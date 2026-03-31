#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/viewer/inbox.sh" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  if [[ $# -gt 0 ]]; then
    usage
    exit 1
  fi

  local inbox_script
  inbox_script=$(require_backend_script "viewer" "inbox") || exit 1

  local mailbox_name
  mailbox_name="$(capture_osascript "$inbox_script")"

  require_jq
  "$JQ_BIN" -nc --arg mailbox "$mailbox_name" '{mailbox: $mailbox}'
}

main "$@"
