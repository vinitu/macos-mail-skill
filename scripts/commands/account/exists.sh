#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/account/exists.sh <account-name>" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local account_name="${1:-}"
  require_arg "$account_name" "account-name" || exit 1

  local accounts_raw
  accounts_raw="$(account_names_raw)"
  require_jq

  if printf '%s\n' "$accounts_raw" | grep -Fqx -- "$account_name"; then
    "$JQ_BIN" -nc --arg id "$account_name" --arg name "$account_name" '{exists: true, id: $id, name: $name}'
  else
    "$JQ_BIN" -nc --arg name "$account_name" '{exists: false, id: null, name: $name}'
  fi
}

main "$@"
