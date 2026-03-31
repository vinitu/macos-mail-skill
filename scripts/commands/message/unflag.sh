#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/message/unflag.sh <account-name> <mailbox-name> <index>" >&2
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

  local unflag_script
  unflag_script=$(require_backend_script "message" "unflag") || exit 1

  capture_osascript "$unflag_script" "$account_name" "$mailbox_name" "$index" >/dev/null

  require_jq
  "$JQ_BIN" -nc \
    --arg account "$account_name" \
    --arg mailbox "$mailbox_name" \
    --argjson index "$index" \
    '{updated: true, flagged: false, account: $account, mailbox: $mailbox, index: $index}'
}

main "$@"
