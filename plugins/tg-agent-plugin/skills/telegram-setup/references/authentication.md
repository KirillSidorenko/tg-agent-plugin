# Local Authorization

Read this reference only for initialization, login, verification, or a login
failure.

## Flow

1. Resolve `tg`; obtain install consent first when it is missing.
2. Run lifecycle action `authorize` in phone mode unless the user asks for QR.
   The action performs one authorization check before launching anything.
3. Tell the user to enter every credential only in the separate local window.
4. Wait for the user to report completion. Do not poll or capture terminal
   input or output.
5. Run lifecycle action `verify-authorization` exactly once.

## Exact local login contract

Phone login is exactly `tg login --phone=`. The empty value tells `tg` to prompt
inside its interactive process. QR login is exactly `tg login`.

Do not use a phone-number argument, `--password`, `TG_PASSWORD`, credential
environment variables, stdin pipes, redirected input, terminal transcripts,
screenshots, or log capture. Never ask the user to paste a phone number, code,
password, or token into agent chat.

The launchers remove known credential environment variables before `tg init`,
login, or verification. They initialize the default local configuration only
when its file is absent. They never inspect, copy, export, or delete session
data.

## Result routing

- `missing`: return to installation and request explicit consent.
- `already-authorized`: report success without opening another window.
- `login-started`: wait for the user to report completion.
- `manual-required`: show the one returned secret-free Linux command.
- `authorized`: return to the sibling `telegram` skill.
- `not-authorized`: offer to open login again; never request a credential.
