#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

[[ $# -ge 4 && $# -le 5 ]] || { echo "Usage: $(basename "$0") <account-name> <mailbox-name> <message-id> <reply-body> [visible]" >&2; exit 1; }

account_name="$1"
mailbox_name="$2"
message_id="$3"
reply_body="$4"
visible="${5:-true}"

account_exists_or_error "$account_name"
mailbox_exists_or_error "$account_name" "$mailbox_name"
index="$(resolve_index "$account_name" "$mailbox_name" "$message_id")"

case "$visible" in
  true|false|1|0)
    ;;
  *)
    echo "Visible must be true, false, 1, or 0" >&2
    exit 1
    ;;
esac

capture_osascript "$APPLETS_DIR/message/reply.applescript" "$account_name" "$mailbox_name" "$index" "$reply_body" "$visible" >/dev/null
ensure_jq
"$JQ_BIN" -nc \
  --arg account "$account_name" \
  --arg mailbox "$mailbox_name" \
  --argjson index "$index" \
  --arg body "$reply_body" \
  --arg visible "$visible" \
  '{created: true, account: $account, mailbox: $mailbox, index: $index, body: $body, visible: ($visible == "true" or $visible == "1")}'
