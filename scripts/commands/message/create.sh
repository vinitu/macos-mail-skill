#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

[[ $# -ge 4 && $# -le 5 ]] || { echo "Usage: $(basename "$0") <account> <to> <subject> <body> [visible]" >&2; exit 1; }

account_name="$1"
to_address="$2"
subject="$3"
body="$4"
visible="${5:-true}"

account_exists_or_error "$account_name"

case "$visible" in
  true|false|1|0)
    ;;
  *)
    echo "Visible must be true, false, 1, or 0" >&2
    exit 1
    ;;
esac

capture_osascript "$APPLETS_DIR/message/create.applescript" "$account_name" "$to_address" "$subject" "$body" "$visible" >/dev/null
ensure_jq
"$JQ_BIN" -nc \
  --arg account "$account_name" \
  --arg to "$to_address" \
  --arg subject "$subject" \
  --arg body "$body" \
  --arg visible "$visible" '
  {
    created: true,
    account: $account,
    to: $to,
    subject: $subject,
    body: $body,
    visible: ($visible == "true" or $visible == "1")
  }
'
