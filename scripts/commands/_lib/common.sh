#!/usr/bin/env bash

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_DIR="$(cd "$COMMON_DIR/.." && pwd)"
REPO_ROOT="$(cd "$COMMANDS_DIR/../.." && pwd)"
APPLETS_DIR="$REPO_ROOT/scripts/applescripts"

# shellcheck source=scripts/commands/_lib/emlx.sh
source "$COMMON_DIR/emlx.sh"

if [[ -z "${JQ_BIN:-}" ]]; then
  if JQ_BIN="$(command -v jq 2>/dev/null)"; then
    :
  elif [[ -x "/opt/homebrew/bin/jq" ]]; then
    JQ_BIN="/opt/homebrew/bin/jq"
  else
    JQ_BIN=""
  fi
fi

# fail <message...>
# Emit the documented JSON error envelope {"success":false,"error":"..."} to
# stderr and exit non-zero. Every command error path uses this so actual
# output matches the SKILL.md error contract.
fail() {
  local msg="$*"
  if [[ -n "${JQ_BIN:-}" ]]; then
    "$JQ_BIN" -nc --arg error "$msg" '{success:false, error:$error}' >&2
  else
    # Minimal JSON string escaping when jq is unavailable.
    local escaped="${msg//\\/\\\\}"
    escaped="${escaped//\"/\\\"}"
    escaped="${escaped//$'\n'/\\n}"
    escaped="${escaped//$'\r'/\\r}"
    escaped="${escaped//$'\t'/\\t}"
    printf '{"success":false,"error":"%s"}\n' "$escaped" >&2
  fi
  exit 1
}

ensure_jq() {
  [[ -n "$JQ_BIN" ]] || fail "jq is required"
}

capture_osascript() {
  local script_path="$1"
  shift

  local output
  if ! output=$(/usr/bin/osascript "$script_path" "$@" 2>&1); then
    fail "$output"
  fi

  printf '%s' "$output"
}

try_capture_osascript() {
  local script_path="$1"
  shift

  /usr/bin/osascript "$script_path" "$@"
}

normalize_json_input() {
  ensure_jq
  "$JQ_BIN" -c '.'
}

json_lines_to_array() {
  ensure_jq
  "$JQ_BIN" -Rsc 'split("\n") | map(select(length > 0) | fromjson)'
}

require_positive_int() {
  local label="$1"
  local value="$2"

  [[ "$value" =~ ^[0-9]+$ ]] && [[ "$value" -ge 1 ]] || fail "Invalid ${label}: ${value}"
}

# resolve_index <account> <mailbox> <message-id>
# Resolves a message-id to the current numeric index in the mailbox via AppleScript.
# Exits with an error if the message is not found.
resolve_index() {
  local account_name="$1"
  local mailbox_name="$2"
  local message_id="$3"

  # `search.sh` and `search-global.sh` return `messages.ROWID` from the SQLite
  # Envelope Index, while find-index matches on the RFC Message-ID header. Bridge
  # the two through the on-disk message file, whose name is the ROWID — otherwise
  # no id from a search can be used with any command that takes one.
  local original_id="$message_id"
  local from_rowid=0
  if [[ "$message_id" =~ ^[0-9]+$ ]]; then
    local header_id
    if header_id="$(message_id_from_rowid "$message_id")" && [[ -n "$header_id" ]]; then
      message_id="$header_id"
      from_rowid=1
    else
      # Fail here rather than handing a bare integer to find-index. An RFC
      # Message-ID always contains an "@", so a plain number can never match —
      # and find-index would issue one Apple Event per message in the mailbox
      # before saying so, which on a large mailbox takes minutes.
      echo "Message not found: $original_id — a numeric id must be a ROWID from search.sh or search-global.sh, and no message file with that ROWID exists on disk. Note this is NOT the small 'index' field returned alongside it: pass the 'id' field." >&2
      exit 1
    fi
  fi

  local resolved
  resolved="$(capture_osascript "$APPLETS_DIR/message/find-index.applescript" \
    "$account_name" "$mailbox_name" "$message_id")"

  # Keep the diagnostic from #25 — a search-global id can legitimately name a message in
  # another mailbox, and the bare "not found" sent people hunting in the wrong place —
  # but raise it through this branch's `fail` helper.
  [[ "$resolved" =~ ^[0-9]+$ ]] || {
    if [[ "$from_rowid" -eq 1 ]]; then
      fail "Message not found: $original_id (ROWID resolved to Message-ID $message_id, which is not in $account_name/$mailbox_name — a search-global id can name a message in another mailbox)"
    else
      fail "Message not found: $original_id"
    fi
  }

  printf '%s' "$resolved"
}

# Same translation, but silent: prints the index or nothing, never exits.
# `exists.sh` needs a soft answer, so it must not go through resolve_index.
resolve_index_soft() {
  local account_name="$1"
  local mailbox_name="$2"
  local message_id="$3"

  if [[ "$message_id" =~ ^[0-9]+$ ]]; then
    local header_id
    header_id="$(message_id_from_rowid "$message_id" 2>/dev/null)" || return 0
    [[ -n "$header_id" ]] || return 0
    message_id="$header_id"
  fi

  local resolved
  resolved="$(/usr/bin/osascript "$APPLETS_DIR/message/find-index.applescript" \
    "$account_name" "$mailbox_name" "$message_id" 2>/dev/null)" || return 0

  [[ "$resolved" =~ ^[0-9]+$ ]] && printf '%s' "$resolved"
  return 0
}

account_names_raw() {
  capture_osascript "$APPLETS_DIR/account/list.applescript"
}

account_exists_or_error() {
  local account_name="$1"
  local accounts_raw

  accounts_raw="$(account_names_raw)"
  printf '%s\n' "$accounts_raw" | grep -Fqx -- "$account_name" || fail "Account not found: $account_name"
}

mailbox_names_raw() {
  local account_name="${1:-}"

  if [[ -n "$account_name" ]]; then
    capture_osascript "$APPLETS_DIR/mailbox/list.applescript" "$account_name"
  else
    capture_osascript "$APPLETS_DIR/mailbox/list.applescript"
  fi
}

mailbox_exists_or_error() {
  local account_name="$1"
  local mailbox_name="$2"
  local mailboxes_raw

  mailboxes_raw="$(mailbox_names_raw "$account_name")"
  printf '%s\n' "$mailboxes_raw" | grep -Fqx -- "$mailbox_name" || fail "Mailbox not found: $mailbox_name"
}

# Validate attachment paths and expose them as absolute POSIX paths in RESOLVED_ATTACHMENTS.
# Mail attaches by file path, so a relative path or a directory fails inside AppleScript with a
# generic error; catching it here gives the caller a usable message instead.
resolve_attachments_or_error() {
  RESOLVED_ATTACHMENTS=()
  local p abs
  for p in "$@"; do
    [ -n "$p" ] || fail "Attachment path is empty"
    [ -e "$p" ] || fail "Attachment not found: $p"
    [ ! -d "$p" ] || fail "Attachment is a directory, not a file: $p"
    [ -r "$p" ] || fail "Attachment is not readable: $p"
    abs="$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"
    RESOLVED_ATTACHMENTS+=("$abs")
  done
}
