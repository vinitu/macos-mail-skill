# macOS Mail Skill

This repository provides a skill for Apple Mail.app integration on macOS via AppleScript.

## Overview
- Public interface: `scripts/commands`
- Internal backend: `scripts/applescripts`
- Output: JSON by default

## Goal
- Provide an accurate and stable public command layer for Mail.app.
- Return structured JSON for all read and write operations.
- Treat email data as private user data and ensure safety boundaries.

## Installation

```bash
npx skills add vinitu/macos-mail-skill
```

## Scope
- List accounts and mailboxes configured in Mail.app.
- Read messages with structured JSON output.
- Show a message in the Mail.app window.
- Create drafts, send messages, and reply to messages.
- Search messages by subject or sender.
- Move, delete, flag, and mark messages.

## Prerequisites
- macOS 12+ with Mail.app configured and signed in
- Automation permission granted to your terminal app
- `jq`

## How To Use
Run the public command wrappers from the repo root or from the installed skill path.
Do not call `scripts/applescripts` directly.

```bash
# List all Mail accounts
scripts/commands/account/list.sh
# Get default account
scripts/commands/account/default.sh
# List mailboxes in account "iCloud"
scripts/commands/mailbox/list.sh "iCloud"
# List recent messages
scripts/commands/message/list.sh "iCloud" "INBOX" 5
```

## Public Interface
- `scripts/commands/account/*`
- `scripts/commands/mailbox/*`
- `scripts/commands/message/*`
- `scripts/commands/signature/list.sh`
- `scripts/commands/viewer/inbox.sh`
- `scripts/commands/import/mailbox.sh`
- `scripts/commands/url/mailto.sh`

## Validation
After making changes, run these commands to ensure everything is correct:
- `make check`: Verify dependencies (Mail.app, `jq`).
- `make compile`: Syntax check for all AppleScript files.
- `make lint`: Run shellcheck on all shell scripts.
- `make test`: Run all contract and smoke tests.

## Troubleshooting
| Issue | Solution |
|-------|----------|
| "not authorized" error | Grant Automation permission to terminal in System Settings |
| Mail.app not responding | Ensure Mail.app is running; launch with `open -a Mail |
| Account not found | Check account name with `scripts/commands/account/list.sh` |
| `jq is required` | Install `jq` and ensure it is in `PATH` |
