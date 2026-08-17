#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  printf 'Usage: %s <account-name> <mailbox-name>\n' "$(basename "$0")" >&2
}

main() {
  [[ $# -eq 2 ]] || { usage; fail "wrong number of arguments"; }

  local account_name="$1"
  local mailbox_name="$2"

  account_exists_or_error "$account_name"
  mailbox_exists_or_error "$account_name" "$mailbox_name"
  ensure_jq

  local count_raw
  count_raw="$(capture_osascript "$APPLETS_DIR/mailbox/count.applescript" "$account_name" "$mailbox_name")"
  "$JQ_BIN" -nc \
    --arg account "$account_name" \
    --arg mailbox "$mailbox_name" \
    --argjson count "$count_raw" \
    '{count: $count, account: $account, mailbox: $mailbox}'
}

main "$@"