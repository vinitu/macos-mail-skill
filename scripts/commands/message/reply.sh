#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: $(basename "$0") [--cc <addrs>] [--bcc <addrs>] [--reply-all] <account-name> <mailbox-name> <message-id> <reply-body> [visible] [attachment...]" >&2
  echo "  --cc/--bcc take a comma-separated list. --reply-all copies every original recipient." >&2
}

cc_addresses=""
bcc_addresses=""
reply_all="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cc)  [[ $# -ge 2 ]] || { usage; fail "--cc needs a value"; };  cc_addresses="$2";  shift 2 ;;
    --bcc) [[ $# -ge 2 ]] || { usage; fail "--bcc needs a value"; }; bcc_addresses="$2"; shift 2 ;;
    --reply-all) reply_all="true"; shift ;;
    --) shift; break ;;
    -*) usage; fail "unknown option $1" ;;
    *) break ;;
  esac
done

[[ $# -ge 4 ]] || { usage; exit 1; }

account_name="$1"
mailbox_name="$2"
message_id="$3"
reply_body="$4"
visible="${5:-true}"
shift 4
if [[ $# -gt 0 ]]; then shift 1; fi
attachments=("$@")

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

resolve_attachments_or_error "${attachments[@]+"${attachments[@]}"}"

capture_osascript "$APPLETS_DIR/message/reply.applescript" \
  "$account_name" "$mailbox_name" "$index" "$reply_body" "$cc_addresses" "$bcc_addresses" "$reply_all" "$visible" \
  "${RESOLVED_ATTACHMENTS[@]+"${RESOLVED_ATTACHMENTS[@]}"}" >/dev/null
ensure_jq
"$JQ_BIN" -nc \
  --arg account "$account_name" \
  --arg mailbox "$mailbox_name" \
  --argjson index "$index" \
  --arg body "$reply_body" \
  --arg cc "$cc_addresses" \
  --arg bcc "$bcc_addresses" \
  --arg reply_all "$reply_all" \
  --arg visible "$visible" \
  --args \
  '{created: true, account: $account, mailbox: $mailbox, index: $index, body: $body, cc: $cc, bcc: $bcc, reply_all: ($reply_all == "true"), visible: ($visible == "true" or $visible == "1"), attachments: $ARGS.positional}' \
  "${RESOLVED_ATTACHMENTS[@]+"${RESOLVED_ATTACHMENTS[@]}"}"
