# Install, Update, and Uninstall

**Read when:** installing, updating, removing, or locally testing the public
plugin and its optional managed executable.

**Do not read by default:** ordinary Telegram requests, code review, or upstream
checksum changes.

**Fact owner:** this runbook owns exact host lifecycle commands. The design owns
product behavior; the platform checklist owns release evidence.

## Agent-led installation

The [README](../../README.md) provides the user-facing installation prompt.
Complete the requested plugin and CLI setup in the same task when the host
allows it; do not stop after marketplace registration.

1. Identify the current local host and platform. Use its matching commands
   below; preserve unrelated plugins, marketplaces, settings, and user data.
2. Register and install the plugin. Resolve its actual installed root from the
   host's plugin inventory; do not assume a cache path.
3. Read `skills/telegram-setup/SKILL.md` from that root and run the platform
   lifecycle script directly, even if newly installed skills are not yet loaded.
4. Run `status`. If installation is needed, explain the pinned upstream release
   and destination. The README prompt explicitly authorizes installation in the
   user's account; honor that authorization without asking them to repeat it.
   Without existing installation authorization, obtain consent before installing.
5. Use the pinned `install` action when needed and verify the returned result.
   Preserve a working existing client; do not replace it merely to repeat setup.
6. When login was requested, use `authorize` to open the separate local window.
   After the user reports completion, use `verify-authorization` once. Never
   collect credentials or capture the login window.
7. Report what is installed and whether login is complete. If the host needs a
   fresh session to discover the plugin, give the continuation prompt from the
   README. Do not claim authorization succeeded before verification.

Keep installation commands and technical diagnosis in this runbook so users can
start with a short request instead of operating the terminal themselves.

## Install from GitHub

The repository is <https://github.com/KirillSidorenko/tg-agent-plugin>.
Version `0.3.0` uses marketplace name `tg-agent` and plugin name
`tg-agent-plugin`. Until the first release tag is published, public validation
uses the reviewed `main` branch.

### Codex

```sh
codex plugin marketplace add KirillSidorenko/tg-agent-plugin --ref main
codex plugin add tg-agent-plugin@tg-agent
```

Start a new task after installation.

After the release exists, replace `--ref main` with immutable
`--ref v0.3.0`.

### Claude Code

```sh
claude plugin marketplace add KirillSidorenko/tg-agent-plugin
claude plugin install tg-agent-plugin@tg-agent
```

Restart Claude Code after installation.

## First local setup

Use the installed setup skill for the local Telegram personal account. Report
the upstream URL, pinned `gotd/cli` version, selected asset, checksum, and per-user
destination. Apply the installation authorization rules above.

Enter the phone number, login code, QR token, and 2FA password only in the
separate local terminal window. Never include a credential in host chat or an
issue report.

## Update the plugin

Codex:

```sh
codex plugin marketplace upgrade tg-agent
codex plugin add tg-agent-plugin@tg-agent
```

Claude Code:

```sh
claude plugin marketplace update tg-agent
claude plugin update tg-agent-plugin@tg-agent
```

Start a new task or restart the host after updating. An upstream update reported
as `newer-unpinned` remains unavailable until a new tested plugin release pins
it.

## Remove the host plugin

Codex:

```sh
codex plugin remove tg-agent-plugin
codex plugin marketplace remove tg-agent
```

Claude Code:

```sh
claude plugin uninstall tg-agent-plugin@tg-agent
claude plugin marketplace remove tg-agent
```

These commands preserve Telegram configuration and sessions. Removing the
plugin does not log out the local personal account.

## Optional managed executable cleanup

Perform this only when the user explicitly wants to remove the plugin-managed
executable and non-secret install state. It is separate from host uninstall.

macOS or Linux:

```sh
rm -- "$HOME/.local/bin/tg"
rm -r -- "${XDG_STATE_HOME:-$HOME/.local/state}/tg-agent-plugin"
```

Windows PowerShell:

```powershell
Remove-Item -LiteralPath "$env:LOCALAPPDATA\Programs\tg\tg.exe"
Remove-Item -LiteralPath "$env:LOCALAPPDATA\TGAgentPlugin" -Recurse
```

Do not remove any `gotd` configuration, Keychain entry, or session path. Session
cleanup is outside plugin uninstall and requires a separate explicit
user-directed procedure through the upstream client.
