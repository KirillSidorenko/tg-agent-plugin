# Manual Platform and Host Tests

**Read when:** preparing a release or recording platform/host validation.

**Do not read by default:** ordinary development that does not change lifecycle,
host manifests, packaging, or release compatibility.

**Fact owner:** this runbook owns the manual checklist and evidence format. The
implementation plan owns completed results; exact upstream digest verification
belongs to the upstream release runbook.

## Required matrix

- [ ] macOS amd64
- [ ] macOS arm64
- [ ] Linux amd64
- [ ] Linux arm64
- [ ] Windows amd64
- [ ] Windows arm64
- [ ] Claude Code marketplace install and skill discovery
- [ ] Codex marketplace install and skill discovery

Unchecked rows block a public release. Static manifest coverage does not replace
an executable platform check.

## Per-platform lifecycle checklist

1. Use a clean local OS user or disposable VM with no `tg` on `PATH`.
2. Run `status` and confirm the platform, architecture, missing state, and
   per-user destination.
3. Approve `install`. Confirm the exact pinned GitHub asset, checksum success,
   strict archive inspection, smoke checks, and non-secret state file.
4. Run `status` again and confirm the managed executable is ready.
5. Run `repair`; confirm the existing executable remains recoverable until the
   replacement passes smoke checks.
6. Simulate a bad checksum and failed smoke result with the platform harness;
   confirm the current executable remains intact.
7. Run `check-update`; confirm an unpinned result is report-only.
8. Exercise the platform login launcher without recording its terminal. Confirm
   phone and QR modes accept credentials only in the local process.
9. Remove the host plugin and confirm Telegram configuration and sessions remain.

## Per-host checklist

1. Add the repository marketplace from the release tag or reviewed commit.
2. Install `tg-agent-plugin@tg-agent`.
3. Start a fresh task or host session.
4. Confirm both `telegram` and `telegram-setup` are discoverable with the correct
   host namespace.
5. Run setup status, one representative read-only request, one negative bot
   request, and one ambiguous-write prompt without executing a write.
6. Confirm starter prompts, assets, upstream links, and privacy wording render.

## Evidence format

Record the date, OS image/version, architecture, host/version, plugin commit or
tag, pinned upstream version, commands executed, and pass/fail result in the
implementation plan. No credential value, phone number, Telegram content,
session path, QR image, terminal transcript, or private filesystem locator may
appear in evidence.
