#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  printf 'Usage: %s <account-name>\n' "$(basename "$0")" >&2
}

main() {
  [[ $# -eq 1 ]] || { usage; fail "wrong number of arguments"; }

  local account_name="$1"
  local accounts_raw
  accounts_raw="$(account_names_raw)"
  ensure_jq

  if printf '%s\n' "$accounts_raw" | grep -Fqx -- "$account_name"; then
    "$JQ_BIN" -nc --arg id "$account_name" --arg name "$account_name" '{exists: true, id: $id, name: $name}'
  else
    "$JQ_BIN" -nc --arg name "$account_name" '{exists: false, id: null, name: $name}'
  fi
}

main "$@"