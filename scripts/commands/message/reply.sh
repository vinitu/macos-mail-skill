#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/message/reply.sh <account-name> <mailbox-name> <index> <reply-body>" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local account_name="${1:-}"
  local mailbox_name="${2:-}"
  local index="${3:-}"
  local reply_body="${4:-}"

  require_arg "$account_name" "account-name" || exit 1
  require_arg "$mailbox_name" "mailbox-name" || exit 1
  require_arg "$index" "index" || exit 1
  require_arg "$reply_body" "reply-body" || exit 1

  account_exists_or_error "$account_name"
  mailbox_exists_or_error "$account_name" "$mailbox_name"
  require_positive_int "index" "$index" || exit 1

  local script
  script=$(require_backend_script "message" "reply") || exit 1

  capture_osascript "$script" "$account_name" "$mailbox_name" "$index" "$reply_body" >/dev/null

  require_jq
  "$JQ_BIN" -nc \
    --arg account "$account_name" \
    --arg mailbox "$mailbox_name" \
    --argjson index "$index" \
    --arg body "$reply_body" \
    '{sent: true, account: $account, mailbox: $mailbox, index: $index, body: $body}'
}

main "$@"
