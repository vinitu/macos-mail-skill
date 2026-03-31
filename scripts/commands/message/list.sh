#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/message/list.sh <account-name> <mailbox-name> [limit]" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local account_name="${1:-}"
  local mailbox_name="${2:-}"
  local limit="${3:-10}"

  require_arg "$account_name" "account-name" || exit 1
  require_arg "$mailbox_name" "mailbox-name" || exit 1

  account_exists_or_error "$account_name"
  mailbox_exists_or_error "$account_name" "$mailbox_name"
  require_positive_int "limit" "$limit"

  local list_script
  list_script=$(require_backend_script "message" "list") || exit 1

  local messages_raw
  messages_raw=$(capture_osascript "$list_script" "$account_name" "$mailbox_name" "$limit")

  if [[ -z "$messages_raw" ]]; then
    echo '[]'
    return 0
  fi

  printf '%s\n' "$messages_raw" | json_lines_to_array
}

main "$@"
