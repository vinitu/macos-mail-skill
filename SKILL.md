---
name: macos-mail
description: Read, compose, search, and organise emails in Apple Mail.app on macOS through the public scripts/commands interface.
---

# macOS Mail

Use this skill when the task is about Apple Mail.app on macOS.

## Overview
- Public interface: `scripts/commands`
- Internal backend: `scripts/applescripts`
- Output: JSON by default

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
- `scripts/commands/account/*`
- `scripts/commands/mailbox/*`
- `scripts/commands/message/*`
- `scripts/commands/signature/list.sh`
- `scripts/commands/viewer/inbox.sh`
- `scripts/commands/import/mailbox.sh`
- `scripts/commands/url/mailto.sh`

## Output Rules
- Commands return JSON by default.
- Write operations (move, delete, flag, etc.) return a JSON confirmation.
- Property reads return a JSON object with the requested value.

## Commands

### Accounts
List accounts and check mail:
```bash
scripts/commands/account/list.sh
scripts/commands/account/default.sh
scripts/commands/account/get.sh "iCloud" name
scripts/commands/account/exists.sh "iCloud"
scripts/commands/account/check-mail.sh
```

### Mailboxes
List and count messages:
```bash
scripts/commands/mailbox/list.sh "iCloud"
scripts/commands/mailbox/get.sh "iCloud" "INBOX" message_count
scripts/commands/mailbox/count.sh "iCloud" "INBOX"
scripts/commands/mailbox/exists.sh "iCloud" "INBOX"
```

### Messages
Read and search:
```bash
scripts/commands/message/list.sh "iCloud" "INBOX" 5
scripts/commands/message/get.sh "iCloud" "INBOX" 1
scripts/commands/message/search.sh "iCloud" "INBOX" subject_contains "invoice"
```

Compose and organize:
```bash
scripts/commands/message/create.sh "person@example.com" "Hello" "Draft body" false
scripts/commands/message/reply.sh "iCloud" "INBOX" 1 "Thanks for your message."
scripts/commands/message/move.sh "iCloud" "INBOX" 1 "Archive"
scripts/commands/message/delete.sh "iCloud" "INBOX" 1
scripts/commands/message/mark-read.sh "iCloud" "INBOX" 1
```

## JSON Contract

Account object:
- `id`: account name
- `name`: account name

Mailbox object:
- `id`: mailbox name
- `name`: mailbox name
- `account`: parent account name
- `message_count`: total messages

Message object:
- `id`: unique identifier
- `subject`: message subject
- `sender`: sender address
- `date_received`: date string
- `content`: message body (full object only)
- `read`: boolean status
- `flagged`: boolean status

Scalar envelopes:
- `count`: `{"count": N, "account": "...", "mailbox": "..."}`
- `exists`: `{"exists": true, ...}`
- `deleted`: `{"deleted": true, ...}`
- property read: `{"id": "...", "property": "...", "value": ...}`

## Safety Boundaries
- Treat email content as private user data.
- Never send or reply without explicit user approval.
- Use `create.sh` to prepare drafts for manual review.
- Internal AppleScript files are not public API.
