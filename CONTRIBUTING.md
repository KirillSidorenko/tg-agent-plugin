# Contributing to TG Agent Plugin

Thank you for helping improve this unofficial local wrapper around
[`gotd/cli`](https://github.com/gotd/cli).

## Development workflow

Every behavior change uses red/green TDD:

1. Add or update a test that fails for the intended reason.
2. Implement the minimum change that makes it pass.
3. Refactor only while the complete suite remains green.

Run all dependency-free checks with:

```sh
npm test
```

Keep public source, tests, documentation, comments, commit messages, and issue
content in English.

## Security rules

- Never commit or request Telegram phone numbers, login codes, QR tokens, 2FA
  passwords, API credentials, configuration, sessions, or downloaded message
  contents.
- Never add a `tg` binary to this repository, a fixture, a package, or a GitHub
  release.
- Never bypass archive, checksum, host, or pinned-version validation.
- Never add automatic `--yes`; destructive operations require confirmation of
  the exact target and effect immediately before execution.
- Never introduce bots, remote sessions, telemetry, hosted services, or a
  persistent watcher.

## Platform changes

Changes to installation, authorization, archives, replacement, rollback, or
managed paths require tests for every affected operating system. Hosted CI does
not replace the manual release checklist for architecture combinations that it
cannot execute.

Run the Windows PowerShell harness, the macOS POSIX harness, and the Linux POSIX
harness before releasing any cross-platform lifecycle change.

## Upstream compatibility

The plugin pins one tested `gotd/cli` version per release. A compatibility
update must change the release manifest, add or update contract tests, verify
every checksum, complete the platform checklist, and document the change here.

## Reporting vulnerabilities

Do not open a public issue for a suspected vulnerability. Follow
[`SECURITY.md`](SECURITY.md).
