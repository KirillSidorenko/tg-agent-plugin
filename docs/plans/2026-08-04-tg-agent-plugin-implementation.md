# TG Agent Plugin Implementation Plan

**Date:** 2026-08-04
**Status:** In progress
**Target release:** `0.3.0`

## Objective

Build, validate, and publicly release the approved `tg-agent-plugin` design as one English-language GitHub repository and one shared local plugin payload for Claude Code and Codex. The implementation must preserve the current local plugin's useful behavior while replacing its dynamic-upstream update model with a pinned, tested `gotd/cli v0.11.0` contract and adding Linux support.

This plan is the canonical owner for implementation sequence, progress, and verification evidence. Product behavior and trust boundaries remain owned by the approved design and architecture overview.

## Preconditions and constraints

- Do not begin implementation until the user approves this plan.
- Read the project map and the approved design before each implementation phase.
- Use red/green TDD for every behavior change.
- Treat `/Users/sidorenko/.codex/plugins/telegram-agent` as a read-only behavioral reference. Copy only deliberately reviewed content; do not edit or depend on that installed cache.
- Keep all public repository content in English.
- Do not add an MCP server, bot flow, remote session, daemon, telemetry, bundled `tg` binary, or automatic unpinned update.
- Do not publish until the local release gate is green.
- Preserve unrelated user files and never read or copy Telegram session contents.

## Phase 1 — Repository and test harness baseline

### Red

1. Add a Node built-in test suite that asserts the required repository files, nested plugin layout, English public-document policy, forbidden binary/session patterns, and initial target version.
2. Run the suite and record the expected failures for files not yet created.

### Green

1. Initialize the Git repository without creating a remote.
2. Add `.gitignore`, `package.json` with dependency-free test scripts, MIT `LICENSE`, `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, and `THIRD_PARTY_NOTICES.md` skeletons containing complete initial content rather than placeholders.
3. Create the planned plugin, test, runbook, asset, and GitHub workflow directories.
4. Make the repository-contract tests pass.

### Refactor and verify

- Remove duplicated policy prose by assigning canonical ownership to the design, security document, or contribution guide.
- Check the architecture overview and update only status and current repository topology.
- Run the Node baseline suite and Markdown whitespace checks.

## Phase 2 — Cross-host manifests and marketplaces

### Red

1. Add `tests/manifest.test.mjs` covering the Claude Code manifest, Codex manifest, both marketplace files, matching plugin identity/version, nested source path, capabilities, upstream wording, and asset references.
2. Add negative fixtures for path traversal, mismatched versions, unsupported fields, missing policy, and more than three starter prompts.
3. Confirm the new tests fail because the manifests do not exist.

### Green

1. Create `.codex-plugin/plugin.json` and `.claude-plugin/plugin.json` inside the nested payload.
2. Create the repository-level Codex and Claude marketplace catalogs pointing to `./plugins/tg-agent-plugin`.
3. Use version `0.3.0`, display name `TG Agent`, and the required unofficial/upstream description.
4. Add non-logo brand assets that do not use Telegram trademarks.
5. Make manifest tests pass with only host-supported fields.

### Refactor and verify

- Run the local Codex validator.
- Run `claude plugin validate` when Claude Code is available; otherwise rely on schema tests and make the missing host validation an explicit release-gate item.
- Confirm both marketplaces resolve the identical payload.

## Phase 3 — Pinned upstream release contract

### Red

1. Add tests for `release-manifest.json`: exact `v0.11.0` tag, six OS/architecture combinations, official GitHub release origin, expected asset naming, lowercase 64-character SHA-256 values, and required smoke commands.
2. Add tests that reject missing, duplicate, malformed, unrecognized, or non-GitHub entries.

### Green

1. Read the official `gotd/cli v0.11.0` release metadata and checksum asset.
2. Populate the manifest with macOS, Linux, and Windows assets for amd64 and arm64.
3. Cross-check committed hashes against both upstream checksums and GitHub asset digests when available.
4. Make release-contract tests pass.

### Refactor and verify

- Keep release lookup/parsing logic independent of lifecycle script implementation.
- Record source URLs and verification date in the release runbook, not in the architecture overview.

## Phase 4 — POSIX lifecycle core for macOS and Linux

### Red

1. Add a self-contained POSIX test harness with task-specific temporary paths and command shims.
2. Add failing tests for status resolution, OS/architecture mapping, managed paths, pinned URLs, checksum verification, safe archive inspection, atomic replacement, rollback, repair, explicit update reporting, stable JSON results, and cleanup confinement.
3. Add negative tests for unsupported systems, host mismatch, tag mismatch, missing asset, checksum mismatch, absolute paths, parent traversal, symlinks/hard links, duplicate `tg` candidates, failed smoke checks, and stale temporary paths.

### Green

1. Implement `tg-tool.sh` with macOS/Linux platform detection and test injection points that cannot affect normal runtime.
2. Read compatibility data from the bundled release manifest rather than from `latest`.
3. Implement pinned download, dual digest checks where available, pre-extraction archive validation, constrained temporary cleanup, atomic installation, rollback, non-secret state, and status/repair/check-update actions.
4. Keep ordinary Telegram commands outside the lifecycle script.
5. Make all POSIX tests pass under `/bin/sh` on macOS and Ubuntu.

### Refactor and verify

- Run ShellCheck and both shell implementations used by CI where available.
- Compare behavior against the current local macOS lifecycle script without copying obsolete dynamic-update behavior.

## Phase 5 — Local authorization launchers

### Red

1. Add tests that inspect the exact constructed login command and reject phone numbers, codes, passwords, tokens, redirected input, secret environment variables, and transcript capture.
2. Add launcher tests for macOS Terminal, Windows PowerShell, the supported Linux terminal-emulator allowlist, and the headless Linux manual handoff.
3. Add tests for phone-default, QR-explicit, already-authorized, launcher-unavailable, and post-login single-verification outcomes.

### Green

1. Implement separate macOS, Linux, and Windows login launchers.
2. Initialize `gotd/cli` configuration only when absent.
3. Use `tg login --phone=` for prompted phone login and `tg login` for QR login.
4. Return only non-secret launcher status to the agent.
5. Make launcher tests pass without performing a real login.

### Refactor and verify

- Ensure terminal selection is deterministic and documented.
- Confirm headless fallback contains one executable command and no credential value.

## Phase 6 — Windows lifecycle parity

### Red

1. Add PowerShell tests matching the POSIX lifecycle contract and security negatives.
2. Confirm they fail before the Windows implementation exists.

### Green

1. Implement `tg-tool.ps1` with the same pinned manifest, state schema, archive rules, atomic replacement, rollback, authorization routing, and update-reporting behavior.
2. Use Windows-native path and process APIs without administrator privileges.
3. Make the PowerShell suite pass on Windows.

### Refactor and verify

- Run PSScriptAnalyzer.
- Compare JSON result fixtures across POSIX and Windows and remove unintended platform drift.

## Phase 7 — Shared English skills and references

### Red

1. Add static skill tests for valid frontmatter, stable names, portable sibling-skill routing, direct `tg` invocation, JSON parsing rules, minimal querying, login secrecy, recipient disambiguation, download overwrite protection, bounded watch behavior, uncertain-write verification, and destructive confirmation.
2. Add negative tests that flag bot setup, hosted MCP language, remote sessions, automatic `--yes`, login secrets in arguments/environment, unbounded watchers, or claims of official Telegram status.

### Green

1. Adapt the existing local `telegram` and `telegram-setup` behavior into English, host-portable skills.
2. Add concise command, authentication, troubleshooting, and platform references through progressive disclosure.
3. Keep upstream acknowledgements and wrapper boundaries visible in setup documentation.
4. Make skill tests pass.

### Refactor and verify

- Validate each skill with the Codex skill validator.
- Validate installed namespacing in both host package structures.
- Keep each main `SKILL.md` compact and move detailed recipes into references.

## Phase 8 — Public documentation and operational runbooks

### Red

1. Extend documentation tests for required upstream links, acknowledgements, unofficial wording, support matrix, install paths, credential boundaries, update policy, uninstall preservation, security reporting, contribution TDD rules, and absence of unredacted secret examples.
2. Add link checks and fail on missing local targets.

### Green

1. Complete README installation and usage flows for Claude Code and Codex.
2. Complete security, third-party, contributing, changelog, troubleshooting, release, uninstall, and manual platform-test documentation.
3. Add issue templates that route suspected vulnerabilities to `SECURITY.md`.
4. Make documentation tests pass.

### Refactor and verify

- Remove duplicated exact commands from overview documents and keep them in runbooks.
- Recheck every trademark, official-status, and binary-redistribution statement.

## Phase 9 — CI, packaging, and supply-chain gates

### Red

1. Add tests that inspect the intended plugin package and reject executable binaries, Telegram configuration/session filenames, credentials, temporary files, backups, test secrets, and files outside the allowlisted payload.
2. Confirm the checks fail against deliberately unsafe fixtures.

### Green

1. Add Ubuntu, macOS, and Windows GitHub Actions jobs for Node tests, POSIX tests, PowerShell tests, manifest validation, static analysis, secret scanning, Markdown/link checks, release asset verification, and packaging inspection.
2. Add a deterministic source-only packaging script that includes the nested payload and required license/notice files but no `tg` binary.
3. Add release-check documentation for architecture combinations not exercised by hosted runners.
4. Make local CI-equivalent commands pass.

### Refactor and verify

- Minimize third-party GitHub Actions and pin every external action to a reviewed immutable commit.
- Confirm workflows never access Telegram credentials or sessions.

## Phase 10 — Host integration and platform validation

1. Install the repository marketplace locally in Codex and verify skill discovery in a new task.
2. Install the repository marketplace in Claude Code and verify namespacing and setup discovery when the CLI is available.
3. Exercise non-authenticated status, archive validation, install, repair, and rollback with isolated test paths.
4. On the user's already-authorized macOS account, run only read-only representative Telegram checks unless the user separately requests a write test.
5. Complete the documented manual smoke checklist on macOS, Linux, and Windows. Where a physical platform is unavailable, keep the release blocked rather than silently claiming coverage.
6. Record exact test commands and results in the implementation plan's evidence section.

## Phase 11 — Public GitHub publication

1. Confirm every automated test and required manual release gate is green.
2. Inspect the authenticated GitHub identity and ensure the repository name `tg-agent-plugin` is available under that account.
3. Create the public GitHub repository, set the description and topics, and push the reviewed source history.
4. Verify README rendering, links, license detection, issue templates, and Actions from the public repository.
5. Create source-only release `0.3.0` with release notes that name `gotd/cli v0.11.0`, supported platforms, wrapper status, and known limitations.
6. Confirm the release contains no `tg` binaries or session-like artifacts.
7. Test installation once from the public GitHub marketplace source in both available hosts.

## Verification commands and evidence ownership

Exact commands belong in `docs/runbooks/`; live results belong in the evidence section below. The architecture overview must contain neither volatile test counts nor publication history.

## Implementation evidence

### Phase 1 — Repository and test harness baseline

- **Date:** 2026-08-04
- **Red:** The initial repository contract produced two expected failures for missing baseline files and the missing package manifest; the English-content and forbidden-file checks already passed.
- **Green:** The dependency-free Node suite passed all four repository-contract tests after the English public documents, package metadata, local Git repository, and planned top-level directories were created.
- **Environment:** macOS with Node.js `v24.15.0`.

### Phase 2 — Cross-host manifests and marketplaces

- **Date:** 2026-08-04
- **Red:** Three expected failures identified the missing Claude Code manifest, Codex manifest, both repository marketplaces, and the referenced brand asset. Negative schema fixtures already passed. A later Claude marketplace-description test reproduced the host validator warning before its fix.
- **Green:** All four manifest-contract tests passed. The Codex plugin validator and Claude Code marketplace validator both accepted the shared nested payload; Claude Code reported no remaining warnings.
- **Environment:** macOS, Claude Code `2.1.221`, and the bundled Codex validator with an isolated temporary `PyYAML` dependency.

### Phase 3 — Pinned upstream release contract

- **Date:** 2026-08-04
- **Red:** The compatibility test produced one expected failure for the missing release manifest; malformed host, tag, digest, platform, and duplicate-platform fixtures were rejected.
- **Green:** Both release-contract tests passed with exact names and SHA-256 values for all six `gotd/cli v0.11.0` `.tar.gz` assets.
- **Upstream evidence:** GitHub's release API asset digests matched the official `checksums.txt` entries for macOS, Linux, and Windows on amd64 and arm64. The local `v0.11.0` command surface confirmed three unauthenticated smoke checks and confirmed that no `tg version` command exists.
- **Environment:** macOS, GitHub CLI `2.88.0`, and local `tg v0.11.0` compatibility evidence.

### Phase 4 — POSIX lifecycle core for macOS and Linux

- **Date:** 2026-08-04
- **Red:** The POSIX harness failed first because `tg-tool.sh` did not exist.
- **Green:** Nine isolated shell scenarios passed for macOS/Linux platform mapping, PATH-first status, unsupported-platform rejection, install, repair, checksum mismatch, strict archive shape, traversal and link rejection, atomic replacement, failed-smoke rollback, stale-backup refusal, confined temporary cleanup, and report-only unpinned update detection.
- **Runtime evidence:** A read-only status call in the real macOS arm64 environment resolved the existing `/Users/sidorenko/.local/bin/tg` and returned the stable JSON envelope without invoking Telegram.
- **Environment:** macOS arm64 under `/bin/sh`, with network, archive, checksum, platform, filesystem, and smoke-command effects isolated by the harness.

### Phase 5 — Local authorization launchers

- **Date:** 2026-08-04
- **Red:** Both authorization suites failed first because the macOS, Linux, and Windows launchers did not exist. The first harness replay also exposed and corrected an invalid fake-client pattern and a background-launch observation race without changing product behavior.
- **Green:** Four dynamic POSIX scenarios and two Windows static contracts passed for phone-default and QR modes, initialize-once behavior, macOS Terminal command construction, deterministic Linux terminal selection, headless handoff, Windows PowerShell isolation, already-authorized detection, and one-shot post-login verification.
- **Credential evidence:** Fake-client logs confirmed that login receives only `--phone=` or no login argument and that `TG_PASSWORD`, `APP_ID`, `APP_HASH`, and `BOT_TOKEN` are absent. No transcript, redirected login input, credential value, or polling path exists.
- **Environment:** macOS arm64 under `/bin/sh`; Windows execution remains a Phase 6/CI gate because PowerShell is unavailable locally.

### Phase 6 — Windows lifecycle parity

- **Date:** 2026-08-04
- **Red:** Two static contract tests failed first because the PowerShell lifecycle and native Windows harness did not exist.
- **Green available locally:** Both static contracts passed for action parity, pinned manifest parsing, GitHub release confinement, SHA-256, pre-extraction archive inspection, backup/rollback, user-local paths, credential-environment removal, and required negative harness cases.
- **Implemented native gate:** The dependency-free PowerShell harness covers pinned asset selection, install state, checksum mismatch, absolute path, parent traversal, symbolic link, hard link, duplicate executable, failed-smoke rollback, stale backup, and report-only unpinned updates.
- **Blocked evidence:** The native harness and PSScriptAnalyzer have not run because `pwsh` is unavailable in the local macOS environment. Phase 9 Windows CI must execute both before release; Phase 6 is implementation-complete but not platform-validated.

### Phase 7 — Shared English skills and references

- **Date:** 2026-08-04
- **Red:** Three expected skill-contract failures identified the missing `telegram` and `telegram-setup` bundles; unsafe fixture detection passed from the start.
- **Green:** Four static contracts passed for minimal frontmatter, UI metadata, direct `tg` execution, JSON/stdout/stderr handling, broad-result reuse, targeted help, sibling routing, ambiguity and destructive gates, uncertain-write verification, overwrite protection, bounded realtime work, pinned lifecycle ownership, and local login secrecy.
- **Validator evidence:** Both skills passed `skill-creator` validation in an isolated temporary `PyYAML` environment. The full payload also passed the Codex plugin validator and Claude Code marketplace validator.
- **Forward-test note:** No subagent forward-test was run because project routing prohibits unrequested delegation. Phase 10 retains real host discovery and representative read-only usage gates.

### Phase 8 — Public documentation and operational runbooks

- **Date:** 2026-08-04
- **Red:** Four documentation tests failed for missing runbooks/issue routing and incomplete host installation, security, contribution, and release wording; local-link and placeholder validation was already green.
- **Green:** All five documentation contracts passed for real Claude Code/Codex commands, public repository URLs, first login, privacy, updates, uninstall preservation, troubleshooting, upstream links and acknowledgements, private security routing, TDD contribution rules, source-only release policy, manual platform matrix, issue forms, local links, and placeholder absence.
- **Source evidence:** Current Codex manual/CLI and current Claude Code CLI plus official marketplace documentation confirmed the marketplace-add and plugin-install flows. GitHub identity `KirillSidorenko` was resolved through the authenticated GitHub CLI.

### Phase 9 — CI, packaging, and supply-chain gates

- **Date:** 2026-08-04
- **Red:** The workflow and package contracts first failed for missing CI/release workflows and a missing packager. The security scanner contract then failed for its missing implementation, and its first repository scan identified a safe test sentinel that required narrowing the high-entropy assignment rule.
- **Green:** The full local suite passed 32 Node contracts, ten isolated POSIX lifecycle scenarios, and four authorization-launcher scenarios. The dependency-free validator accepted the payload, the source scanner reported no credential/session/binary artifacts, and the upstream verifier matched all six pinned assets against the official checksum file and GitHub digests.
- **Package evidence:** Two builds of `dist/tg-agent-plugin-0.3.0.tar.gz` were byte-for-byte identical. The archive contains 19 allowlisted source and notice files with normalized metadata, no bundled `tg`, and no session-like artifact.
- **Workflow evidence:** CI covers Node contracts on Ubuntu, macOS, and Windows; POSIX behavior on Ubuntu and macOS; PowerShell behavior and PSScriptAnalyzer on Windows; ShellCheck; plugin validation; source scanning; deterministic packaging; and live upstream metadata verification. All external Actions are pinned to immutable 40-character commits.
- **Open platform gate:** These workflows have not run on GitHub yet. Native Windows, PSScriptAnalyzer, and hosted-runner results remain release blockers until publication of the source branch enables CI.

### Phase 10 — Host integration and platform validation

- **Date:** 2026-08-04
- **Host installation:** The local repository marketplace installed `tg-agent-plugin@tg-agent` version `0.3.0` in Codex and Claude Code. Host inventories reported the plugin enabled, with Claude Code explicitly listing the two-skill component inventory and no agent, hook, MCP, or LSP component.
- **Fresh-session discovery:** An ephemeral read-only Codex session resolved `tg-agent-plugin:telegram` and `tg-agent-plugin:telegram-setup`. Two no-tool Claude Code sessions invoked `/tg-agent-plugin:telegram` and `/tg-agent-plugin:telegram-setup` successfully.
- **Safety behavior:** Fresh no-tool sessions in both hosts rejected bot setup as out of scope and required recipient clarification for a hypothetical ambiguous `Alex` write. No Telegram command was executed for these scenarios.
- **Real macOS arm64 lifecycle:** A clean isolated home completed missing status, pinned install, ready status, repair, update check, and all three real `gotd/cli v0.11.0` smoke commands. The first run exposed cleanup failure when macOS supplied a trailing-slash `TMPDIR`; a new failing regression test reproduced it, path normalization fixed it, and the repeated real install/repair confirmed cleanup.
- **Local account check:** One authorized `chats list` read parsed as JSON. The local filter emitted only `{jsonParsed, itemCount, contentEmitted}` evidence and no chat, account, phone, message, or session content.
- **Open matrix gate:** macOS amd64, Linux amd64/arm64, and Windows amd64/arm64 executable checks remain unavailable locally. Windows harness, PSScriptAnalyzer, and hosted CI remain blocked until the source branch is pushed; the `0.3.0` release must remain unpublished meanwhile.

Each later completed phase will add its test result, platform, and date here without removing earlier release-relevant evidence.

## Completion gate

The implementation is complete only when all approved design acceptance criteria are satisfied, the architecture map matches the implemented topology, CI and required manual platform checks are green, the source-only public repository and `0.3.0` release exist, and installation from that public source has been verified. Partial platform coverage, missing host validation, unreviewed upstream hashes, or any credential-boundary failure blocks publication.
