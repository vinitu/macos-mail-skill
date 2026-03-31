#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/mailbox/list.sh [account-name]" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local account_name="${1:-}"

  if [[ -n "$account_name" ]]; then
    account_exists_or_error "$account_name"
  else
    account_name="$(account_names_raw | head -n 1)"
  fi

  if [[ -z "$account_name" ]]; then
    echo '[]'
    return 0
  fi

  local mailboxes_raw
  mailboxes_raw="$(mailbox_names_raw "$account_name")"
  require_jq

  local count_script
  count_script=$(require_backend_script "mailbox" "count") || exit 1

  local out='[]'
  while IFS= read -r mailbox_name; do
    [[ -n "$mailbox_name" ]] || continue
    local count_raw
    count_raw="$(capture_osascript "$count_script" "$account_name" "$mailbox_name")"
    local mailbox_json
    mailbox_json="$("$JQ_BIN" -nc \
      --arg id "${account_name}/${mailbox_name}" \
      --arg name "$mailbox_name" \
      --arg account "$account_name" \
      --argjson count "$count_raw" \
      '{id: $id, name: $name, account: $account, message_count: $count}')"
    out="$(printf '%s' "$out" | "$JQ_BIN" -c --argjson item "$mailbox_json" '. + [$item]')"
  done <<< "$mailboxes_raw"

  printf '%s\n' "$out"
}

main "$@"
