# Release Runbook

**Read when:** cutting, publishing, or auditing a TG Agent Plugin release.

**Do not read by default:** ordinary feature work, Telegram use, or local setup.

**Fact owner:** this runbook owns exact release procedure. The implementation
plan owns dated evidence and blockers; the architecture map owns delivery
boundaries.

## Release prerequisites

1. Confirm the plugin version matches `package.json`, both host manifests, both
   marketplace entries, the changelog, and the intended Git tag.
2. Run the complete Node, POSIX, PowerShell, validator, static-analysis,
   packaging, secret, Markdown, and link checks.
3. Complete the manual macOS, Linux, Windows, Claude Code, and Codex checklist.
4. Verify the pinned upstream assets using
   [`upstream-release-verification.md`](upstream-release-verification.md).
5. Confirm the architecture map matches the source tree and trust boundaries.

## Source-only package gate

Build the deterministic plugin archive. Inspect its complete file list and
confirm it contains the nested plugin payload plus required license and notice
files. It must contain no `tg` binaries, executable archives, Telegram config,
session data, credentials, temporary files, backups, or generated logs.

GitHub release attachments are source-only. Attach the reviewed plugin archive
and checksums for this project if the release workflow produces them, but attach
no `tg` binaries. Upstream binaries remain available only from
<https://github.com/gotd/cli/releases>.

Run the local source and supply-chain gates from the repository root:

```sh
npm test
npm run validate:plugin
npm run security:scan
npm run verify:upstream
npm run package
tar -tzvf dist/tg-agent-plugin-0.3.0.tar.gz
```

On Windows, also run the native lifecycle harness:

```powershell
npm run test:windows
```

## Publish

1. Review the complete Git diff and commit history.
2. Push the reviewed `main` branch to
   <https://github.com/KirillSidorenko/tg-agent-plugin>.
3. Create the semantic version tag matching the host manifests.
4. Publish release notes that state the plugin version, tested `gotd/cli`
   version, supported matrix, wrapper-only status, and known limitations.
5. Verify license detection, README rendering, links, issue forms, and GitHub
   Actions on the public repository.
6. Install once from the public source in both available hosts and record the
   result in the implementation plan.

Do not publish while a required platform, host, digest, credential-boundary, or
package-content gate remains open.
