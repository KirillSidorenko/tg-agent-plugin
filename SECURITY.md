# Security Policy

## Supported versions

TG Agent Plugin has not published its first public release. Security fixes will
be provided for the latest released minor version once `0.3.0` is available.

## Reporting a vulnerability

Do not disclose suspected vulnerabilities in a public issue. Use GitHub's
[private vulnerability report](https://github.com/KirillSidorenko/tg-agent-plugin/security/advisories/new).
If private reporting is temporarily unavailable, do not include credentials,
session data, Telegram content, or exploit details in any public channel.

Maintainers will acknowledge a complete report, assess affected versions, and
coordinate remediation and disclosure through the private report.

## Credential boundary

Phone numbers used for login, Telegram login codes, QR tokens, 2FA passwords, API
credentials, and Telegram session data must remain inside the local interactive
`gotd/cli` process. The plugin must never accept them through agent chat,
command arguments, environment variables, redirected input, logs, fixtures,
screenshots, or committed files.

## Supply-chain policy

- Install only the `gotd/cli` release pinned by the plugin release manifest.
- Download only from the official `github.com/gotd/cli` release path.
- Verify the committed SHA-256 before extraction.
- Reject archives with unsafe paths, links, unexpected files, or duplicate
  executable candidates.
- Keep the previous executable until the replacement passes smoke checks.
- Never bundle or redistribute an upstream `tg` binary.

A checksum or archive validation failure stops installation. A replacement
failure triggers rollback to the previous executable rather than a bypass.

## Data handling

The plugin owns only non-secret installation metadata. It does not persist
Telegram messages, contacts, media contents, credentials, configuration, or
sessions. Uninstall and repair preserve Telegram configuration and sessions by
default.
