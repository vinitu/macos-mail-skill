#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/url/mailto.sh <mailto-url>" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local mailto_url="${1:-}"

  require_arg "$mailto_url" "mailto-url" || exit 1

  local mailto_script
  mailto_script=$(require_backend_script "url" "mailto") || exit 1

  capture_osascript "$mailto_script" "$mailto_url" >/dev/null

  require_jq
  "$JQ_BIN" -nc --arg url "$mailto_url" '{opened: true, url: $url}'
}

main "$@"
