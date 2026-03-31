#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/mailbox/exists.sh <account-name> <mailbox-name>" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local account_name="${1:-}"
  local mailbox_name="${2:-}"

  require_arg "$account_name" "account-name" || exit 1
  require_arg "$mailbox_name" "mailbox-name" || exit 1

  account_exists_or_error "$account_name"

  local mailboxes_raw
  mailboxes_raw="$(mailbox_names_raw "$account_name")"
  require_jq

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
