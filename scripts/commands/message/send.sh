#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/message/send.sh <to> <subject> <body>" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local to_address="${1:-}"
  local subject="${2:-}"
  local body="${3:-}"

  require_arg "$to_address" "to" || exit 1
  require_arg "$subject" "subject" || exit 1
  require_arg "$body" "body" || exit 1

  local script
  script=$(require_backend_script "message" "send") || exit 1

  capture_osascript "$script" "$to_address" "$subject" "$body" >/dev/null

  require_jq
  "$JQ_BIN" -nc --arg to "$to_address" --arg subject "$subject" --arg body "$body" '
    {
      sent: true,
      to: $to,
      subject: $subject,
      body: $body
    }
  '
}

main "$@"
