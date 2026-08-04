#!/bin/sh
set -u

REPOSITORY_ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
TOOL=$REPOSITORY_ROOT/plugins/tg-agent-plugin/scripts/tg-tool.sh
SYSTEM_PATH=/usr/bin:/bin:/usr/sbin:/sbin
PASS_COUNT=0
FAIL_COUNT=0

assert_contains() {
  value=$1
  expected=$2
  case "$value" in
    *"$expected"*) return 0 ;;
    *)
      printf 'expected output to contain: %s\nactual output: %s\n' "$expected" "$value" >&2
      return 1
      ;;
  esac
}

assert_not_exists() {
  if [ -e "$1" ]; then
    printf 'expected path not to exist: %s\n' "$1" >&2
    return 1
  fi
}

make_case() {
  case_root=$(mktemp -d "${TMPDIR:-/tmp}/tg-agent-test.XXXXXX") || return 1
  mkdir -p "$case_root/home" "$case_root/state" "$case_root/shims" "$case_root/tmp"
  printf '%s\n' "$case_root"
}

cleanup_case() {
  target=$1
  case "$target" in
    "${TMPDIR:-/tmp}"/tg-agent-test.*) rm -rf -- "$target" ;;
    *)
      printf 'refusing unsafe test cleanup: %s\n' "$target" >&2
      return 1
      ;;
  esac
}

make_shims() {
  root=$1
  os_name=$2
  architecture=$3

  cat >"$root/shims/uname" <<EOF
#!/bin/sh
case "\${1:-}" in
  -s) printf '%s\\n' '$os_name' ;;
  -m) printf '%s\\n' '$architecture' ;;
  *) printf '%s\\n' '$os_name' ;;
esac
EOF

  cat >"$root/shims/curl" <<'EOF'
#!/bin/sh
destination=
effective_url=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      shift
      destination=${1:?missing curl destination}
      ;;
    -w)
      shift
      effective_url=1
      ;;
  esac
  shift
done
if [ "$effective_url" -eq 1 ]; then
  printf '%s' "${TG_TEST_LATEST_URL:-https://github.com/gotd/cli/releases/tag/v0.11.0}"
elif [ -n "$destination" ]; then
  printf 'mock archive\n' >"$destination"
else
  exit 34
fi
EOF

  cat >"$root/shims/shasum" <<'EOF'
#!/bin/sh
last=
for argument in "$@"; do last=$argument; done
printf '%s  %s\n' "${TG_TEST_SHA:-invalid}" "$last"
EOF

  cat >"$root/shims/sha256sum" <<'EOF'
#!/bin/sh
printf '%s  %s\n' "${TG_TEST_SHA:-invalid}" "$1"
EOF

  cat >"$root/shims/tar" <<'EOF'
#!/bin/sh
mode=$1
archive_case=${TG_TEST_TAR_CASE:-safe}
case "$mode" in
  -tzf)
    case "$archive_case" in
      safe|symlink|hardlink) printf 'LICENSE\nREADME.md\ntg\n' ;;
      absolute) printf 'LICENSE\nREADME.md\n/tg\n' ;;
      traversal) printf 'LICENSE\nREADME.md\n../tg\n' ;;
      duplicate) printf 'LICENSE\nREADME.md\ntg\ntg\n' ;;
      unexpected) printf 'LICENSE\nREADME.md\ntg\nevil\n' ;;
      *) exit 31 ;;
    esac
    ;;
  -tvzf)
    case "$archive_case" in
      symlink)
        printf '%s\n' '-rw-r--r-- user/group 1 2026-01-01 00:00 LICENSE'
        printf '%s\n' '-rw-r--r-- user/group 1 2026-01-01 00:00 README.md'
        printf '%s\n' 'lrwxr-xr-x user/group 0 2026-01-01 00:00 tg -> /bin/sh'
        ;;
      hardlink)
        printf '%s\n' '-rw-r--r-- user/group 1 2026-01-01 00:00 LICENSE'
        printf '%s\n' '-rw-r--r-- user/group 1 2026-01-01 00:00 README.md'
        printf '%s\n' 'hrwxr-xr-x user/group 0 2026-01-01 00:00 tg link to /bin/sh'
        ;;
      *)
        printf '%s\n' '-rw-r--r-- user/group 1 2026-01-01 00:00 LICENSE'
        printf '%s\n' '-rw-r--r-- user/group 1 2026-01-01 00:00 README.md'
        printf '%s\n' '-rwxr-xr-x user/group 1 2026-01-01 00:00 tg'
        ;;
    esac
    ;;
  -xzf)
    shift
    shift
    if [ "${1:-}" != "-C" ]; then exit 32; fi
    destination=${2:?missing extraction destination}
    printf '%s\n' '#!/bin/sh' >"$destination/tg"
    printf '%s\n' 'printf "%s\n" "$*" >>"${TG_TEST_TG_LOG:?}"' >>"$destination/tg"
    printf '%s\n' 'if [ "${TG_TEST_SMOKE_FAIL:-}" = "1" ] && [ "$*" = "login --help" ]; then exit 9; fi' >>"$destination/tg"
    printf '%s\n' 'exit 0' >>"$destination/tg"
    chmod 755 "$destination/tg"
    printf 'license\n' >"$destination/LICENSE"
    printf 'readme\n' >"$destination/README.md"
    ;;
  *) exit 33 ;;
esac
EOF

  chmod 755 "$root/shims/uname" "$root/shims/curl" \
    "$root/shims/shasum" "$root/shims/sha256sum" "$root/shims/tar"
}

run_tool() {
  env \
    HOME="$case_root/home" \
    XDG_STATE_HOME="$case_root/state" \
    TMPDIR="${TG_TEST_TMPDIR:-$case_root/tmp}" \
    PATH="$case_root/shims:$SYSTEM_PATH" \
    TG_TEST_SHA="${TG_TEST_SHA:-}" \
    TG_TEST_TAR_CASE="${TG_TEST_TAR_CASE:-safe}" \
    TG_TEST_TG_LOG="${TG_TEST_TG_LOG:-$case_root/tg.log}" \
    TG_TEST_SMOKE_FAIL="${TG_TEST_SMOKE_FAIL:-}" \
    TG_TEST_LATEST_URL="${TG_TEST_LATEST_URL:-}" \
    /bin/sh "$TOOL" "$@"
}

test_status_and_platform_mapping() (
  case_root=$(make_case) || exit 1
  trap 'cleanup_case "$case_root"' EXIT
  make_shims "$case_root" Darwin arm64

  output=$(run_tool status --json) || exit 1
  assert_contains "$output" '"status":"missing"' || exit 1
  assert_contains "$output" '"platform":"darwin"' || exit 1
  assert_contains "$output" '"architecture":"arm64"' || exit 1
  assert_contains "$output" "$case_root/home/.local/bin/tg" || exit 1

  make_shims "$case_root" Linux x86_64
  output=$(run_tool status --json) || exit 1
  assert_contains "$output" '"platform":"linux"' || exit 1
  assert_contains "$output" '"architecture":"amd64"' || exit 1
)

test_status_prefers_path() (
  case_root=$(make_case) || exit 1
  trap 'cleanup_case "$case_root"' EXIT
  make_shims "$case_root" Darwin arm64
  printf '%s\n' '#!/bin/sh' 'exit 0' >"$case_root/shims/tg"
  chmod 755 "$case_root/shims/tg"

  output=$(run_tool status --json) || exit 1
  assert_contains "$output" '"status":"ready"' || exit 1
  assert_contains "$output" "$case_root/shims/tg" || exit 1
)

test_unsupported_platform_fails_before_download() (
  case_root=$(make_case) || exit 1
  trap 'cleanup_case "$case_root"' EXIT
  make_shims "$case_root" Plan9 mips64

  output=$(run_tool status --json 2>&1)
  code=$?
  [ "$code" -ne 0 ] || exit 1
  assert_contains "$output" 'Unsupported operating system' || exit 1
  [ ! -s "$case_root/tg.log" ] || exit 1
)

test_install_and_repair() (
  case_root=$(make_case) || exit 1
  trap 'cleanup_case "$case_root"' EXIT
  make_shims "$case_root" Darwin arm64
  TG_TEST_SHA=9e72b09903c69e0a3854dfdac722bd44b99d4f2f5b9721e28bf1fa201f2b62f7
  TG_TEST_TG_LOG=$case_root/tg.log

  output=$(run_tool install --json) || exit 1
  assert_contains "$output" '"status":"installed"' || exit 1
  assert_contains "$output" '"version":"0.11.0"' || exit 1
  test -x "$case_root/home/.local/bin/tg" || exit 1
  assert_not_exists "$case_root/home/.local/bin/tg.bak" || exit 1
  assert_contains "$(cat "$case_root/tg.log")" 'whoami --help' || exit 1
  assert_contains "$(cat "$case_root/tg.log")" 'login --help' || exit 1
  assert_contains "$(cat "$case_root/state/tg-agent-plugin/install.json")" '"archiveSha256":"9e72b099' || exit 1
  [ -z "$(find "$case_root/tmp" -mindepth 1 -maxdepth 1 -print)" ] || exit 1

  : >"$case_root/tg.log"
  output=$(run_tool repair --json) || exit 1
  assert_contains "$output" '"status":"repaired"' || exit 1
  test -x "$case_root/home/.local/bin/tg" || exit 1
)

test_trailing_tmpdir_cleanup() (
  case_root=$(make_case) || exit 1
  trap 'cleanup_case "$case_root"' EXIT
  make_shims "$case_root" Darwin arm64
  TG_TEST_SHA=9e72b09903c69e0a3854dfdac722bd44b99d4f2f5b9721e28bf1fa201f2b62f7
  TG_TEST_TMPDIR=$case_root/tmp/

  output=$(run_tool install --json 2>&1) || exit 1
  assert_contains "$output" '"status":"installed"' || exit 1
  case "$output" in
    *'Refusing to remove unexpected temporary path'*) exit 1 ;;
  esac
  [ -z "$(find "$case_root/tmp" -mindepth 1 -maxdepth 1 -print)" ] || exit 1
)

test_checksum_mismatch_preserves_existing_binary() (
  case_root=$(make_case) || exit 1
  trap 'cleanup_case "$case_root"' EXIT
  make_shims "$case_root" Darwin arm64
  mkdir -p "$case_root/home/.local/bin"
  printf '%s\n' '#!/bin/sh' '# old-marker' 'exit 0' >"$case_root/home/.local/bin/tg"
  chmod 755 "$case_root/home/.local/bin/tg"
  TG_TEST_SHA=0000000000000000000000000000000000000000000000000000000000000000

  output=$(run_tool install --json 2>&1)
  code=$?
  [ "$code" -ne 0 ] || exit 1
  assert_contains "$output" 'Checksum mismatch' || exit 1
  grep -q 'old-marker' "$case_root/home/.local/bin/tg" || exit 1
  assert_not_exists "$case_root/home/.local/bin/tg.bak" || exit 1
)

test_unsafe_archives_are_rejected() (
  for archive_case in absolute traversal symlink hardlink duplicate unexpected; do
    case_root=$(make_case) || exit 1
    make_shims "$case_root" Linux aarch64
    TG_TEST_SHA=d26f11be2adfc30c9a9f10aa8f2930d736f83468f452bf814963b1d917c5474b
    TG_TEST_TAR_CASE=$archive_case

    run_tool install --json >/dev/null 2>&1
    code=$?
    if [ "$code" -eq 0 ] || [ -e "$case_root/home/.local/bin/tg" ]; then
      cleanup_case "$case_root"
      exit 1
    fi
    cleanup_case "$case_root" || exit 1
  done
)

test_failed_smoke_check_rolls_back() (
  case_root=$(make_case) || exit 1
  trap 'cleanup_case "$case_root"' EXIT
  make_shims "$case_root" Darwin arm64
  mkdir -p "$case_root/home/.local/bin"
  printf '%s\n' '#!/bin/sh' '# old-marker' 'exit 0' >"$case_root/home/.local/bin/tg"
  chmod 755 "$case_root/home/.local/bin/tg"
  TG_TEST_SHA=9e72b09903c69e0a3854dfdac722bd44b99d4f2f5b9721e28bf1fa201f2b62f7
  TG_TEST_SMOKE_FAIL=1

  output=$(run_tool install --json 2>&1)
  code=$?
  [ "$code" -ne 0 ] || exit 1
  assert_contains "$output" 'Smoke check failed' || exit 1
  grep -q 'old-marker' "$case_root/home/.local/bin/tg" || exit 1
  assert_not_exists "$case_root/home/.local/bin/tg.bak" || exit 1
)

test_stale_backup_blocks_replacement() (
  case_root=$(make_case) || exit 1
  trap 'cleanup_case "$case_root"' EXIT
  make_shims "$case_root" Darwin arm64
  mkdir -p "$case_root/home/.local/bin"
  printf 'old-marker\n' >"$case_root/home/.local/bin/tg"
  printf 'stale-backup\n' >"$case_root/home/.local/bin/tg.bak"
  TG_TEST_SHA=9e72b09903c69e0a3854dfdac722bd44b99d4f2f5b9721e28bf1fa201f2b62f7

  output=$(run_tool install --json 2>&1)
  code=$?
  [ "$code" -ne 0 ] || exit 1
  assert_contains "$output" 'stale backup' || exit 1
  grep -q 'old-marker' "$case_root/home/.local/bin/tg" || exit 1
  grep -q 'stale-backup' "$case_root/home/.local/bin/tg.bak" || exit 1
)

test_update_check_reports_but_never_installs_unpinned_release() (
  case_root=$(make_case) || exit 1
  trap 'cleanup_case "$case_root"' EXIT
  make_shims "$case_root" Linux x86_64
  TG_TEST_LATEST_URL=https://github.com/gotd/cli/releases/tag/v0.12.0

  output=$(run_tool check-update --json) || exit 1
  assert_contains "$output" '"status":"newer-unpinned"' || exit 1
  assert_contains "$output" '"pinnedVersion":"0.11.0"' || exit 1
  assert_contains "$output" '"latestTag":"v0.12.0"' || exit 1
  assert_not_exists "$case_root/home/.local/bin/tg" || exit 1
)

run_test() {
  name=$1
  shift
  if "$@"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'ok - %s\n' "$name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'not ok - %s\n' "$name"
  fi
}

if [ ! -f "$TOOL" ]; then
  printf 'not ok - lifecycle script exists: %s\n' "$TOOL"
  exit 1
fi

run_test 'status and platform mapping' test_status_and_platform_mapping
run_test 'status prefers PATH' test_status_prefers_path
run_test 'unsupported platform fails before download' test_unsupported_platform_fails_before_download
run_test 'install and repair' test_install_and_repair
run_test 'trailing TMPDIR cleanup' test_trailing_tmpdir_cleanup
run_test 'checksum mismatch preserves existing binary' test_checksum_mismatch_preserves_existing_binary
run_test 'unsafe archives are rejected' test_unsafe_archives_are_rejected
run_test 'failed smoke check rolls back' test_failed_smoke_check_rolls_back
run_test 'stale backup blocks replacement' test_stale_backup_blocks_replacement
run_test 'update check never installs unpinned releases' test_update_check_reports_but_never_installs_unpinned_release

printf '%s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
