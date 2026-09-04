#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  printf 'Usage: %s <account-name> [id|name]\n' "$(basename "$0")" >&2
}

main() {
  [[ $# -ge 1 && $# -le 2 ]] || { usage; fail "wrong number of arguments"; }

  local account_name="$1"
  local property="${2:-}"

  account_exists_or_error "$account_name"
  ensure_jq

  local account_json
  account_json="$("$JQ_BIN" -nc --arg id "$account_name" --arg name "$account_name" '{id: $id, name: $name}')"

  if [[ -z "$property" ]]; then
    printf '%s' "$account_json"
    exit 0
  fi

  case "$property" in
    id|name)
      ;;
    *)
      fail "Unsupported account property: $property"
      ;;
  esac

  printf '%s' "$account_json" | "$JQ_BIN" -c --arg property "$property" '
    {
      id: .id,
      name: .name,
      property: $property,
      value: .[$property]
    }
  '
}

main "$@"