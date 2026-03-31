#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/message/move.sh <account-name> <source-mailbox> <index> <target-mailbox>" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local account_name="${1:-}"
  local source_mailbox="${2:-}"
  local index="${3:-}"
  local target_mailbox="${4:-}"

  require_arg "$account_name" "account-name" || exit 1
  require_arg "$source_mailbox" "source-mailbox" || exit 1
  require_arg "$index" "index" || exit 1
  require_arg "$target_mailbox" "target-mailbox" || exit 1

  account_exists_or_error "$account_name"
  mailbox_exists_or_error "$account_name" "$source_mailbox"
  mailbox_exists_or_error "$account_name" "$target_mailbox"
  require_positive_int "index" "$index"

  local move_script
  move_script=$(require_backend_script "message" "move") || exit 1

  capture_osascript "$move_script" "$account_name" "$source_mailbox" "$index" "$target_mailbox" >/dev/null

  require_jq
  "$JQ_BIN" -nc \
    --arg account "$account_name" \
    --arg source_mailbox "$source_mailbox" \
    --arg target_mailbox "$target_mailbox" \
    --argjson index "$index" \
    '{moved: true, account: $account, source_mailbox: $source_mailbox, target_mailbox: $target_mailbox, index: $index}'
}

main "$@"
