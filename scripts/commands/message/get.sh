#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/message/get.sh <account-name> <mailbox-name> <index> [property]" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local account_name="${1:-}"
  local mailbox_name="${2:-}"
  local index="${3:-}"
  local property="${4:-}"

  require_arg "$account_name" "account-name" || exit 1
  require_arg "$mailbox_name" "mailbox-name" || exit 1
  require_arg "$index" "index" || exit 1

  account_exists_or_error "$account_name"
  mailbox_exists_or_error "$account_name" "$mailbox_name"
  require_positive_int "index" "$index"

  local get_script
  get_script=$(require_backend_script "message" "get") || exit 1

  local message_json
  message_json=$(capture_osascript "$get_script" "$account_name" "$mailbox_name" "$index")

  require_jq

  if [[ -z "$property" ]]; then
    printf '%s' "$message_json" | normalize_json_input
    return 0
  fi

  case "$property" in
    id|account|mailbox|index|subject|sender|date_received|date_sent|message_id|reply_to|message_size|read|flagged|junk|flag_index|background_color|all_headers|content)
      ;;
    *)
      fail "Unsupported message property: $property"
      ;;
  esac

  printf '%s' "$message_json" | "$JQ_BIN" -c --arg property "$property" '
    {
      id: .id,
      account: .account,
      mailbox: .mailbox,
      index: .index,
      property: $property,
      value: .[$property]
    }
  '
}

main "$@"
