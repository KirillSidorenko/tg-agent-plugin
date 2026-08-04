# Platform Lifecycle Reference

Read this reference when resolving scripts, managed paths, or platform-specific
launcher results.

## Support matrix

| Platform | Architectures | Managed executable | Plugin state |
| --- | --- | --- | --- |
| macOS | amd64, arm64 | `$HOME/.local/bin/tg` | `${XDG_STATE_HOME:-$HOME/.local/state}/tg-agent-plugin` |
| Linux | amd64, arm64 | `$HOME/.local/bin/tg` | `${XDG_STATE_HOME:-$HOME/.local/state}/tg-agent-plugin` |
| Windows | amd64, arm64 | `%LOCALAPPDATA%\Programs\tg\tg.exe` | `%LOCALAPPDATA%\TGAgentPlugin` |

The plugin never requires administrator privileges and never changes the
`gotd/cli` configuration or session path.

## Commands

POSIX:

```text
/bin/sh <plugin-root>/scripts/tg-tool.sh status --json
/bin/sh <plugin-root>/scripts/tg-tool.sh install --json
/bin/sh <plugin-root>/scripts/tg-tool.sh repair --json
/bin/sh <plugin-root>/scripts/tg-tool.sh check-update --json
/bin/sh <plugin-root>/scripts/tg-tool.sh authorize --mode phone --json
/bin/sh <plugin-root>/scripts/tg-tool.sh verify-authorization --json
```

Windows:

```text
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File <plugin-root>\scripts\tg-tool.ps1 -Action status -Json
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File <plugin-root>\scripts\tg-tool.ps1 -Action install -Json
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File <plugin-root>\scripts\tg-tool.ps1 -Action authorize -Mode phone -Json
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File <plugin-root>\scripts\tg-tool.ps1 -Action verify-authorization -Json
```

## Linux launcher order

Use the first available entry in this fixed order: `x-terminal-emulator`,
`gnome-terminal`, `konsole`, `kitty`, then `alacritty`. If none is available,
return `manual-required` with one secret-free worker command. Do not run that
interactive command through an agent transcript.

## Upstream boundary

Download only the version pinned in the bundled release manifest from
<https://github.com/gotd/cli/releases>. An explicit update check may report a
new release but cannot make it installable.
