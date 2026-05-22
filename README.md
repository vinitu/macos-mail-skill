# macOS Mail Skill

This repo stores an AI agent skill for Apple Mail.app on macOS.

The public interface is `scripts/commands`.
`scripts/applescripts` stores internal AppleScript backends and dictionary-aligned coverage.

## Installation

```bash
npx skills add vinitu/macos-mail-skill
```

Or with [skills.sh](https://skills.sh):

```bash
skills.sh add vinitu/macos-mail-skill
```

## Prerequisites

- macOS 12+ with Mail.app configured and signed in
- Automation permission granted to your terminal app
- `jq`
- (Optional) Full Disk Access for SQLite-based search

## Public Interface

Run skill actions with:

```bash
scripts/commands/<entity>/<action>.sh [args...]
```

Output rules:

- Commands return JSON by default unless noted otherwise.
- `--json`, `--plain`, and `--format=plain|json` are not supported.

## Backend Map

- `scripts/commands/account/*` → AppleScript in `scripts/applescripts/account/*`
- `scripts/commands/mailbox/*` → AppleScript in `scripts/applescripts/mailbox/*`
- `scripts/commands/message/*` → AppleScript in `scripts/applescripts/message/*`
- `scripts/commands/signature/*` → AppleScript in `scripts/applescripts/signature/*`
- `scripts/commands/viewer/*` → AppleScript in `scripts/applescripts/viewer/*`
- `scripts/commands/import/*` → AppleScript in `scripts/applescripts/import/*`
- `scripts/commands/url/*` → AppleScript in `scripts/applescripts/url/*`

`scripts/applescripts` is internal. Do not call it directly from the skill instructions.

## Command Surface

Account:

- `scripts/commands/account/list.sh`
- `scripts/commands/account/get.sh`
- `scripts/commands/account/exists.sh`
- `scripts/commands/account/check-mail.sh`

Mailbox:

- `scripts/commands/mailbox/list.sh`
- `scripts/commands/mailbox/get.sh`
- `scripts/commands/mailbox/count.sh`
- `scripts/commands/mailbox/exists.sh`

Message:

- `scripts/commands/message/list.sh`
- `scripts/commands/message/get.sh`
- `scripts/commands/message/show.sh`
- `scripts/commands/message/search.sh`
- `scripts/commands/message/search-global.sh`
- `scripts/commands/message/exists.sh`
- `scripts/commands/message/create.sh`
- `scripts/commands/message/send.sh`
- `scripts/commands/message/reply.sh`
- `scripts/commands/message/forward.sh`
- `scripts/commands/message/move.sh`
- `scripts/commands/message/delete.sh`
- `scripts/commands/message/mark-read.sh`
- `scripts/commands/message/mark-unread.sh`
- `scripts/commands/message/flag.sh`
- `scripts/commands/message/unflag.sh`
- `scripts/commands/message/extract-name.sh`
- `scripts/commands/message/extract-address.sh`

Other:

- `scripts/commands/signature/list.sh`
- `scripts/commands/viewer/inbox.sh`
- `scripts/commands/import/mailbox.sh`
- `scripts/commands/url/mailto.sh`

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

## Validation

```bash
make compile
make test
```

`make test` runs live checks against Mail.app and expects Mail to be available.

## Known Limits

- Mail.app must be running and configured for most commands to work.
- TCC permissions (Automation) must be granted to the terminal or parent process.
- Account names and mailbox names are case-sensitive.
- Slow searches: use `message/search-global.sh` for fast cross-account search.
