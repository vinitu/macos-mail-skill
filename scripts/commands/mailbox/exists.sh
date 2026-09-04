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
  local mailboxes_raw
  mailboxes_raw="$(mailbox_names_raw "$account_name")"
  ensure_jq

  if printf '%s\n' "$mailboxes_raw" | grep -Fqx -- "$mailbox_name"; then
    "$JQ_BIN" -nc \
      --arg id "${account_name}/${mailbox_name}" \
      --arg account "$account_name" \
      --arg mailbox "$mailbox_name" \
      '{exists: true, id: $id, account: $account, mailbox: $mailbox}'
  else
    "$JQ_BIN" -nc \
      --arg account "$account_name" \
      --arg mailbox "$mailbox_name" \
      '{exists: false, id: null, account: $account, mailbox: $mailbox}'
  fi
}

main "$@"