#!/bin/sh
set -eu

WORKER=0
if [ "${1:-}" = "--worker" ]; then
  WORKER=1
  shift
fi

[ "$#" -ge 2 ] && [ "$#" -le 3 ] || {
  printf 'Usage: %s [--worker] <tg-path> <phone|qr> [--no-pause]\n' "$0" >&2
  exit 2
}

TG_PATH=$1
MODE=$2
NO_PAUSE=${3:-}
case "$MODE" in phone|qr) ;; *) printf 'Unknown login mode.\n' >&2; exit 2 ;; esac
case "$NO_PAUSE" in ''|--no-pause) ;; *) printf 'Unknown option.\n' >&2; exit 2 ;; esac
[ -x "$TG_PATH" ] || { printf 'The local tg executable was not found.\n' >&2; exit 1; }

unset TG_PASSWORD APP_ID APP_HASH BOT_TOKEN

finish_worker() {
  message=$1
  code=$2
  printf '\n%s\n' "$message"
  if [ "$NO_PAUSE" != "--no-pause" ]; then
    printf 'Press Enter to close this window: '
    IFS= read -r _
  fi
  exit "$code"
}

if [ "$WORKER" -eq 1 ]; then
  printf '%s\n' 'Secure local Telegram login'
  printf '%s\n' 'Enter every credential only in this local window.'
  printf '%s\n\n' 'Never send a phone number, code, QR token, or 2FA password to the agent.'

  config_path=${XDG_CONFIG_HOME:-"$HOME/.config"}/gotd/gotd.cli.yaml
  if [ ! -f "$config_path" ]; then
    "$TG_PATH" init || finish_worker 'Unable to initialize the local gotd/cli configuration.' 1
  fi

  if [ "$MODE" = phone ]; then
    printf '%s\n' 'Enter the phone number, Telegram code, and 2FA password when prompted.'
    "$TG_PATH" login --phone= || finish_worker 'Login did not complete.' 1
  else
    printf '%s\n' 'In Telegram, open Settings, Devices, then Link Desktop Device.'
    "$TG_PATH" login || finish_worker 'Login did not complete.' 1
  fi
  finish_worker 'Login completed. Return to the agent and report that you are ready.' 0
fi

SCRIPT_PATH=$(CDPATH= cd "$(dirname "$0")" && pwd)/$(basename "$0")
if command -v x-terminal-emulator >/dev/null 2>&1; then
  x-terminal-emulator -e /bin/sh "$SCRIPT_PATH" --worker "$TG_PATH" "$MODE" >/dev/null 2>&1 &
elif command -v gnome-terminal >/dev/null 2>&1; then
  gnome-terminal -- /bin/sh "$SCRIPT_PATH" --worker "$TG_PATH" "$MODE" >/dev/null 2>&1 &
elif command -v konsole >/dev/null 2>&1; then
  konsole -e /bin/sh "$SCRIPT_PATH" --worker "$TG_PATH" "$MODE" >/dev/null 2>&1 &
elif command -v kitty >/dev/null 2>&1; then
  kitty /bin/sh "$SCRIPT_PATH" --worker "$TG_PATH" "$MODE" >/dev/null 2>&1 &
elif command -v alacritty >/dev/null 2>&1; then
  alacritty -e /bin/sh "$SCRIPT_PATH" --worker "$TG_PATH" "$MODE" >/dev/null 2>&1 &
else
  shell_quote() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
  }
  printf 'manual-required command=/bin/sh %s --worker %s %s\n' \
    "$(shell_quote "$SCRIPT_PATH")" \
    "$(shell_quote "$TG_PATH")" \
    "$(shell_quote "$MODE")"
  exit 3
fi

printf 'login-started mode=%s\n' "$MODE"
