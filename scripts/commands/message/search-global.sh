#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"
# shellcheck source=scripts/commands/_lib/sqlite-search.sh
source "$SCRIPT_DIR/../_lib/sqlite-search.sh"

[[ $# -ge 2 && $# -le 3 ]] || { echo "Usage: $(basename "$0") <subject_contains|sender_contains> <value> [limit]" >&2; exit 1; }

mode="$1"
value="$2"
limit="${3:-50}"

case "$mode" in
  subject_contains|sender_contains) ;;
  *) echo "Unsupported search mode: $mode (use subject_contains or sender_contains)" >&2; exit 1 ;;
esac

require_positive_int "limit" "$limit"

run_sqlite_search "$mode" "$value" "$limit"
