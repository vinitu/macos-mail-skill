#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

[[ $# -eq 3 ]] || { echo "Usage: $(basename "$0") <account-name> <mailbox-name> <message-id>" >&2; exit 1; }

account_name="$1"
mailbox_name="$2"
message_id="$3"

account_exists_or_error "$account_name"
mailbox_exists_or_error "$account_name" "$mailbox_name"
ensure_jq

index="$(/usr/bin/osascript "$APPLETS_DIR/message/find-index.applescript" \
  "$account_name" "$mailbox_name" "$message_id" 2>/dev/null)" || index=""

if [[ "$index" =~ ^[0-9]+$ ]]; then
  message_json="$(try_capture_osascript "$APPLETS_DIR/message/get.applescript" "$account_name" "$mailbox_name" "$index" 2>/dev/null)" || message_json=""
  if [[ -n "$message_json" ]]; then
    printf '%s' "$message_json" | "$JQ_BIN" -c '{exists: true, id: .id, account: .account, mailbox: .mailbox, index: .index}'
    exit 0
  fi
fi

"$JQ_BIN" -nc \
  --arg id "$message_id" \
  --arg account "$account_name" \
  --arg mailbox "$mailbox_name" \
  '{exists: false, id: null, account: $account, mailbox: $mailbox}'
