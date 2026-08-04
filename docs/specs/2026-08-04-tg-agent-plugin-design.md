# TG Agent Plugin Design

**Date:** 2026-08-04
**Status:** Approved

## Decision summary

`tg-agent-plugin` will be a public, English-language, source-only GitHub repository that packages one local integration for Claude Code and Codex. It will let an agent work with a user's local Telegram personal account through the independent open-source [`gotd/cli`](https://github.com/gotd/cli) client.

The plugin is a thin installation, workflow, and safety wrapper. It does not implement Telegram or MTProto, redistribute `tg`, host an MCP server, operate a bot, or store Telegram sessions remotely.

The first release supports macOS, Linux, and Windows on amd64 and arm64.

## Goals

- Install and configure a tested `tg` release without administrator privileges.
- Keep login credentials and Telegram session data local to the user's device.
- Expose one shared set of Telegram skills to Claude Code and Codex.
- Support common personal-account workflows: chat discovery, history, search, sending, replying, editing, forwarding, media transfer, bounded realtime waiting, and basic chat actions.
- Apply clear confirmation gates to ambiguous, destructive, administrative, and session-changing operations.
- Publish an auditable repository with platform tests, CI, security documentation, upstream attribution, and reproducible release metadata.

## Non-goals

- ChatGPT Web connectivity.
- A hosted or local MCP server.
- Telegram Bot API or bot-account setup.
- Remote storage or synchronization of Telegram sessions.
- A custom Telegram or MTProto implementation.
- Bundling, modifying, or redistributing `tg` binaries.
- Background daemons, persistent watchers, telemetry, analytics, or advertising.
- Automatic installation of arbitrary future `gotd/cli` releases.

## Product identity and attribution

- Repository and package identifier: `tg-agent-plugin`.
- Public display name: `TG Agent`.
- Required descriptor: `Unofficial local agent integration for Telegram, powered by gotd/cli.`
- The project must not use the official Telegram logo or imply Telegram endorsement.

The README introduction must state substantially:

> TG Agent Plugin is a thin integration and safety layer around the independent open-source [gotd/cli](https://github.com/gotd/cli) client. It does not implement the Telegram protocol, ship its own Telegram client, or redistribute `tg` binaries.

The repository will link directly to the upstream [source](https://github.com/gotd/cli), [releases](https://github.com/gotd/cli/releases), and [MIT license](https://github.com/gotd/cli/blob/main/LICENSE). `THIRD_PARTY_NOTICES.md` will thank Aleksandr Razumov ([@ernado](https://github.com/ernado)), the gotd maintainers, and all contributors, and will describe the dependency and responsibility boundary.

## Repository structure

```text
tg-agent-plugin/
├── .agents/plugins/marketplace.json
├── .claude-plugin/marketplace.json
├── .github/
│   ├── ISSUE_TEMPLATE/
│   └── workflows/
├── docs/
│   ├── architecture/project-map.md
│   ├── runbooks/
│   └── specs/2026-08-04-tg-agent-plugin-design.md
├── plugins/tg-agent-plugin/
│   ├── .claude-plugin/plugin.json
│   ├── .codex-plugin/plugin.json
│   ├── assets/
│   ├── config/release-manifest.json
│   ├── scripts/
│   │   ├── tg-login-linux.sh
│   │   ├── tg-login-macos.sh
│   │   ├── tg-login-windows.ps1
│   │   ├── tg-tool.ps1
│   │   └── tg-tool.sh
│   └── skills/
│       ├── telegram/
│       │   ├── SKILL.md
│       │   └── references/
│       └── telegram-setup/
│           ├── SKILL.md
│           └── references/
├── tests/
├── AGENTS.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── README.md
├── SECURITY.md
└── THIRD_PARTY_NOTICES.md
```

The nested plugin payload avoids marketplace-root compatibility ambiguity. Both marketplaces point to `./plugins/tg-agent-plugin`, and both hosts install the same skills, scripts, configuration, and assets.

## Components and responsibilities

### Host manifests

`.codex-plugin/plugin.json` owns Codex package metadata and `.claude-plugin/plugin.json` owns Claude Code package metadata. Their user-facing identity, semantic version, descriptions, upstream statement, capabilities, and asset references must remain consistent. Host-specific fields are isolated to the relevant manifest.

The repository-level Codex and Claude marketplace files each expose the nested payload from the same GitHub repository. Installation documentation provides separate host commands but describes identical runtime behavior.

### `telegram` skill

The ordinary-operation skill:

- Resolves `tg` from `PATH`, with platform-specific fallback to the plugin-managed installation.
- Delegates missing installation or authorization to `telegram-setup`.
- Calls `tg` directly rather than routing ordinary commands through lifecycle scripts.
- Adds `-o json` whenever the result will be parsed.
- Treats stdout as data and stderr as diagnostics.
- Reuses one broad result and filters locally instead of issuing one query per chat, sender, or message.
- Uses one targeted `tg <command> --help` call only after uncertain syntax or a rejected argument.
- Applies the operation safety classes defined below.

### `telegram-setup` skill

The lifecycle skill owns installation status, pinned installation, authorization launch, explicit update checks, repair, and post-login verification. It never handles ordinary Telegram commands.

### Lifecycle scripts

`tg-tool.sh` supports macOS and Linux through explicit platform detection. `tg-tool.ps1` implements equivalent Windows behavior. Small platform launchers isolate GUI-terminal differences and keep interactive login out of the agent tool transcript.

All lifecycle actions return a stable JSON envelope when requested. State contains only schema version, installed upstream version, asset name, verified archive digest, timestamps, skipped update notice, and executable path.

### Pinned release manifest

`config/release-manifest.json` is the canonical compatibility owner for:

- Tested `gotd/cli` version (`v0.11.0` for the initial release).
- Expected asset name for macOS, Linux, and Windows on amd64 and arm64.
- SHA-256 for every supported asset.
- Minimum command-contract checks required after installation.
- Direct upstream release URL.

A missing platform entry or digest is a build and validation failure.

## Installation flow

1. Resolve an existing executable from `PATH`, then check the managed install path.
2. If missing, report the upstream repository, pinned version, target asset, and local destination.
3. Obtain explicit user consent immediately before downloading and installing.
4. Download only the pinned release asset from `github.com/gotd/cli/releases`.
5. Verify the committed SHA-256 and, when supplied by GitHub, the release asset digest.
6. Inspect the archive before extraction. Reject absolute paths, parent traversal, links, unexpected executable names, duplicate candidates, and files outside the expected package shape.
7. Extract to a uniquely created temporary directory.
8. Copy to a `.new` path, preserve the previous executable as `.bak`, atomically replace the target, and run contract smoke tests.
9. Delete the backup only after all smoke tests pass. Restore it on any failure.
10. Persist non-secret install metadata and disclose any PATH profile change.

Managed paths:

| Platform | Executable | Plugin state |
| --- | --- | --- |
| macOS | `~/.local/bin/tg` | `${XDG_STATE_HOME:-$HOME/.local/state}/tg-agent-plugin` |
| Linux | `~/.local/bin/tg` | `${XDG_STATE_HOME:-$HOME/.local/state}/tg-agent-plugin` |
| Windows | `%LOCALAPPDATA%\Programs\tg\tg.exe` | `%LOCALAPPDATA%\TGAgentPlugin` |

The plugin does not change the `gotd/cli` configuration or session location.

## Authorization flow

1. Run `tg whoami -o json` only during setup or authorization diagnosis. If it succeeds, report that the account is connected.
2. Explain that phone number, Telegram code, QR token, and 2FA password must be entered only in the local login window.
3. Use phone login by default and QR only when the user requests it.
4. Launch a separate interactive process:
   - macOS: Terminal.
   - Windows: PowerShell.
   - Linux desktop: the first supported installed terminal emulator from a documented allowlist.
   - Headless Linux: provide one secret-free command for the user to run directly; do not capture its interactive input.
5. Wait for the user to report completion; do not poll.
6. Verify exactly once with `tg whoami -o json`.

Login secrets must never appear in chat, shell arguments, environment variables, redirected stdin, command history generated by the plugin, screenshots, transcripts, plugin state, logs, fixtures, or documentation. The plugin never deletes or exports Telegram configuration or session files.

## Update and repair model

- Normal installation and repair use the release pinned by the installed plugin version.
- Repair reinstalls the pinned binary without deleting Telegram configuration or sessions.
- An explicit update check may query the current upstream release and report that a newer version exists, with a direct release link. It cannot install an unpinned version.
- A newer `tg` becomes installable only after maintainers update the pinned manifest, validate command compatibility, pass CI, perform the manual platform checklist, and publish a new plugin release.
- Updates preserve the previous executable until the replacement passes all checks.
- Plugin and `tg` versions remain independent and are reported separately.

## Supported operations

The first release documents and tests:

- Chat and contact discovery.
- Recent message history and bounded context.
- Search within one chat and global search.
- Send, reply, edit, and forward text.
- Upload and download images and files.
- Reactions and basic chat state such as read, mute, and archive.
- One-shot waiting and explicitly bounded realtime watch.

The broader `tg` command surface remains available only when the user explicitly requests an operation and the skill obtains command-specific help instead of guessing syntax.

## Safety policy

| Class | Examples | Required behavior |
| --- | --- | --- |
| Read-only Telegram | list chats, history, search, context, resolve | Proceed when requested; minimize scope and reuse broad results locally. |
| Local file write | download media | Require an explicit destination or safe workspace default; never overwrite without confirmation. |
| External write | send, reply, edit, forward, upload, react, mark read, mute, archive | The user's explicit request authorizes the action only for an unambiguous target. Clarify ambiguous recipients. |
| Destructive/admin/session | delete, delete history, leave, ban, contact removal, profile changes, admin changes, session termination | Confirm the exact target and effect immediately before execution. Add `--yes` only after confirmation. |

Additional invariants:

- Prefer usernames or cached numeric peer IDs over phone-number peers when available.
- Never resend after an uncertain write result. Verify once using context or history.
- `watch` must have a user-defined event boundary or duration and must not become a daemon.
- Do not preflight every ordinary request with `whoami`.
- Do not collect more chat history than needed for the task.
- Bot setup and remote accounts are refused as out of scope with a concise explanation.

## Data and trust boundaries

The plugin persists no Telegram messages, contacts, media contents, phone numbers, or login secrets. Downloaded media exists only at the user-selected local path. The only plugin-owned persistent data is non-secret installation and update metadata.

`gotd/cli` owns Telegram protocol access, configuration, local peer cache, and sessions. Telegram owns the remote service. Claude Code and Codex initiate commands and may receive the requested command results in their normal conversation context; the plugin adds no separate transmission or telemetry path.

All command input, upstream release metadata, archives, Telegram content, and filesystem paths are untrusted. Scripts validate them before use and constrain destructive filesystem operations to verified, explicit temporary and installation paths.

## Failure handling

- Missing binary: route to setup and ask before installation.
- Unsupported OS or architecture: fail without downloading and show the supported matrix.
- Offline release host: preserve the current installation and continue ordinary Telegram work when possible.
- Checksum, digest, or archive validation failure: stop, retain the existing binary, and report the failed validation class without bypass instructions.
- Failed smoke test: restore the previous executable.
- Authorization absent: open or hand off the local login flow; never request secrets in chat.
- Login launcher unavailable: provide one secret-free manual command.
- Ambiguous peer: stop before the write and request clarification.
- Uncertain write result: verify once; never repeat blindly.
- Changed upstream syntax: use one targeted help call, do not silently install a newer binary, and require a tested plugin release for durable compatibility updates.

## Public documentation

All repository content intended for users or contributors is English. The initial release includes:

- `README.md`: purpose, unofficial status, upstream wrapper statement, support matrix, installation for Claude Code and Codex, first login, examples, privacy model, updates, uninstall behavior, troubleshooting, and acknowledgements.
- `SECURITY.md`: vulnerability reporting, credential boundary, supported versions, and supply-chain policy.
- `THIRD_PARTY_NOTICES.md`: upstream dependency, links, license, author/maintainer thanks, and no-redistribution statement.
- `CONTRIBUTING.md`: TDD workflow, platform testing, security rules, and release expectations.
- `CHANGELOG.md`: semantic-versioned plugin changes and tested `tg` version changes.
- Issue templates for bugs, platform installation failures, compatibility reports, and security redirection.

Uninstall instructions remove only the plugin and, optionally, the plugin-managed `tg` executable and non-secret plugin state. Telegram configuration and sessions are retained by default and require a separate, explicit user-directed cleanup procedure.

## Testing strategy

Every implementation change follows red/green TDD:

1. Add or update a failing test that captures the behavior.
2. Implement the minimum code required to pass.
3. Refactor only while all tests remain green.

Test layers:

- Node built-in test runner for manifest schemas, marketplace consistency, release manifest completeness, documentation invariants, secret-pattern checks, and archive-policy fixtures.
- POSIX shell tests with mocked network, filesystem, archive, terminal-launch, time, and `tg` commands for macOS and Linux lifecycle behavior.
- PowerShell tests with built-in assertions and equivalent mocks for Windows lifecycle behavior.
- Static skill tests for trigger descriptions, command contracts, destructive confirmation rules, and secret-handling prohibitions.
- Integration smoke tests that download the pinned public assets in CI where architecture permits and verify the required command surface without logging into Telegram.

Required negative tests include checksum mismatch, GitHub host mismatch, unexpected release tag, missing digest, absolute archive path, parent traversal, symlink executable, multiple executable candidates, interrupted replacement, failed smoke test, stale update confirmation, ambiguous recipient, automatic `--yes`, secret-bearing login invocation, and overwrite without confirmation.

## Continuous integration

GitHub Actions runs on Ubuntu, macOS, and Windows and includes:

- Manifest and marketplace validation.
- Node tests.
- POSIX and PowerShell platform suites.
- ShellCheck and PSScriptAnalyzer.
- JSON, YAML, Markdown, and link validation.
- Secret scanning and forbidden-pattern tests.
- Pinned release asset verification.
- Packaging checks confirming that no `tg` binary or session-like file enters the plugin archive.

Hosted CI does not perform real Telegram authorization. Architecture combinations unavailable on hosted runners receive static asset validation plus a required manual release checklist.

## Release policy

- Plugin releases use semantic versioning and a Git tag matching the manifest version.
- GitHub releases contain source and plugin packaging only; they never attach a `tg` binary.
- Release notes state the tested `gotd/cli` version and supported platforms.
- A release requires green CI, validated Claude Code and Codex installations from the repository marketplaces, and manual smoke evidence for macOS, Linux, and Windows.
- A release that changes the pinned `tg` version must include compatibility test updates and a changelog entry.

## Acceptance criteria

The first public release is complete when:

1. The same nested payload installs from the repository in current Claude Code and Codex.
2. Both hosts discover the setup and ordinary Telegram skills with correct namespacing.
3. A clean macOS, Linux, or Windows user can install the pinned `tg` version without administrator privileges.
4. Local phone and QR login flows keep every secret outside agent-visible channels.
5. A previously authorized user can list chats, read history, search, send text, upload, download, and perform a bounded wait.
6. Ambiguous recipients and destructive operations stop at the required confirmation gates.
7. Archive attacks, checksum failures, and failed replacements are rejected without damaging an existing installation or Telegram session.
8. All automated checks pass, required manual platform smoke tests are recorded, and the package contains no binaries, credentials, session data, or secret-bearing fixtures.
9. README, security, contribution, third-party, changelog, and installation documentation are public, English, accurate, and link directly to upstream `gotd/cli`.

## Principal risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Upstream `tg` changes command behavior | Pin one tested version per plugin release and require compatibility tests before updates. |
| Compromised or malformed release asset | Verify committed SHA-256, constrain the host and release path, inspect archives safely, and retain rollback. |
| Login secrets leak through agent tooling | Use a separate interactive process, prohibit secret-bearing arguments/environment/logs, and test invocation construction. |
| Trademark or official-status confusion | Use `TG Agent`, state that the project is unofficial, avoid the official logo, and credit the independent upstream clearly. |
| Linux terminal fragmentation | Use a small documented launcher allowlist and provide a safe headless manual handoff. |
| Agent performs an unintended external action | Require explicit intent, recipient disambiguation, immediate destructive confirmation, and one-time verification instead of retries. |

## Design completion rule

Implementation may begin only after the user reviews this written specification and explicitly approves it. Any later change to scope, trust boundaries, supported hosts, supported account type, update policy, or confirmation policy requires a design revision before implementation.
