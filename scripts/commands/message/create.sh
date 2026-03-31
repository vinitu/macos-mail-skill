#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/message/create.sh <to> <subject> <body> [visible]" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local to_address="${1:-}"
  local subject="${2:-}"
  local body="${3:-}"
  local visible="${4:-true}"

  require_arg "$to_address" "to" || exit 1
  require_arg "$subject" "subject" || exit 1
  require_arg "$body" "body" || exit 1

  case "$visible" in
    true|false|1|0)
      ;;
    *)
      fail "Visible must be true, false, 1, or 0"
      ;;
  esac

  local create_script
  create_script=$(require_backend_script "message" "create") || exit 1

  capture_osascript "$create_script" "$to_address" "$subject" "$body" "$visible" >/dev/null

  require_jq
  "$JQ_BIN" -nc \
    --arg to "$to_address" \
    --arg subject "$subject" \
    --arg body "$body" \
    --arg visible "$visible" \
    '{created: true, to: $to, subject: $subject, body: $body, visible: ($visible == "true" or $visible == "1")}'
}

main "$@"
