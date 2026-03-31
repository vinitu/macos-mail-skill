#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/import/mailbox.sh <path>" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local path_value="${1:-}"
  require_arg "$path_value" "path" || exit 1

  local script
  script=$(require_backend_script "import" "mailbox") || exit 1
  capture_osascript "$script" "$path_value" >/dev/null

  require_jq
  "$JQ_BIN" -nc --arg path "$path_value" '{imported: true, path: $path}'
}

main "$@"
