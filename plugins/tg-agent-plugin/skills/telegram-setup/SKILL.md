---
name: telegram-setup
description: Install, authorize, verify, repair, or explicitly check updates for the local gotd/cli client used by TG Agent. Use when tg is missing, local Telegram login is required, installation is damaged, the user asks about setup or updates, or the sibling telegram skill delegates lifecycle work.
---

# Telegram Setup

Own installation, authorization, repair, and update reporting for the local
personal-account client. Never route ordinary Telegram commands through this
skill; return to the sibling `telegram` skill when setup is ready.

TG Agent Plugin is only a wrapper around the independent open-source
[`gotd/cli`](https://github.com/gotd/cli) client. It does not implement Telegram
or redistribute `tg` binaries.

## Resolve the lifecycle command

Resolve the plugin root two directories above this skill directory. Use the
script for the current platform:

- macOS or Linux:
  `/bin/sh <plugin-root>/scripts/tg-tool.sh <action> --json`
- Windows:
  `powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File <plugin-root>\scripts\tg-tool.ps1 -Action <action> -Json`

For authorization, add `--mode phone|qr` on POSIX or `-Mode phone|qr` on
Windows. Read [`references/platforms.md`](references/platforms.md) for paths,
supported systems, and result routing.

## Choose one action

- `status`: inspect local availability without network access.
- `install`: download and install the release pinned by this plugin.
- `repair`: reinstall that same pinned release while preserving Telegram data.
- `check-update`: report the current upstream release without installing it.
- `authorize`: check once, then open or hand off a separate local login process.
- `verify-authorization`: perform one post-login verification after the user
  reports completion.

Do not invent actions, versions, flags, or lifecycle paths.

## Install or repair safely

Run `status` first for a setup request. If the client is missing, explain the
upstream repository, pinned version, selected asset, and per-user destination.
Obtain explicit consent immediately before install. Consent to setup is not
consent to a different upstream version.

Use `repair` only after a failed or damaged managed installation. Neither
action may delete or export `gotd/cli` configuration or Telegram sessions.
Stop on host, tag, checksum, archive, smoke, stale-backup, or rollback errors;
do not offer a bypass.

Treat `newer-unpinned` as report-only. Show the official release link and
explain that a newer client becomes installable only in a tested plugin release.
Never modify the compatibility manifest during a user setup flow.

## Authorize locally

Use phone mode by default and QR only when requested. Before launch, tell the
user to enter the phone number, Telegram code, QR token, and 2FA password only
inside the new local terminal window.

Run `authorize` once. On `already-authorized`, stop. On `login-started`, ask the
user to finish locally and report completion. On `manual-required`, show the
single returned secret-free command exactly. Do not poll.

After the user reports completion, run `verify-authorization` exactly once. Do
not request, relay, log, screenshot, or persist a credential or session value.
Read [`references/authentication.md`](references/authentication.md) for the full
secret boundary and failure routing.
