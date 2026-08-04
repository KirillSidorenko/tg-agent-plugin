# TG Agent Plugin Project Instructions

## Project Scope

- The repository and all public-facing project documentation are written in English.
- The product is a local-only integration for a Telegram personal account.
- Bot API support, remote Telegram sessions, hosted MCP servers, and ChatGPT Web connectivity are out of scope.
- The plugin is a thin agent integration and safety layer around the independent open-source [`gotd/cli`](https://github.com/gotd/cli) client. Do not fork, vendor, or redistribute the `tg` binary.
- Never use the official Telegram logo or imply that this project is an official Telegram client.

## Development Process

- Use red/green TDD for every behavior change.
- Add or update a failing test first, implement the minimum change that makes it pass, and refactor only while the suite stays green.
- Preserve the local-only credential boundary. Phone numbers used for login, login codes, QR tokens, 2FA passwords, API credentials, and Telegram session data must never appear in chat, command arguments, environment variables, logs, fixtures, documentation, or committed files.
- Keep destructive Telegram operations behind an immediate confirmation gate. Never add `--yes` unless the user has explicitly confirmed the exact destructive action.
- Do not make a newer upstream `tg` release installable until its assets and command contract have been tested and the pinned release manifest has been updated in a plugin release.

## Architecture Map

- Read [`docs/architecture/project-map.md`](docs/architecture/project-map.md) in full before planning, implementation, review, deployment, or delegation.
- Follow the task router in the overview and load only the detail documents routed for the task; do not read every architecture document by default.
- The written design at [`docs/specs/2026-08-04-tg-agent-plugin-design.md`](docs/specs/2026-08-04-tg-agent-plugin-design.md) and the implementation plan at [`docs/plans/2026-08-04-tg-agent-plugin-implementation.md`](docs/plans/2026-08-04-tg-agent-plugin-implementation.md) are approved. Implement the plan in order and preserve its release gates.
- After every project change, check the overview and the affected routed documents for accuracy. Update them in the same change when components, boundaries, dependencies, interfaces, data flows, storage, infrastructure, deployment topology, or security/trust boundaries change.
- Give every detailed fact one canonical owner. Keep system topology in the overview, approved behavior in the design, exact operational commands in runbooks, and task/test evidence in project plans or reports.
- Keep the overview compact. If it approaches roughly 2,500 words, move task-specific detail into physically separate maps and link them from the task router.
- Never place secrets, credentials, tokens, private keys, session contents, or credential-bearing URLs in architecture documentation.
