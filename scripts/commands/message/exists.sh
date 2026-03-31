#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/message/exists.sh <account-name> <mailbox-name> <index>" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local account_name="${1:-}"
  local mailbox_name="${2:-}"
  local index="${3:-}"

  require_arg "$account_name" "account-name" || exit 1
  require_arg "$mailbox_name" "mailbox-name" || exit 1
  require_arg "$index" "index" || exit 1

  account_exists_or_error "$account_name"
  mailbox_exists_or_error "$account_name" "$mailbox_name"
  require_positive_int "index" "$index"
  require_jq

  local get_script
  get_script=$(require_backend_script "message" "get") || exit 1

  local message_json
  if message_json="$(try_capture_osascript "$get_script" "$account_name" "$mailbox_name" "$index" 2>/dev/null)"; then
    printf '%s' "$message_json" | "$JQ_BIN" -c '{exists: true, id: .id, account: .account, mailbox: .mailbox, index: .index}'
  else
    "$JQ_BIN" -nc \
      --arg account "$account_name" \
      --arg mailbox "$mailbox_name" \
      --argjson index "$index" \
      '{exists: false, id: null, account: $account, mailbox: $mailbox, index: $index}'
  fi
}

main "$@"
