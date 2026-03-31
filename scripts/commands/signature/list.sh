#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/signature/list.sh" >&2
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

  local list_script
  list_script=$(require_backend_script "signature" "list") || exit 1

  local signatures_raw
  signatures_raw="$(capture_osascript "$list_script")"

  require_jq
  printf '%s\n' "$signatures_raw" | "$JQ_BIN" -Rsc '
    split("\n")
    | map(select(length > 0))
    | map({id: ., name: .})
  '
}

main "$@"
