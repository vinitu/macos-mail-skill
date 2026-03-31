#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/account/get.sh <account-name> [id|name]" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local account_name="${1:-}"
  local property="${2:-}"

  require_arg "$account_name" "account-name" || exit 1

  account_exists_or_error "$account_name"
  require_jq

  local account_json
  account_json="$("$JQ_BIN" -nc --arg id "$account_name" --arg name "$account_name" '{id: $id, name: $name}')"

  if [[ -z "$property" ]]; then
    printf '%s' "$account_json"
    return 0
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
