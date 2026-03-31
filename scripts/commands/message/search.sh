#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/message/search.sh <account-name> <mailbox-name> <subject_contains|sender_contains> <value>" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  local account_name="${1:-}"
  local mailbox_name="${2:-}"
  local mode="${3:-}"
  local value="${4:-}"

  require_arg "$account_name" "account-name" || exit 1
  require_arg "$mailbox_name" "mailbox-name" || exit 1
  require_arg "$mode" "mode" || exit 1
  require_arg "$value" "value" || exit 1

  account_exists_or_error "$account_name"
  mailbox_exists_or_error "$account_name" "$mailbox_name"

  case "$mode" in
    subject_contains|sender_contains)
      ;;
    *)
      fail "Unsupported search mode: $mode"
      ;;
  esac

  local script
  script=$(require_backend_script "message" "search") || exit 1

  local messages_raw
  messages_raw="$(capture_osascript "$script" "$account_name" "$mailbox_name" "$mode" "$value")"

  if [[ -z "$messages_raw" ]]; then
    echo '[]'
    exit 0
  fi

  printf '%s\n' "$messages_raw" | json_lines_to_array
}

main "$@"
