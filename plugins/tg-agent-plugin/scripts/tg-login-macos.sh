#!/bin/sh
set -eu

WORKER=0
if [ "${1:-}" = "--worker" ]; then
  WORKER=1
  shift
fi

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  printf 'Usage: %s [--worker] <tg-path> <phone|qr> [--no-pause]\n' "$0" >&2
  exit 2
fi

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

  config_path=$HOME/Library/Application\ Support/gotd/gotd.cli.yaml
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

shell_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

SCRIPT_DIRECTORY=$(CDPATH='' cd "$(dirname "$0")" && pwd)
SCRIPT_NAME=$(basename "$0")
SCRIPT_PATH=$SCRIPT_DIRECTORY/$SCRIPT_NAME
command_line="/bin/sh $(shell_quote "$SCRIPT_PATH") --worker $(shell_quote "$TG_PATH") $(shell_quote "$MODE")"
apple_command=$(printf '%s' "$command_line" | sed 's/\\/\\\\/g; s/"/\\"/g')
osascript_path=$(command -v osascript 2>/dev/null || true)
[ -n "$osascript_path" ] || { printf 'macOS Terminal launcher is unavailable.\n' >&2; exit 3; }

"$osascript_path" \
  -e 'tell application "Terminal"' \
  -e 'activate' \
  -e "do script \"$apple_command\"" \
  -e 'end tell' >/dev/null
printf 'login-started mode=%s\n' "$MODE"
