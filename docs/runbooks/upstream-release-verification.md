# Upstream Release Verification

**Read when:** changing the pinned `gotd/cli` version, its supported asset set,
or its committed checksums.

**Do not read by default:** ordinary plugin, skill, documentation, or host
manifest work that does not change upstream compatibility.

**Fact owner:** this runbook owns the exact upstream verification procedure.
The release manifest owns installable compatibility data; the implementation
plan owns dated execution evidence.

## Approved upstream

- Repository: <https://github.com/gotd/cli>
- Release: <https://github.com/gotd/cli/releases/tag/v0.11.0>
- Checksums: <https://github.com/gotd/cli/releases/download/v0.11.0/checksums.txt>
- Compatibility manifest:
  [`plugins/tg-agent-plugin/config/release-manifest.json`](../../plugins/tg-agent-plugin/config/release-manifest.json)

TG Agent Plugin is only a wrapper around this independent client. Never copy or
attach upstream binaries to this repository or its releases.

## Verification procedure

1. Read the release through GitHub's repository API and confirm the exact tag,
   publisher, release page, asset names, asset URLs, and GitHub-provided
   `sha256:` digests.
2. Download `checksums.txt` from the same exact tag. Do not follow a `latest`
   URL and do not accept a checksum file from another host.
3. Select only the `.tar.gz` assets for `darwin`, `linux`, and `windows` on
   `amd64` and `arm64`.
4. Confirm every selected checksum is identical in the upstream checksum file
   and the corresponding GitHub asset digest.
5. Update the release-contract test with exact expected names and checksums
   before changing the compatibility manifest.
6. Update the compatibility manifest and make the release-contract test pass.
7. Download and inspect each asset through the integration checks. Confirm the
   archive policy and the unauthenticated smoke-command contract before making
   the new version installable.
8. Complete every required platform checklist and release a new plugin version.

## Initial verification evidence

On 2026-08-04, the six `v0.11.0` `.tar.gz` asset digests returned by the GitHub
release API matched the six entries in upstream `checksums.txt`. The local
installed client also confirmed the unauthenticated `--help`, `whoami --help`,
and `login --help` command surface. `tg version` was deliberately excluded
because `v0.11.0` does not provide that command.
