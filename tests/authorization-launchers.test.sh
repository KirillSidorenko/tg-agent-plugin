#!/bin/sh
set -u

REPOSITORY_ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
SCRIPTS=$REPOSITORY_ROOT/plugins/tg-agent-plugin/scripts
MACOS_LAUNCHER=$SCRIPTS/tg-login-macos.sh
LINUX_LAUNCHER=$SCRIPTS/tg-login-linux.sh
TOOL=$SCRIPTS/tg-tool.sh
SYSTEM_PATH=/usr/bin:/bin:/usr/sbin:/sbin
PASS_COUNT=0
FAIL_COUNT=0

assert_contains() {
  case "$1" in
    *"$2"*) return 0 ;;
    *) printf 'expected [%s] in [%s]\n' "$2" "$1" >&2; return 1 ;;
  esac
}

assert_not_contains() {
  case "$1" in
    *"$2"*) printf 'did not expect [%s] in [%s]\n' "$2" "$1" >&2; return 1 ;;
    *) return 0 ;;
  esac
}

make_case() {
  case_root=$(mktemp -d "${TMPDIR:-/tmp}/tg-agent-auth-test.XXXXXX") || return 1
  mkdir -p "$case_root/home" "$case_root/state" "$case_root/shims" "$case_root/tmp"
  printf '%s\n' "$case_root"
}

cleanup_case() {
  case "$1" in
    "${TMPDIR:-/tmp}"/tg-agent-auth-test.*) rm -rf -- "$1" ;;
    *) printf 'refusing unsafe test cleanup: %s\n' "$1" >&2; return 1 ;;
  esac
}

make_fake_tg() {
  fake_path=$1
  mkdir -p "$(dirname "$fake_path")"
  cat >"$fake_path" <<'EOF'
#!/bin/sh
if [ -n "${TG_PASSWORD:-}" ] || [ -n "${APP_ID:-}" ] || \
   [ -n "${APP_HASH:-}" ] || [ -n "${BOT_TOKEN:-}" ]; then
  printf 'secret-environment-present\n' >>"${TG_TEST_TG_LOG:?}"
fi
line=${1:-}
if [ "$#" -gt 0 ]; then shift; fi
for argument in "$@"; do line=$line'|'$argument; done
printf '%s\n' "$line" >>"${TG_TEST_TG_LOG:?}"
case "$line" in
  init)
    if [ -n "${TG_TEST_CONFIG_PATH:-}" ]; then
      mkdir -p "$(dirname "$TG_TEST_CONFIG_PATH")"
      : >"$TG_TEST_CONFIG_PATH"
    fi
    ;;
  "whoami|-o|json")
    [ "${TG_TEST_AUTHORIZED:-0}" = 1 ] || exit 7
    ;;
esac
exit 0
EOF
  chmod 755 "$fake_path"
}

make_uname_shim() {
  root=$1
  cat >"$root/shims/uname" <<'EOF'
#!/bin/sh
case "${1:-}" in
  -s) printf 'Darwin\n' ;;
  -m) printf 'arm64\n' ;;
  *) printf 'Darwin\n' ;;
esac
EOF
  chmod 755 "$root/shims/uname"
}

test_workers_keep_secrets_out_of_argv_and_env() (
  case_root=$(make_case) || exit 1
  trap 'cleanup_case "$case_root"' EXIT
  fake_tg=$case_root/bin/tg
  make_fake_tg "$fake_tg"

  mac_config=$case_root/home/Library/Application\ Support/gotd/gotd.cli.yaml
  TG_TEST_TG_LOG=$case_root/mac.log \
  TG_TEST_CONFIG_PATH=$mac_config \
  HOME=$case_root/home \
  TG_PASSWORD=do-not-forward APP_ID=do-not-forward APP_HASH=do-not-forward BOT_TOKEN=do-not-forward \
    /bin/sh "$MACOS_LAUNCHER" --worker "$fake_tg" phone --no-pause >/dev/null || exit 1
  mac_log=$(cat "$case_root/mac.log")
  [ "$mac_log" = "init
login|--phone=" ] || exit 1
  assert_not_contains "$mac_log" 'do-not-forward' || exit 1
  assert_not_contains "$mac_log" 'secret-environment-present' || exit 1

  linux_config=$case_root/config/gotd/gotd.cli.yaml
  mkdir -p "$(dirname "$linux_config")"
  : >"$linux_config"
  TG_TEST_TG_LOG=$case_root/linux.log \
  TG_TEST_CONFIG_PATH=$linux_config \
  HOME=$case_root/home XDG_CONFIG_HOME=$case_root/config \
  TG_PASSWORD=do-not-forward APP_ID=do-not-forward APP_HASH=do-not-forward BOT_TOKEN=do-not-forward \
    /bin/sh "$LINUX_LAUNCHER" --worker "$fake_tg" qr --no-pause >/dev/null || exit 1
  linux_log=$(cat "$case_root/linux.log")
  [ "$linux_log" = 'login' ] || exit 1
  assert_not_contains "$linux_log" 'secret-environment-present' || exit 1

  /bin/sh "$LINUX_LAUNCHER" --worker "$fake_tg" phone unexpected >/dev/null 2>&1
  [ "$?" -ne 0 ] || exit 1
)

test_macos_launcher_constructs_secret_free_terminal_command() (
  case_root=$(make_case) || exit 1
  trap 'cleanup_case "$case_root"' EXIT
  fake_tg=$case_root/bin\ with\ space/tg
  make_fake_tg "$fake_tg"
  cat >"$case_root/shims/osascript" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"${TG_TEST_LAUNCH_LOG:?}"
EOF
  chmod 755 "$case_root/shims/osascript"

  output=$(TG_TEST_LAUNCH_LOG=$case_root/launch.log \
    PATH=$case_root/shims:$SYSTEM_PATH \
    /bin/sh "$MACOS_LAUNCHER" "$fake_tg" phone) || exit 1
  assert_contains "$output" 'login-started' || exit 1
  launch=$(cat "$case_root/launch.log")
  assert_contains "$launch" '/bin/sh' || exit 1
  assert_contains "$launch" '--worker' || exit 1
  assert_contains "$launch" "$fake_tg" || exit 1
  assert_contains "$launch" 'phone' || exit 1
  assert_not_contains "$launch" 'do-not-forward' || exit 1
)

test_linux_launcher_uses_allowlist_then_safe_headless_handoff() (
  case_root=$(make_case) || exit 1
  trap 'cleanup_case "$case_root"' EXIT
  fake_tg=$case_root/bin/tg
  make_fake_tg "$fake_tg"
  cat >"$case_root/shims/x-terminal-emulator" <<'EOF'
#!/bin/sh
printf 'x-terminal-emulator|%s\n' "$*" >"${TG_TEST_LAUNCH_LOG:?}"
EOF
  cat >"$case_root/shims/gnome-terminal" <<'EOF'
#!/bin/sh
printf 'gnome-terminal|%s\n' "$*" >>"${TG_TEST_LAUNCH_LOG:?}"
EOF
  chmod 755 "$case_root/shims/x-terminal-emulator" "$case_root/shims/gnome-terminal"

  output=$(TG_TEST_LAUNCH_LOG=$case_root/launch.log \
    PATH=$case_root/shims:$SYSTEM_PATH \
    /bin/sh "$LINUX_LAUNCHER" "$fake_tg" phone) || exit 1
  assert_contains "$output" 'login-started' || exit 1
  attempts=0
  while [ ! -s "$case_root/launch.log" ] && [ "$attempts" -lt 100 ]; do
    sleep 0.05
    attempts=$((attempts + 1))
  done
  [ -s "$case_root/launch.log" ] || exit 1
  launch=$(cat "$case_root/launch.log")
  assert_contains "$launch" 'x-terminal-emulator|' || exit 1
  assert_not_contains "$launch" 'gnome-terminal|' || exit 1
  assert_contains "$launch" '--worker' || exit 1

  mkdir -p "$case_root/minimal-path"
  ln -s /usr/bin/dirname "$case_root/minimal-path/dirname"
  ln -s /usr/bin/basename "$case_root/minimal-path/basename"
  ln -s /usr/bin/sed "$case_root/minimal-path/sed"
  output=$(PATH=$case_root/minimal-path /bin/sh "$LINUX_LAUNCHER" "$fake_tg" qr 2>/dev/null)
  code=$?
  [ "$code" -eq 3 ] || exit 1
  assert_contains "$output" 'manual-required' || exit 1
  assert_contains "$output" '--worker' || exit 1
  assert_contains "$output" 'qr' || exit 1
  assert_not_contains "$output" 'do-not-forward' || exit 1
)

test_lifecycle_authorization_checks_once_and_never_polls() (
  case_root=$(make_case) || exit 1
  trap 'cleanup_case "$case_root"' EXIT
  make_uname_shim "$case_root"
  make_fake_tg "$case_root/shims/tg"
  cat >"$case_root/shims/osascript" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"${TG_TEST_LAUNCH_LOG:?}"
EOF
  chmod 755 "$case_root/shims/osascript"

  output=$(env HOME="$case_root/home" XDG_STATE_HOME="$case_root/state" TMPDIR="$case_root/tmp" \
    PATH="$case_root/shims:$SYSTEM_PATH" TG_TEST_TG_LOG="$case_root/tg.log" \
    TG_TEST_LAUNCH_LOG="$case_root/launch.log" TG_TEST_AUTHORIZED=0 \
    TG_PASSWORD=do-not-forward APP_ID=do-not-forward APP_HASH=do-not-forward BOT_TOKEN=do-not-forward \
    /bin/sh "$TOOL" authorize --mode phone --json) || exit 1
  assert_contains "$output" '"status":"login-started"' || exit 1
  [ "$(grep -c '^whoami|-o|json$' "$case_root/tg.log")" -eq 1 ] || exit 1
  assert_not_contains "$(cat "$case_root/tg.log")" 'secret-environment-present' || exit 1

  : >"$case_root/tg.log"
  : >"$case_root/launch.log"
  output=$(env HOME="$case_root/home" XDG_STATE_HOME="$case_root/state" TMPDIR="$case_root/tmp" \
    PATH="$case_root/shims:$SYSTEM_PATH" TG_TEST_TG_LOG="$case_root/tg.log" \
    TG_TEST_LAUNCH_LOG="$case_root/launch.log" TG_TEST_AUTHORIZED=1 \
    /bin/sh "$TOOL" authorize --mode qr --json) || exit 1
  assert_contains "$output" '"status":"already-authorized"' || exit 1
  [ "$(grep -c '^whoami|-o|json$' "$case_root/tg.log")" -eq 1 ] || exit 1
  [ ! -s "$case_root/launch.log" ] || exit 1

  : >"$case_root/tg.log"
  output=$(env HOME="$case_root/home" XDG_STATE_HOME="$case_root/state" TMPDIR="$case_root/tmp" \
    PATH="$case_root/shims:$SYSTEM_PATH" TG_TEST_TG_LOG="$case_root/tg.log" \
    TG_TEST_AUTHORIZED=1 /bin/sh "$TOOL" verify-authorization --json) || exit 1
  assert_contains "$output" '"status":"authorized"' || exit 1
  [ "$(grep -c '^whoami|-o|json$' "$case_root/tg.log")" -eq 1 ] || exit 1
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

if [ ! -f "$MACOS_LAUNCHER" ] || [ ! -f "$LINUX_LAUNCHER" ]; then
  printf 'not ok - authorization launchers exist\n'
  exit 1
fi

run_test 'workers keep secrets out of argv and env' test_workers_keep_secrets_out_of_argv_and_env
run_test 'macOS constructs a secret-free Terminal command' test_macos_launcher_constructs_secret_free_terminal_command
run_test 'Linux uses the allowlist and safe headless handoff' test_linux_launcher_uses_allowlist_then_safe_headless_handoff
run_test 'lifecycle authorization checks exactly once' test_lifecycle_authorization_checks_once_and_never_polls

printf '%s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
