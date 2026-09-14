#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: $(basename "$0") [--cc <addrs>] [--bcc <addrs>] [--from <addr>] <account> <to> <subject> <body> [visible] [attachment...]" >&2
  echo "  --cc/--bcc/<to> take a comma-separated list. --from must be an address of the account." >&2
}

cc_addresses=""
bcc_addresses=""
sender_address=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cc)   [[ $# -ge 2 ]] || { usage; fail "--cc needs a value"; };  cc_addresses="$2";  shift 2 ;;
    --bcc)  [[ $# -ge 2 ]] || { usage; fail "--bcc needs a value"; }; bcc_addresses="$2"; shift 2 ;;
    --from) [[ $# -ge 2 ]] || { usage; fail "--from needs a value"; }; sender_address="$2"; shift 2 ;;
    --) shift; break ;;
    -*) usage; fail "unknown option $1" ;;
    *) break ;;
  esac
done

[[ $# -ge 4 ]] || { usage; exit 1; }

account_name="$1"
to_address="$2"
subject="$3"
body="$4"
visible="${5:-true}"
shift 4
if [[ $# -gt 0 ]]; then shift 1; fi
attachments=("$@")

account_exists_or_error "$account_name"
sender_allowed_or_error "$account_name" "$sender_address"

case "$visible" in
  true|false|1|0)
    ;;
  *)
    echo "Visible must be true, false, 1, or 0" >&2
    exit 1
    ;;
esac

resolve_attachments_or_error "${attachments[@]+"${attachments[@]}"}"

capture_osascript "$APPLETS_DIR/message/create.applescript" \
  "$account_name" "$to_address" "$cc_addresses" "$bcc_addresses" "$sender_address" "$subject" "$body" "$visible" \
  "${RESOLVED_ATTACHMENTS[@]+"${RESOLVED_ATTACHMENTS[@]}"}" >/dev/null
ensure_jq
"$JQ_BIN" -nc \
  --arg account "$account_name" \
  --arg to "$to_address" \
  --arg cc "$cc_addresses" \
  --arg bcc "$bcc_addresses" \
  --arg from "$sender_address" \
  --arg subject "$subject" \
  --arg body "$body" \
  --arg visible "$visible" \
  --args '
  {
    created: true,
    account: $account,
    to: $to,
    cc: $cc,
    bcc: $bcc,
    from: $from,
    subject: $subject,
    body: $body,
    visible: ($visible == "true" or $visible == "1"),
    attachments: $ARGS.positional
  }
' "${RESOLVED_ATTACHMENTS[@]+"${RESOLVED_ATTACHMENTS[@]}"}"
