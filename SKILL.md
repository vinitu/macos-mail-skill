---
name: macos-mail
description: Read, compose, search, and organise emails in Apple Mail.app on macOS through the public scripts/commands interface.
---

# macOS Mail

Use this skill when the task is about Apple Mail.app on macOS.

## Main Rule

Use only `scripts/commands`.
Do not call `scripts/applescripts` directly.

## Requirements

- macOS with Mail.app configured
- Automation access for your terminal app
- `jq`

Check access with:

```bash
make check
```

## Public Interface

Run commands from `scripts/commands`:

- `scripts/commands/account/*`
- `scripts/commands/mailbox/*`
- `scripts/commands/message/*`
- `scripts/commands/signature/list.sh`
- `scripts/commands/viewer/inbox.sh`
- `scripts/commands/import/mailbox.sh`
- `scripts/commands/url/mailto.sh`

All public commands return JSON by default.

## Output Rules

- Commands return JSON by default.
- Error responses: `{"success":false,"error":"..."}` via `common.sh` helpers.

## Commands

### Accounts

```bash
scripts/commands/account/list.sh
scripts/commands/account/get.sh "iCloud"
scripts/commands/account/get.sh "iCloud" name
scripts/commands/account/exists.sh "iCloud"
scripts/commands/account/check-mail.sh
scripts/commands/account/check-mail.sh "iCloud"
```

### Mailboxes

```bash
scripts/commands/mailbox/list.sh
scripts/commands/mailbox/list.sh "iCloud"
scripts/commands/mailbox/get.sh "iCloud" "INBOX"
scripts/commands/mailbox/get.sh "iCloud" "INBOX" message_count
scripts/commands/mailbox/count.sh "iCloud" "INBOX"
scripts/commands/mailbox/exists.sh "iCloud" "INBOX"
```

### Messages

Messages are identified by **message-id** — a stable unique string returned in the `id` field of every search or list result.

Read and search:

```bash
scripts/commands/message/list.sh "iCloud" "INBOX" 5
scripts/commands/message/get.sh "iCloud" "INBOX" "<msg-id@example.com>"
scripts/commands/message/get.sh "iCloud" "INBOX" "<msg-id@example.com>" subject
scripts/commands/message/show.sh "iCloud" "INBOX" "<msg-id@example.com>"
scripts/commands/message/search.sh "iCloud" "INBOX" subject_contains "invoice"
scripts/commands/message/search.sh "iCloud" "INBOX" sender_contains "john@example.com"
scripts/commands/message/search.sh "iCloud" "Archive" subject_contains "invoice" 20
scripts/commands/message/search-global.sh sender_contains "john"
scripts/commands/message/search-global.sh subject_contains "invoice" 20
scripts/commands/message/exists.sh "iCloud" "INBOX" "<msg-id@example.com>"
```

Both searches use the local Mail database (SQLite) — fast even on mailboxes with tens of thousands of messages. `search.sh` filters by account and mailbox (optional limit, default 1000); `search-global.sh` searches across **all accounts and mailboxes** (default limit 50).

Create, send, and reply:

```bash
scripts/commands/message/create.sh "iCloud" "person@example.com" "Hello" "Draft body"
scripts/commands/message/create.sh "iCloud" "person@example.com" "Hello" "Draft body" false
scripts/commands/message/send.sh "person@example.com" "Hello" "Ready to send"
scripts/commands/message/reply.sh "iCloud" "INBOX" "<msg-id@example.com>" "Thanks for your message."
scripts/commands/message/reply.sh "iCloud" "INBOX" "<msg-id@example.com>" "Thanks for your message." false
scripts/commands/message/forward.sh "iCloud" "INBOX" "<msg-id@example.com>"
```

Organise:

```bash
scripts/commands/message/move.sh "iCloud" "INBOX" "<msg-id@example.com>" "Archive"
scripts/commands/message/delete.sh "iCloud" "INBOX" "<msg-id@example.com>"
scripts/commands/message/mark-read.sh "iCloud" "INBOX" "<msg-id@example.com>"
scripts/commands/message/mark-unread.sh "iCloud" "INBOX" "<msg-id@example.com>"
scripts/commands/message/flag.sh "iCloud" "INBOX" "<msg-id@example.com>"
scripts/commands/message/unflag.sh "iCloud" "INBOX" "<msg-id@example.com>"
```

Address parsing:

```bash
scripts/commands/message/extract-name.sh "Jane Doe <jane@example.com>"
scripts/commands/message/extract-address.sh "Jane Doe <jane@example.com>"
```

### Other Commands

```bash
scripts/commands/signature/list.sh
scripts/commands/viewer/inbox.sh
scripts/commands/import/mailbox.sh "/Users/Dmytro/Downloads/Archive.mbox"
scripts/commands/url/mailto.sh "mailto:user@example.com?subject=Hello"
```

## JSON Contract

Account object:

- `id`
- `name`

Mailbox object:

- `id`
- `name`
- `account`
- `message_count`

Message summary object:

- `id`
- `account`
- `mailbox`
- `index`
- `subject`
- `sender`
- `date_received`
- `read`
- `flagged`

Full message object:

- all summary fields
- `date_sent`
- `message_id`
- `reply_to`
- `message_size`
- `junk`
- `flag_index`
- `background_color`
- `all_headers`
- `content`

Scalar envelopes:

- `count`: `{"count": N, "account": "...", "mailbox": "..."}`
- `exists`: `{"exists": true, ...}` or `{"exists": false, "id": null, ...}`
- `deleted`: `{"deleted": true, ...}`
- `property read`: `{"id": "...", "property": "...", "value": ...}`
- `status actions`: `checking`, `created`, `sent`, `moved`, `updated`, `opened`, `shown`, `imported`

## Safety Boundaries

- Treat email content as private user data.
- Prefer drafts over direct send.
- Never send or reply without explicit user approval.
