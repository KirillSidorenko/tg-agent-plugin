# Tested `tg v0.11.0` Recipes

Read this reference for ordinary Telegram commands after `tg` is installed and
authorized. Use `-o json` for parsed output.

## Discover chats and people

```sh
tg chats list --limit 100 -o json
tg resolve @username -o json
tg contacts search "Name" -o json
```

Filter one broad chat result locally by name, username, unread state, or recent
date. Prefer `@username`; otherwise use a cached `id:<number>` after `chats
list` has populated the peer cache. Clarify duplicate or ambiguous matches
before a write.

## Read and search

```sh
tg history me --limit 30 -o json
tg history @username --limit 30 -o json
tg search @username "invoice" --limit 50 -o json
tg search --global "invoice" --limit 50 -o json
tg context @username 12345 --radius 5 -o json
```

History exposes message IDs, dates, direction, sender, text, media, and reply
metadata. Keep the limit proportional to the task.

## Send and modify

```sh
tg send "note to self" -o json
tg send --peer @username "hello" -o json
tg reply me 12345 "reply" -o json
tg edit me 12346 "corrected" -o json
tg forward me @username 12345 -o json
tg read @username -o json
```

An explicit request authorizes these commands only for an unambiguous target.
Use the returned message ID for follow-up work. If a write result is uncertain,
verify once with `context` or `history`; never repeat it blindly.

## Transfer media

```sh
tg upload ./photo.png --message "caption" -o json
tg upload --peer @username ./report.pdf -o json
tg album --peer me ./one.jpg ./two.jpg -o json
tg download me 12345 --out ./downloads/ -o json
```

Confirm before replacing any existing download target. Use the media message ID
for one-file downloads rather than exporting a chat.

## Wait within a boundary

```sh
tg wait --timeout 30s -o json
tg wait @username --timeout 5m -o json
```

On `v0.11.0`, omit `me` for Saved Messages and filter the returned JSON. Use
`tg watch` only behind a host-enforced duration or event boundary, and terminate
`tg watch` when the boundary is reached. Do not show or run a standalone
unbounded watch command.

For an uncommon operation, request one command-specific help page. Destructive,
administrative, profile, and session operations require immediate confirmation
of the exact target and effect.
