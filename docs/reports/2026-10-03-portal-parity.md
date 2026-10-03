# Portal Distribution Comparison — 2026-10-03

## Sources

The public GitHub baseline was `8988dfc` on `main`. A fresh fetch confirmed the
local checkout and remote branch matched before changes.

The portal exposes two distributions; checking only the standalone download
misses the newer managed package:

| Distribution | Version | Source |
| --- | --- | --- |
| Standalone Codex prototype | `0.2.0+codex.20260724130422` | [Standalone ZIP](https://go.dvs.group/downloads/telegram-agent-plugin.zip) |
| Managed Codex package | `0.3.1+diversity.1` | [Managed ZIP](https://go.dvs.group/downloads/plugins/telegram-agent/0.3.1+diversity.1/plugin.zip) |
| Managed Claude Code package | `0.3.1+diversity.1` | [Claude ZIP](https://go.dvs.group/downloads/plugins/telegram-agent/0.3.1+diversity.1/claude-plugin.zip) |

Discovery sources were the [Telegram instruction](https://go.dvs.group/instructions/telegram-agent-setup),
the [onboarding instruction](https://go.dvs.group/instructions/diversity-onboarding),
and the [Claude marketplace](https://go.dvs.group/downloads/plugins/claude/marketplace.json).

Observed archive SHA-256 values:

```text
standalone: 92bceab3495eb5d31e22a3f0734b728884fc420b1f95f9cef7779d3fa0e13787
managed:    d484723fdffbad9611e25f4cfd33b0d546779e3e944cd7f66169aecf0ce6b708
claude:     5c6ab78c842ddc0924fb6cd84a9bc1dc6b994ac02351118acd338ebe11e4fb6f
```

The Claude archive digest also matched its marketplace entry. These hashes
identify the inspected snapshots; they are not a new installation trust policy.
Archives were inspected as data, without running their scripts or hooks.

## Comparison and disposition

All 14 standalone files were compared with the 18-file managed Codex package.
After normalizing line endings, files shared by the managed Codex and Claude
archives were identical. Claude uses its own host manifest.

| Portal material | Public-source disposition |
| --- | --- |
| Quoted lifecycle paths in `skills/telegram-setup/SKILL.md` | Ported to the public setup skill and platform command reference. An executable regression test checks paths containing spaces on the runner's native platform. |
| Host-neutral sibling setup routing in `skills/telegram/SKILL.md` | Already present in the public skills; no namespace rewrite needed. |
| Persistent-data guidance added to both skills | Ported: credentials, sessions, mutable state, and downloads stay outside the replaceable plugin package. Public state locations remain those documented in the platform reference. |
| Separate package and CLI lifecycles | Made explicit in both skills; the public pinned CLI policy remains authoritative. |
| Installation and login handoff | Clarified `ready`, separately requested authorization, and a fresh host session when newly registered skills are not loaded. |
| Four `scripts/telegram-*.sh` / `.ps1` files | Byte-identical between standalone and managed portal ZIPs. No new managed script fixes to import. Public `tg-*` implementations retain pinned assets, stronger archive checks, rollback, credential-environment cleanup, Linux support, and the native macOS configuration path. |
| Two command/error references and the authentication reference | Byte-identical between standalone and managed portal ZIPs. Public references already cover the shared core workflows and known `v0.11.0` outcomes, with bounded realtime work and stricter write confirmation. |
| Two `agents/openai.yaml` files | Byte-identical between standalone and managed portal ZIPs. Public UI metadata retains the English TG Agent identity. |
| `README.md` and `LICENSE` | Byte-identical between standalone and managed portal ZIPs. Public English documentation and MIT attribution are retained. |
| Host manifests | Corporate identity/version and translated UI metadata are distribution-specific. Public Claude/Codex manifests continue to share the existing `tg-agent-plugin` identity. |
| `DIVERSITY-RELEASE.md` | Corporate release metadata declares a dependency on `diversity-onboarding`; recorded here rather than added as a public runtime dependency. |
| `hooks/hooks.json` and `hooks/check.py` | Corporate-only prompt hook invokes the separate Diversity manager under the user's home directory. Not imported into the standalone public plugin. |

The portal's automatic daily update checks and install-from-latest policy belong
to the earlier prototype. They are not new managed changes and are intentionally
superseded by the public design's explicit update checks and tested, pinned CLI
releases. Copying them would violate the approved compatibility policy.

This is a portable-change reconciliation, not byte-for-byte mirroring of the
corporate distribution. Corporate onboarding, update notifications, localized
branding, and distribution versioning remain outside the public plugin.

## Validation and architecture

- Red: the command-example regression failed because the unquoted POSIX path
  was split at its first space.
- Green: the corrected setup skill and reference commands passed the same
  regression, together with existing skill contracts.
- Local validation passed all 33 Node tests, ten POSIX lifecycle scenarios,
  four authorization scenarios, plugin validation, source scanning, and
  source-only packaging. Native Windows execution is delegated to the existing
  GitHub CI matrix; no local Windows runtime was used.
- The architecture overview and routed design/install documentation were
  checked. No component, dependency, interface, storage path, or trust boundary
  changed; the additions clarify the existing data boundary.
- This reconciliation does not change the pinned `gotd/cli v0.11.0`, publish a
  release, or replace the outstanding manual platform release gates.
