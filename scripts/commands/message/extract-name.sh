#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/message/extract-name.sh <full-email-address>" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local full_address="${1:-}"

  require_arg "$full_address" "full-email-address" || exit 1

  local extract_script
  extract_script=$(require_backend_script "message" "extract-name") || exit 1

  local name_value
  name_value="$(capture_osascript "$extract_script" "$full_address")"

  require_jq
  "$JQ_BIN" -nc --arg input "$full_address" --arg name "$name_value" '{input: $input, name: $name}'
}

main "$@"
