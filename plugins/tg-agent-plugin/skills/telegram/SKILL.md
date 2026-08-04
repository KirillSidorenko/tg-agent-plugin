---
name: telegram
description: Work with a local Telegram personal account through the upstream gotd/cli tg binary. Use when the user asks to find chats or people, read or search messages, send, reply, edit, forward, react, upload or download media, manage chats, or wait for new Telegram messages on this device.
---

# Telegram

Use the upstream `tg` binary directly for ordinary Telegram work. Do not route
ordinary commands through lifecycle scripts, another CLI, or an MCP server.

## Resolve the local client

Resolve `tg` from `PATH` first. Fall back to the plugin-managed executable:

- macOS and Linux: `$HOME/.local/bin/tg`
- Windows: `$env:LOCALAPPDATA\Programs\tg\tg.exe`

If the executable is missing, authorization is absent, or the user asks about
installation, login, repair, or updates, invoke the sibling `telegram-setup`
skill from this plugin. Do not hardcode a Claude Code or Codex namespace.

Refuse bot setup, remote sessions, or hosted Telegram access as outside the
local personal-account scope.

## Query efficiently

- Run the requested operation directly. Do not preflight every request with
  `whoami`.
- Add `-o json` whenever parsing the result. Treat stdout as data and stderr as
  diagnostics.
- Reuse one broad result and filter it locally. Do not issue one request per
  chat, sender, or message.
- Make one targeted `tg <command> --help` call only after uncertain syntax or a
  rejected argument. Do not guess repeatedly.
- Read only the history and media needed for the request.

Read [`references/commands.md`](references/commands.md) for tested command
recipes. Read [`references/troubleshooting.md`](references/troubleshooting.md)
only after a command fails or produces an uncertain result.

## Apply operation safety

- Proceed with listing, history, search, context, and resolution when asked.
- Treat a download as a local file write. Use an explicit destination or a safe
  workspace default, and never overwrite an existing path without confirmation.
- Treat an explicit send, reply, edit, forward, upload, reaction, read, mute, or
  archive request as authorization only when the target is unambiguous.
- Clarify an ambiguous recipient before any external write.
- Require confirmation immediately before deletion, history deletion, leaving,
  bans, contact removal, profile/admin changes, or session termination. State
  the exact target and effect, then add `--yes` only after that confirmation.
- Never retry or repeat a write after an uncertain result. Verify once with
  context or history and report what can be established.

## Bound realtime work

Prefer `tg wait --timeout <duration> -o json` for the next matching event. A
zero timeout is unbounded and is not allowed.

Run `tg watch` only when the host execution tool enforces the user's duration
or event-count boundary. Terminate `tg watch` as soon as that boundary is met.
If the host cannot guarantee termination, use repeated bounded `wait` calls
within the overall user-approved deadline instead. Never create a daemon.

## Protect credentials and sessions

Never request or expose a login phone number, Telegram code, QR token, 2FA
password, API credential, configuration, or session content. Let the sibling
setup skill open the separate local interactive login process.
