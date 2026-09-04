#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

usage() {
  printf 'Usage: %s\n' "$(basename "$0")" >&2
}

main() {
  [[ $# -eq 0 ]] || { usage; fail "unexpected arguments"; }

  local accounts_raw
  accounts_raw="$(account_names_raw)"
  ensure_jq

  printf '%s\n' "$accounts_raw" | "$JQ_BIN" -Rsc '
    split("\n")
    | map(select(length > 0))
    | map({id: ., name: .})
  '
}

main "$@"