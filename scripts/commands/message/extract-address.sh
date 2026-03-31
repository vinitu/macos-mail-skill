#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/message/extract-address.sh <full-email-address>" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local full_address="${1:-}"

  require_arg "$full_address" "full-email-address" || exit 1

  local extract_script
  extract_script=$(require_backend_script "message" "extract-address") || exit 1

  local address_value
  address_value="$(capture_osascript "$extract_script" "$full_address")"

  require_jq
  "$JQ_BIN" -nc --arg input "$full_address" --arg address "$address_value" '{input: $input, address: $address}'
}

main "$@"
