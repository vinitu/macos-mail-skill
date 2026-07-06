#!/usr/bin/env bash
# Shared SQLite-backed message search over Mail.app's Envelope Index.
# Used by message/search-global.sh (all accounts) and message/search.sh
# (single account+mailbox). Fast on large mailboxes: no per-message
# Apple Events, one SQL query.
#
# Message data is passed to Python via temp files, never interpolated
# into the Python source — subjects with backslashes (e.g. PHP
# namespaces like "AirSlate\UrlShortener\...") must not reach the
# Python parser as string-literal escapes.

MAIL_DB="$HOME/Library/Mail/V10/MailData/Envelope Index"

# run_sqlite_search <subject_contains|sender_contains> <value> <limit> [account] [mailbox]
# Prints a JSON array of message summary objects (same shape as the
# AppleScript summary: id, account, mailbox, index, subject, sender,
# date_received, read, flagged).
run_sqlite_search() {
  local mode="$1" value="$2" limit="$3" account_filter="${4:-}" mailbox_filter="${5:-}"

  [[ -f "$MAIL_DB" ]] || { echo "Mail database not found: $MAIL_DB" >&2; return 1; }

  # Account UUID→name mapping from Mail.app (one fast Apple Event)
  local account_map
  account_map="$(/usr/bin/osascript -e '
tell application "Mail"
  set r to ""
  repeat with acc in accounts
    set r to r & id of acc & "|" & name of acc & linefeed
  end repeat
  r
end tell' 2>/dev/null)"

  # Escape single quotes to keep the LIKE value inert in SQL
  local safe_value="${value//\'/\'\'}"

  local where_clause
  if [[ "$mode" == "sender_contains" ]]; then
    where_clause="(LOWER(addr.address) LIKE LOWER('%${safe_value}%')
                OR LOWER(addr.comment) LIKE LOWER('%${safe_value}%'))"
  else
    where_clause="LOWER(sub.subject) LIKE LOWER('%${safe_value}%')"
  fi

  # SQL-level cap: exact when no post-SQL filters; otherwise a generous
  # bound since account/mailbox filtering happens in Python after ranking.
  local sql_limit="$limit"
  if [[ -n "$account_filter" || -n "$mailbox_filter" ]]; then
    sql_limit=10000
  fi

  local sqlite3_query="WITH ranked AS (
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
     LIMIT $sql_limit;"

  local sqlite3_rc=0 sqlite3_err="" rows
  local sqlite3_err_file
  sqlite3_err_file="$(mktemp)"
  if ! rows="$(sqlite3 "$MAIL_DB" -separator $'\x1f' "$sqlite3_query" 2>"$sqlite3_err_file")"; then
    sqlite3_rc=$?
  fi
  [[ -s "$sqlite3_err_file" ]] && sqlite3_err="$(cat "$sqlite3_err_file")"
  rm -f "$sqlite3_err_file"

  if [[ $sqlite3_rc -ne 0 ]]; then
    local err_msg="SQLite query failed (exit $sqlite3_rc)"
    [[ -n "$sqlite3_err" ]] && err_msg="$err_msg: $sqlite3_err"
    printf '%s\n' "{\"success\":false,\"error\":\"${err_msg//\"/\\\"}\"}" >&2
    return 1
  fi

  if [[ -z "$rows" ]]; then
    echo '[]'
    return 0
  fi

  # Hand data to Python via files; heredoc is quoted so nothing from the
  # mail content can be parsed as Python source.
  local rows_file map_file
  rows_file="$(mktemp)"
  map_file="$(mktemp)"
  printf '%s' "$rows" > "$rows_file"
  printf '%s' "$account_map" > "$map_file"

  SQLITE_SEARCH_ROWS_FILE="$rows_file" \
  SQLITE_SEARCH_MAP_FILE="$map_file" \
  SQLITE_SEARCH_LIMIT="$limit" \
  SQLITE_SEARCH_ACCOUNT="$account_filter" \
  SQLITE_SEARCH_MAILBOX="$mailbox_filter" \
  python3 - <<'PYEOF'
import json, os, urllib.parse, datetime

with open(os.environ['SQLITE_SEARCH_ROWS_FILE'], encoding='utf-8') as f:
    rows_raw = f.read()
with open(os.environ['SQLITE_SEARCH_MAP_FILE'], encoding='utf-8') as f:
    account_map_raw = f.read()
limit = int(os.environ['SQLITE_SEARCH_LIMIT'])
account_filter = os.environ.get('SQLITE_SEARCH_ACCOUNT', '')
mailbox_filter = os.environ.get('SQLITE_SEARCH_MAILBOX', '')

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

    parsed = urllib.parse.urlparse(mb_url)
    uuid = parsed.hostname or ''
    mailbox_path = urllib.parse.unquote(parsed.path.lstrip('/'))
    account_name = uuid_to_name.get(uuid.lower(), uuid)

    if account_filter and account_name != account_filter:
        continue
    if mailbox_filter and mailbox_path != mailbox_filter:
        continue

    sender = f"{display_name} <{email}>" if display_name else email

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
    if len(results) >= limit:
        break

print(json.dumps(results, ensure_ascii=False))
PYEOF
  local py_rc=$?
  rm -f "$rows_file" "$map_file"
  return $py_rc
}
