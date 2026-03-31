#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../../commands/_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/message/get-by-id.sh <message-id>" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local message_id="${1:-}"

  require_arg "$message_id" "message-id" || exit 1
  require_jq

  local script
  script=$(require_backend_script "message" "get-by-id") || exit 1

  capture_osascript "$script" "$message_id"
}

main "$@"
