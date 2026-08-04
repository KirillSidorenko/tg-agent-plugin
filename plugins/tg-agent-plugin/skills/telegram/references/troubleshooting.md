# Telegram Troubleshooting

Read this reference only after setup is complete and an ordinary command fails
or has an uncertain result.

## Authorization and availability

- `not authorized`: invoke the sibling `telegram-setup` skill. Let it open the
  local login process, wait for the user, then verify once.
- Missing executable: route to setup and ask for installation consent.
- Network failure: preserve the current installation and report the operation
  that could not complete.

## Known `v0.11.0` outcomes

- `USERNAME_INVALID` from `wait me`: use `tg wait` without a peer and filter the
  response for Saved Messages.
- `bad updates result` from `edit`: the edit may have succeeded. Verify once
  with `context` or `history`; never repeat the edit blindly.
- `PREMIUM_ACCOUNT_REQUIRED`: report the Telegram account restriction and do
  not retry.
- Numeric peer cannot resolve: call `chats list -o json` once to populate the
  local peer cache, then retry the selected `id:<number>` once.
- Rejected syntax: call one targeted `tg <command> --help`, correct the command,
  and do not install an untested upstream version.

Never resolve an error by requesting credentials or session files in chat.
