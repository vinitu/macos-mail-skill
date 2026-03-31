#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/account/check-mail.sh [account-name]" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local account_name="${1:-}"

  local script
  script=$(require_backend_script "account" "check-mail") || exit 1

  if [[ -n "$account_name" ]]; then
    account_exists_or_error "$account_name"
    capture_osascript "$script" "$account_name" >/dev/null
  else
    capture_osascript "$script" >/dev/null
  fi

  require_jq
  "$JQ_BIN" -nc --arg account "$account_name" '
    {
      checking: true,
      account: (if $account == "" then null else $account end)
    }
  '
}

main "$@"
