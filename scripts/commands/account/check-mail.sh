#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  printf 'Usage: %s [account-name]\n' "$(basename "$0")" >&2
}

main() {
  [[ $# -le 1 ]] || { usage; fail "wrong number of arguments"; }

  local account_name="${1:-}"
  if [[ -n "$account_name" ]]; then
    account_exists_or_error "$account_name"
    capture_osascript "$APPLETS_DIR/account/check-mail.applescript" "$account_name" >/dev/null
  else
    capture_osascript "$APPLETS_DIR/account/check-mail.applescript" >/dev/null
  fi

  ensure_jq
  "$JQ_BIN" -nc --arg account "$account_name" '
    {
      checking: true,
      account: (if $account == "" then null else $account end)
    }
  '
}

main "$@"