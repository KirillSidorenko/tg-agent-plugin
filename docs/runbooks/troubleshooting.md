# Troubleshooting

**Read when:** installation, authorization, update reporting, host discovery, or
an ordinary `tg` operation fails.

**Do not read by default:** successful ordinary Telegram requests.

**Fact owner:** this runbook owns user-facing diagnosis paths. The lifecycle
scripts own result production; the implementation plan owns test evidence.

## Host discovery

- Marketplace missing: list configured marketplaces and confirm `tg-agent`
  resolves to the reviewed GitHub source.
- Plugin missing: install `tg-agent-plugin@tg-agent`, then start a new task or
  restart the host.
- Skill missing: confirm both skill folders exist in the installed payload and
  validate the host manifest.

## Lifecycle results

- `missing`: review the pinned source and destination, then request install
  consent.
- `Checksum mismatch`: stop. Preserve the current executable and report the
  selected platform and asset without attaching the archive.
- Archive validation failure: stop. Do not extract manually or bypass the
  rejected path, link, duplicate, or unexpected entry.
- Smoke failure: confirm rollback restored the previous executable.
- `stale backup`: do not overwrite it. Inspect the managed executable and
  backup as a repair incident before retrying.
- `newer-unpinned`: show the upstream release link. Do not install it.
- Offline update check: continue using the installed pinned client when normal
  Telegram work is still possible.

## Authorization results

- `already-authorized`: do not open another login window.
- `login-started`: wait for the user to finish locally; do not poll.
- `manual-required`: show the returned secret-free Linux worker command once.
- `not-authorized`: offer another local login attempt without requesting a
  credential in chat.
- Launcher unavailable: verify the documented terminal allowlist or Windows
  PowerShell availability. Do not redirect login input or record a transcript.

## Ordinary command outcomes

For a rejected argument, make one targeted `tg <command> --help` call. For an
uncertain write, verify once with context or history and never repeat blindly.
See the bundled Telegram troubleshooting reference for tested `v0.11.0`
outcomes.

Never attach session files, config files, credentials, phone numbers, QR images,
or private Telegram content to an issue.
