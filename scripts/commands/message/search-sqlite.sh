#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../../commands/_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/message/search-sqlite.sh <query> [limit]" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

find_envelope_index() {
  local base_dir="$HOME/Library/Mail"
  local index_path
  index_path=$(find "$base_dir" -maxdepth 3 -name "Envelope Index" | head -n 1)
  echo "$index_path"
}

main() {
  local query="${1:-}"
  local limit="${2:-20}"

  require_arg "$query" "query" || exit 1
  require_jq

  local db_path
  db_path=$(find_envelope_index)

  if [[ -z "$db_path" ]]; then
    fail "Envelope Index database not found in $HOME/Library/Mail"
  fi

  if [[ ! -r "$db_path" ]]; then
    fail "No read permission for $db_path. Please grant Full Disk Access to your terminal."
  fi

  # Optimized READ-ONLY query to fetch message summaries with correct joins
  local sql="
SELECT 
    m.ROWID as id,
    s.subject as subject,
    a.address as sender,
    datetime(m.date_received + 978307200, 'unixepoch') as date_received,
    m.read as read,
    m.flagged as flagged,
    mb.url as mailbox_url
FROM messages m
JOIN addresses a ON m.sender = a.ROWID
JOIN subjects s ON m.subject = s.ROWID
JOIN mailboxes mb ON m.mailbox = mb.ROWID
WHERE s.subject LIKE '%${query}%' OR a.address LIKE '%${query}%'
ORDER BY m.date_received DESC
LIMIT ${limit};
"

  local raw_output
  raw_output=$(sqlite3 -json "$db_path" "$sql" 2>/dev/null) || {
    # Fallback for older sqlite3
    raw_output=$(sqlite3 -header -csv "$db_path" "$sql" | "$JQ_BIN" -R '
      split("\n") | .[0] as $header | .[1:] | map(select(length > 0) | split(",") | . as $row | 
      $header | split(",") | reduce range(0; length) as $i ({}; . + {($header | split(",") | .[$i]): $row[$i]}))')
  }

  if [[ -z "$raw_output" || "$raw_output" == "[]" ]]; then
    echo "[]"
  else
    echo "$raw_output" | "$JQ_BIN" -c '.'
  fi
}

main "$@"
