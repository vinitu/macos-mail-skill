#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/commands/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

[[ $# -eq 3 ]] || { echo "Usage: $(basename "$0") <account-name> <mailbox-name> <message-id>" >&2; exit 1; }

account_name="$1"
mailbox_name="$2"
message_id="$3"

account_exists_or_error "$account_name"
mailbox_exists_or_error "$account_name" "$mailbox_name"
index="$(resolve_index "$account_name" "$mailbox_name" "$message_id")"

show_json="$(capture_osascript "$APPLETS_DIR/message/show.applescript" "$account_name" "$mailbox_name" "$index")"
printf '%s' "$show_json" | normalize_json_input
