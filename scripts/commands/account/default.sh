#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../../commands/_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/account/default.sh" >&2
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

  local script
  script=$(require_backend_script "account" "default") || exit 1

  local name
  name="$(capture_osascript "$script")"

  require_jq
  "$JQ_BIN" -nc --arg name "$name" '{id: $name, name: $name}'
}

main "$@"
