#!/usr/bin/env bash
set -euo pipefail

# Use absolute path to common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  echo "Usage: scripts/commands/account/list.sh" >&2
}

fail() {
  json_fail "$1"
  exit 1
}

main() {
  [[ $# -eq 0 ]] || { usage; exit 1; }

  local accounts_raw
  accounts_raw="$(account_names_raw)"
  require_jq

  printf '%s\n' "$accounts_raw" | "$JQ_BIN" -Rsc '
    split("\n")
    | map(select(length > 0))
    | map({id: ., name: .})
  '
}

main "$@"
