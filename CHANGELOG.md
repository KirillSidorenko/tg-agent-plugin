# Changelog

All notable changes to TG Agent Plugin are documented here. The project follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Approved cross-host design for Claude Code and Codex.
- Local-only personal-account boundary and credential-handling policy.
- Pinned compatibility target for `gotd/cli v0.11.0` on macOS, Linux, and
  Windows for amd64 and arm64.
- Dependency-free repository contract tests.
- Matching Claude Code and Codex manifests and repository marketplaces for one
  shared nested plugin payload.
- An original non-Telegram brand mark for host presentation.
- A compatibility manifest pinning six official `gotd/cli v0.11.0` release
  archives with exact SHA-256 values and unauthenticated smoke commands.
- A POSIX lifecycle tool for macOS and Linux with pinned downloads, strict
  archive validation, atomic replacement, rollback, repair, status, and
  report-only upstream update checks.
- Secret-free local login launchers for macOS Terminal, Windows PowerShell,
  deterministic Linux terminal emulators, and a headless Linux handoff.
- Separate authorize and single-shot post-login verification actions.
- A PowerShell lifecycle implementation matching the pinned install, archive
  validation, atomic replacement, rollback, repair, update-reporting, and
  authorization contracts used on POSIX systems.
- Shared English `telegram` and `telegram-setup` skills with direct CLI use,
  progressive command references, explicit safety classes, secret-free setup,
  and bounded realtime rules.
- Public installation, update, uninstall, troubleshooting, manual platform,
  release, contribution, security, and issue-routing documentation for the
  GitHub repository.
- Deterministic source-only packaging with a strict allowlist and normalized
  archive metadata.
- Dependency-free plugin validation, repository credential/artifact scanning,
  and live verification of the pinned upstream checksum and GitHub digests.
- Commit-pinned GitHub Actions workflows for Node, POSIX, PowerShell,
  ShellCheck, PSScriptAnalyzer, packaging, and release gates.
- Local marketplace installation and skill discovery for both Claude Code and
  Codex, plus a macOS temporary-directory cleanup regression fix found during
  a real isolated pinned install.

## [0.2.0] - 2026-08-04

This version identifies the prior local prototype. It was not released from
this public repository.
