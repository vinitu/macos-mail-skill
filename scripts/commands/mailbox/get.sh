#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  printf 'Usage: %s <account-name> <mailbox-name> [id|name|account|message_count]\n' "$(basename "$0")" >&2
}

main() {
  [[ $# -ge 2 && $# -le 3 ]] || { usage; fail "wrong number of arguments"; }

  local account_name="$1"
  local mailbox_name="$2"
  local property="${3:-}"

  account_exists_or_error "$account_name"
  mailbox_exists_or_error "$account_name" "$mailbox_name"
  ensure_jq

  local count_raw mailbox_json
  count_raw="$(capture_osascript "$APPLETS_DIR/mailbox/count.applescript" "$account_name" "$mailbox_name")"
  mailbox_json="$("$JQ_BIN" -nc \
    --arg id "${account_name}/${mailbox_name}" \
    --arg name "$mailbox_name" \
    --arg account "$account_name" \
    --argjson count "$count_raw" \
    '{id: $id, name: $name, account: $account, message_count: $count}')"

  if [[ -z "$property" ]]; then
    printf '%s' "$mailbox_json"
    exit 0
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