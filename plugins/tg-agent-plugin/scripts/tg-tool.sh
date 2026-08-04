#!/bin/sh
set -eu

ACTION=${1:-status}
if [ "$#" -gt 0 ]; then shift; fi

JSON=0
MODE=phone
while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --mode)
      shift
      [ "$#" -gt 0 ] || { printf 'Missing value for --mode\n' >&2; exit 2; }
      MODE=$1
      case "$MODE" in
        phone|qr) ;;
        *) printf 'Unknown login mode: %s\n' "$MODE" >&2; exit 2 ;;
      esac
      ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

SCRIPT_DIR=$(CDPATH='' cd "$(dirname "$0")" && pwd)
MANIFEST_PATH=$SCRIPT_DIR/../config/release-manifest.json
STATE_DIR=${XDG_STATE_HOME:-"$HOME/.local/state"}/tg-agent-plugin
INSTALL_STATE=$STATE_DIR/install.json
INSTALL_DIR=$HOME/.local/bin
TG_PATH=$INSTALL_DIR/tg
BACKUP_PATH=$TG_PATH.bak
NEW_PATH=$TG_PATH.new.$$
STATE_TMP=$INSTALL_STATE.tmp.$$
WORK_DIR=
REPLACEMENT_ACTIVE=0
HAD_PREVIOUS=0

die() {
  printf '%s\n' "$1" >&2
  exit "${2:-1}"
}

unset TG_PASSWORD APP_ID APP_HASH BOT_TOKEN

json_escape() {
  printf '%s' "$1" | awk '
    BEGIN { first = 1 }
    {
      if (!first) printf "\\n"
      first = 0
      gsub(/\\/, "\\\\")
      gsub(/\"/, "\\\"")
      gsub(/\t/, "\\t")
      gsub(/\r/, "\\r")
      printf "%s", $0
    }
  '
}

result() {
  status=$1
  shift
  if [ "$JSON" -eq 1 ]; then
    printf '{"schemaVersion":1,"status":"%s","platform":"%s","architecture":"%s"' \
      "$(json_escape "$status")" \
      "$(json_escape "$PLATFORM")" \
      "$(json_escape "$ARCHITECTURE")"
    while [ "$#" -gt 0 ]; do
      key=$1
      value=$2
      shift 2
      printf ',"%s":"%s"' "$key" "$(json_escape "$value")"
    done
    printf '}\n'
  else
    printf '%s' "$status"
    while [ "$#" -gt 0 ]; do
      key=$1
      value=$2
      shift 2
      printf ' %s=%s' "$key" "$value"
    done
    printf '\n'
  fi
}

detect_platform() {
  os_name=$(uname -s)
  case "$os_name" in
    Darwin) PLATFORM=darwin ;;
    Linux) PLATFORM=linux ;;
    *) die "Unsupported operating system: $os_name" 2 ;;
  esac

  machine=$(uname -m)
  case "$machine" in
    x86_64|amd64) ARCHITECTURE=amd64 ;;
    arm64|aarch64) ARCHITECTURE=arm64 ;;
    *) die "Unsupported architecture: $machine" 2 ;;
  esac
}

manifest_string() {
  key=$1
  sed -n "s/^[[:space:]]*\"$key\":[[:space:]]*\"\([^\"]*\)\"[,]*[[:space:]]*$/\\1/p" \
    "$MANIFEST_PATH" | head -n 1
}

select_asset() {
  awk -v wanted_os="$PLATFORM" -v wanted_arch="$ARCHITECTURE" '
    function value(line) {
      sub(/^.*:[[:space:]]*\"/, "", line)
      sub(/\"[,]?[[:space:]]*$/, "", line)
      return line
    }
    /\"os\":[[:space:]]*\"/ { os = value($0) }
    /\"arch\":[[:space:]]*\"/ { arch = value($0) }
    /\"name\":[[:space:]]*\"/ && os != "" { name = value($0) }
    /\"url\":[[:space:]]*\"/ && os != "" { url = value($0) }
    /\"sha256\":[[:space:]]*\"/ && os != "" { sha = value($0) }
    /\"githubDigest\":[[:space:]]*\"/ && os != "" { digest = value($0) }
    /^[[:space:]]*}[,]?[[:space:]]*$/ && os != "" {
      if (os == wanted_os && arch == wanted_arch) {
        print name "|" url "|" sha "|" digest
      }
      os = arch = name = url = sha = digest = ""
    }
  ' "$MANIFEST_PATH"
}

load_compatibility() {
  [ -f "$MANIFEST_PATH" ] || die "Release manifest is missing"
  PINNED_TAG=$(manifest_string tag)
  PINNED_VERSION=$(manifest_string version)
  [ "$PINNED_TAG" = "v$PINNED_VERSION" ] || die "Release manifest tag and version disagree"

  asset_record=$(select_asset)
  [ -n "$asset_record" ] || die "No pinned asset for $PLATFORM/$ARCHITECTURE"
  old_ifs=$IFS
  IFS='|'
  # shellcheck disable=SC2086 # Intentional four-field split using the delimiter above.
  set -- $asset_record
  IFS=$old_ifs
  [ "$#" -eq 4 ] || die "Pinned asset entry is incomplete"
  ASSET_NAME=$1
  ASSET_URL=$2
  ASSET_SHA256=$3
  ASSET_GITHUB_DIGEST=$4

  expected_name=tg_${PINNED_VERSION}_${PLATFORM}_${ARCHITECTURE}.tar.gz
  expected_url=https://github.com/gotd/cli/releases/download/$PINNED_TAG/$expected_name
  [ "$ASSET_NAME" = "$expected_name" ] || die "Pinned asset name is unexpected"
  [ "$ASSET_URL" = "$expected_url" ] || die "Pinned asset URL is not the approved GitHub release URL"
  [ "$ASSET_GITHUB_DIGEST" = "sha256:$ASSET_SHA256" ] || die "Pinned GitHub digest does not match SHA-256"
  case "$ASSET_SHA256" in
    *[!a-f0-9]*|'') die "Pinned SHA-256 is malformed" ;;
  esac
  [ "${#ASSET_SHA256}" -eq 64 ] || die "Pinned SHA-256 is malformed"
}

resolve_tg() {
  if command -v tg >/dev/null 2>&1; then
    command -v tg
  elif [ -x "$TG_PATH" ]; then
    printf '%s\n' "$TG_PATH"
  fi
}

read_installed_version() {
  if [ -f "$INSTALL_STATE" ]; then
    sed -n 's/.*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$INSTALL_STATE" | head -n 1
  fi
}

archive_sha256() {
  archive=$1
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$archive" | awk '{ print tolower($1); exit }'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$archive" | awk '{ print tolower($1); exit }'
  else
    die "No SHA-256 tool is available"
  fi
}

temp_root_path() {
  value=${TMPDIR:-/tmp}
  while [ "$value" != / ] && [ "${value%/}" != "$value" ]; do
    value=${value%/}
  done
  printf '%s\n' "$value"
}

cleanup_work() {
  target=${1:-}
  [ -n "$target" ] || return 0
  temp_root=$(temp_root_path)
  case "$target" in
    "$temp_root"/tg-agent-plugin.*)
      if [ -d "$target" ]; then rm -rf -- "$target"; fi
      ;;
    *)
      printf 'Refusing to remove unexpected temporary path: %s\n' "$target" >&2
      return 1
      ;;
  esac
}

rollback_replacement() {
  if [ "$REPLACEMENT_ACTIVE" -eq 1 ]; then
    rm -f -- "$TG_PATH"
    if [ "$HAD_PREVIOUS" -eq 1 ] && [ -e "$BACKUP_PATH" ]; then
      mv -- "$BACKUP_PATH" "$TG_PATH"
    fi
    REPLACEMENT_ACTIVE=0
  fi
}

on_exit() {
  exit_code=$?
  trap - EXIT HUP INT TERM
  set +e
  if [ "$exit_code" -ne 0 ]; then rollback_replacement; fi
  if [ -e "$NEW_PATH" ]; then rm -f -- "$NEW_PATH"; fi
  if [ -e "$STATE_TMP" ]; then rm -f -- "$STATE_TMP"; fi
  cleanup_work "$WORK_DIR"
  exit "$exit_code"
}

trap on_exit EXIT
trap 'exit 130' HUP INT TERM

validate_archive() {
  archive=$1
  entries=$WORK_DIR/archive-entries.txt
  details=$WORK_DIR/archive-details.txt
  tar -tzf "$archive" >"$entries" || die "Archive listing failed"
  tar -tvzf "$archive" >"$details" || die "Archive metadata listing failed"

  license_count=0
  readme_count=0
  executable_count=0
  while IFS= read -r entry; do
    [ -n "$entry" ] || die "Archive contains an empty path"
    case "$entry" in
      /*) die "Archive contains an absolute path" ;;
      *\\*) die "Archive contains a backslash path" ;;
    esac
    case "/$entry/" in
      */../*) die "Archive contains parent traversal" ;;
    esac
    case "$entry" in
      LICENSE) license_count=$((license_count + 1)) ;;
      README.md) readme_count=$((readme_count + 1)) ;;
      tg) executable_count=$((executable_count + 1)) ;;
      *) die "Archive contains an unexpected entry: $entry" ;;
    esac
  done <"$entries"

  [ "$license_count" -eq 1 ] || die "Archive must contain one LICENSE"
  [ "$readme_count" -eq 1 ] || die "Archive must contain one README.md"
  [ "$executable_count" -eq 1 ] || die "Archive must contain exactly one tg executable"

  while IFS= read -r detail; do
    entry_type=$(printf '%s' "$detail" | cut -c 1)
    case "$entry_type" in
      l|h) die "Archive links are not allowed" ;;
    esac
    case "$detail" in
      *' link to '*) die "Archive links are not allowed" ;;
    esac
  done <"$details"
}

write_smoke_plan() {
  output=$1
  awk '
    function json_value(line) {
      sub(/^.*\"/, "", line)
      sub(/\".*$/, "", line)
      return line
    }
    /\"smokeCommands\"[[:space:]]*:/ { in_smoke = 1; next }
    in_smoke && !in_args && /^  ]/ { exit }
    in_smoke && /\"name\"[[:space:]]*:/ {
      line = $0
      sub(/^.*\"name\"[[:space:]]*:[[:space:]]*\"/, "", line)
      sub(/\".*$/, "", line)
      name = line
      next
    }
    in_smoke && /\"args\"[[:space:]]*:/ {
      in_args = 1
      args = ""
      next
    }
    in_args && /^[[:space:]]*\"/ {
      line = $0
      sub(/^[[:space:]]*\"/, "", line)
      sub(/\".*$/, "", line)
      if (args == "") args = line
      else args = args "|" line
      next
    }
    in_args && /^[[:space:]]*]/ {
      print name "|" args
      name = args = ""
      in_args = 0
    }
  ' "$MANIFEST_PATH" >"$output"
}

run_smoke_checks() {
  executable=$1
  plan=$WORK_DIR/smoke-plan.txt
  write_smoke_plan "$plan"
  count=0
  while IFS='|' read -r check_name first second third; do
    [ -n "$check_name" ] || die "Smoke command name is missing"
    [ -n "$first" ] || die "Smoke command arguments are missing"
    [ -z "${third:-}" ] || die "Smoke command has too many arguments"
    if [ -n "${second:-}" ]; then
      "$executable" "$first" "$second" >/dev/null 2>&1 || return 1
    else
      "$executable" "$first" >/dev/null 2>&1 || return 1
    fi
    count=$((count + 1))
  done <"$plan"
  [ "$count" -eq 3 ] || die "Unexpected smoke command count"
}

write_install_state() {
  installed_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  mkdir -p "$STATE_DIR"
  printf '{"schemaVersion":1,"version":"%s","tag":"%s","asset":"%s","archiveSha256":"%s","installedAt":"%s","executable":"%s"}\n' \
    "$(json_escape "$PINNED_VERSION")" \
    "$(json_escape "$PINNED_TAG")" \
    "$(json_escape "$ASSET_NAME")" \
    "$(json_escape "$ASSET_SHA256")" \
    "$(json_escape "$installed_at")" \
    "$(json_escape "$TG_PATH")" >"$STATE_TMP"
  mv -- "$STATE_TMP" "$INSTALL_STATE"
}

install_pinned() {
  success_status=$1
  load_compatibility

  [ ! -e "$BACKUP_PATH" ] || die "Refusing replacement because a stale backup exists"
  [ ! -e "$NEW_PATH" ] || die "Refusing replacement because a stale temporary executable exists"

  temp_root=$(temp_root_path)
  WORK_DIR=$(mktemp -d "$temp_root/tg-agent-plugin.XXXXXX") || die "Unable to create a temporary directory"
  archive=$WORK_DIR/$ASSET_NAME
  extract_dir=$WORK_DIR/extract
  mkdir -p "$extract_dir"

  curl --fail --silent --show-error --location \
    -H 'User-Agent: tg-agent-plugin' \
    -o "$archive" "$ASSET_URL" || die "Unable to download the pinned gotd/cli asset"

  actual_sha=$(archive_sha256 "$archive")
  [ "$actual_sha" = "$ASSET_SHA256" ] || die "Checksum mismatch for pinned gotd/cli archive"

  validate_archive "$archive"
  tar -xzf "$archive" -C "$extract_dir" || die "Archive extraction failed"
  candidate=$extract_dir/tg
  if [ ! -f "$candidate" ] || [ -L "$candidate" ]; then
    die "Extracted tg candidate is not a regular file"
  fi
  chmod 755 "$candidate"

  mkdir -p "$INSTALL_DIR" "$STATE_DIR"
  cp -- "$candidate" "$NEW_PATH"
  chmod 755 "$NEW_PATH"

  if [ -e "$TG_PATH" ]; then
    mv -- "$TG_PATH" "$BACKUP_PATH"
    HAD_PREVIOUS=1
  fi
  REPLACEMENT_ACTIVE=1
  mv -- "$NEW_PATH" "$TG_PATH"

  if ! run_smoke_checks "$TG_PATH"; then
    die "Smoke check failed; the previous executable was restored"
  fi
  write_install_state

  REPLACEMENT_ACTIVE=0
  if [ "$HAD_PREVIOUS" -eq 1 ]; then rm -f -- "$BACKUP_PATH"; fi
  result "$success_status" \
    version "$PINNED_VERSION" \
    tag "$PINNED_TAG" \
    asset "$ASSET_NAME" \
    path "$TG_PATH"
}

check_update() {
  load_compatibility
  latest_url=$(curl --fail --silent --show-error --location \
    -o /dev/null -w '%{url_effective}' \
    -H 'User-Agent: tg-agent-plugin' \
    https://github.com/gotd/cli/releases/latest) || die "Unable to check the latest gotd/cli release"
  case "$latest_url" in
    https://github.com/gotd/cli/releases/tag/v[0-9]*.[0-9]*.[0-9]*) ;;
    *) die "Latest release response is not an approved gotd/cli GitHub tag URL" ;;
  esac
  latest_tag=${latest_url##*/}
  if [ "$latest_tag" = "$PINNED_TAG" ]; then
    update_status=pinned-current
  else
    update_status=newer-unpinned
  fi
  result "$update_status" \
    pinnedVersion "$PINNED_VERSION" \
    pinnedTag "$PINNED_TAG" \
    latestTag "$latest_tag" \
    releaseUrl "$latest_url"
}

authorize_account() {
  resolved=$(resolve_tg)
  if [ -z "$resolved" ]; then
    result missing path "$TG_PATH"
    return
  fi
  if "$resolved" whoami -o json >/dev/null 2>&1; then
    result already-authorized path "$resolved"
    return
  fi

  case "$PLATFORM" in
    darwin) launcher=$SCRIPT_DIR/tg-login-macos.sh ;;
    linux) launcher=$SCRIPT_DIR/tg-login-linux.sh ;;
    *) die "No authorization launcher for $PLATFORM" ;;
  esac
  [ -x "$launcher" ] || die "Authorization launcher is unavailable"

  if launcher_output=$("$launcher" "$resolved" "$MODE"); then
    result login-started mode "$MODE"
  else
    launcher_code=$?
    if [ "$launcher_code" -eq 3 ] && [ "$PLATFORM" = linux ]; then
      manual_command=${launcher_output#manual-required command=}
      result manual-required mode "$MODE" command "$manual_command"
    else
      die "Unable to launch the local login window"
    fi
  fi
}

verify_authorization() {
  resolved=$(resolve_tg)
  if [ -z "$resolved" ]; then
    result missing path "$TG_PATH"
    return
  fi
  if "$resolved" whoami -o json >/dev/null 2>&1; then
    result authorized path "$resolved"
  else
    result not-authorized path "$resolved"
  fi
}

detect_platform

case "$ACTION" in
  status)
    resolved=$(resolve_tg)
    if [ -n "$resolved" ]; then
      result ready path "$resolved" version "$(read_installed_version)"
    else
      result missing path "$TG_PATH"
    fi
    ;;
  install) install_pinned installed ;;
  repair) install_pinned repaired ;;
  check-update) check_update ;;
  authorize) authorize_account ;;
  verify-authorization) verify_authorization ;;
  *) die "Unknown action: $ACTION" 2 ;;
esac
