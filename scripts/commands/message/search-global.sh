#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

[[ $# -ge 2 && $# -le 3 ]] || { echo "Usage: $(basename "$0") <subject_contains|sender_contains> <value> [limit]" >&2; exit 1; }

mode="$1"
value="$2"
limit="${3:-50}"

case "$mode" in
  subject_contains|sender_contains) ;;
  *) echo "Unsupported search mode: $mode (use subject_contains or sender_contains)" >&2; exit 1 ;;
esac

require_positive_int "limit" "$limit"

DB="$HOME/Library/Mail/V10/MailData/Envelope Index"
[[ -f "$DB" ]] || { echo "Mail database not found: $DB" >&2; exit 1; }

# Get account UUID→name mapping from Mail.app
account_map="$(/usr/bin/osascript -e '
tell application "Mail"
  set r to ""
  repeat with acc in accounts
    set r to r & id of acc & "|" & name of acc & linefeed
  end repeat
  r
end tell' 2>/dev/null)"

# Escape single quotes in value to prevent SQL injection
safe_value="${value//\'/\'\'}"

# Build WHERE clause
if [[ "$mode" == "sender_contains" ]]; then
  where_clause="(LOWER(addr.address) LIKE LOWER('%${safe_value}%')
              OR LOWER(addr.comment) LIKE LOWER('%${safe_value}%'))"
else
  where_clause="LOWER(sub.subject) LIKE LOWER('%${safe_value}%')"
fi

# Query SQLite — output raw rows using unit separator (0x1F) to avoid conflicts
# CTE ranks ALL messages per mailbox (DESC = newest first, matching Mail.app UI order),
# then filters to matching rows so the index reflects the true position in the mailbox.
rows="$(sqlite3 "$DB" \
  -separator $'\x1f' \
  "WITH ranked AS (
     SELECT
       ROWID,
       CAST(ROW_NUMBER() OVER (PARTITION BY mailbox ORDER BY date_received DESC) AS TEXT) AS idx
     FROM messages
     WHERE deleted = 0
   )
   SELECT
     COALESCE(mgd.message_id_header, CAST(m.ROWID AS TEXT)),
     sub.subject,
     addr.address,
     COALESCE(addr.comment, ''),
     mb.url,
     m.date_received,
     m.read,
     m.flagged,
     r.idx
   FROM messages m
   JOIN ranked r ON r.ROWID = m.ROWID
   JOIN subjects sub ON m.subject = sub.ROWID
   JOIN addresses addr ON m.sender = addr.ROWID
   JOIN mailboxes mb ON m.mailbox = mb.ROWID
   LEFT JOIN message_global_data mgd ON mgd.message_id = m.ROWID
   WHERE $where_clause
     AND m.deleted = 0
   ORDER BY m.date_received DESC
   LIMIT $limit;" 2>/dev/null)"

if [[ -z "$rows" ]]; then
  echo '[]'
  exit 0
fi

python3 - <<PYEOF
import sys, json, urllib.parse, datetime, os

account_map_raw = """$account_map"""
rows_raw = """$rows"""

# Parse UUID→account name (case-insensitive keys)
uuid_to_name = {}
for line in account_map_raw.strip().splitlines():
    if '|' in line:
        uuid, name = line.split('|', 1)
        uuid_to_name[uuid.strip().lower()] = name.strip()

SEP = '\x1f'
results = []
for line in rows_raw.strip().splitlines():
    parts = line.split(SEP)
    if len(parts) < 9:
        continue
    msg_id, subject, email, display_name, mb_url, date_ts, is_read, is_flagged, idx = parts[:9]

    # Resolve account name and mailbox from imap URL
    parsed = urllib.parse.urlparse(mb_url)
    uuid = parsed.hostname or ''
    mailbox_path = urllib.parse.unquote(parsed.path.lstrip('/'))

    account_name = uuid_to_name.get(uuid.lower(), uuid)

    # Format sender
    sender = f"{display_name} <{email}>" if display_name else email

    # Format date (Unix timestamp → human-readable)
    try:
        dt = datetime.datetime.fromtimestamp(int(date_ts))
        date_str = dt.strftime('%A, %d %B %Y at %I:%M:%S %p')
    except Exception:
        date_str = date_ts

    results.append({
        'id': msg_id,
        'account': account_name,
        'mailbox': mailbox_path,
        'index': int(idx),
        'subject': subject,
        'sender': sender,
        'date_received': date_str,
        'read': is_read == '1',
        'flagged': is_flagged == '1',
    })

print(json.dumps(results, ensure_ascii=False))
PYEOF
