#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/mailbox/count.sh <account-name> <mailbox-name>" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local account_name="${1:-}"
  local mailbox_name="${2:-}"

  require_arg "$account_name" "account-name" || exit 1
  require_arg "$mailbox_name" "mailbox-name" || exit 1

  account_exists_or_error "$account_name"
  mailbox_exists_or_error "$account_name" "$mailbox_name"
  require_jq

  local count_script
  count_script=$(require_backend_script "mailbox" "count") || exit 1

  local count_raw
  count_raw="$(capture_osascript "$count_script" "$account_name" "$mailbox_name")"

  "$JQ_BIN" -nc \
    --arg account "$account_name" \
    --arg mailbox "$mailbox_name" \
    --argjson count "$count_raw" \
    '{count: $count, account: $account, mailbox: $mailbox}'
}

main "$@"
