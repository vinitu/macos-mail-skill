#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/mailbox/get.sh <account-name> <mailbox-name> [id|name|account|message_count]" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local account_name="${1:-}"
  local mailbox_name="${2:-}"
  local property="${3:-}"

  require_arg "$account_name" "account-name" || exit 1
  require_arg "$mailbox_name" "mailbox-name" || exit 1

  account_exists_or_error "$account_name"
  mailbox_exists_or_error "$account_name" "$mailbox_name"
  require_jq

  local count_script
  count_script=$(require_backend_script "mailbox" "count") || exit 1
  local count_raw
  count_raw="$(capture_osascript "$count_script" "$account_name" "$mailbox_name")"

  local mailbox_json
  mailbox_json="$("$JQ_BIN" -nc \
    --arg id "${account_name}/${mailbox_name}" \
    --arg name "$mailbox_name" \
    --arg account "$account_name" \
    --argjson count "$count_raw" \
    '{id: $id, name: $name, account: $account, message_count: $count}')"

  if [[ -z "$property" ]]; then
    printf '%s' "$mailbox_json"
    return 0
  fi

  case "$property" in
    id|name|account|message_count)
      ;;
    *)
      fail "Unsupported mailbox property: $property"
      ;;
  esac

  printf '%s' "$mailbox_json" | "$JQ_BIN" -c --arg property "$property" '
    {
      id: .id,
      name: .name,
      account: .account,
      property: $property,
      value: .[$property]
    }
  '
}

main "$@"
