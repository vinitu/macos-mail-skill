#!/usr/bin/env bash

# Use absolute path to the repo root
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
APPLETS_DIR="$ROOT_DIR/scripts/applescripts"

# JQ resolution
if [[ -z "${JQ_BIN:-}" ]]; then
  if JQ_BIN="$(command -v jq 2>/dev/null)"; then
    :
  elif [[ -x "/opt/homebrew/bin/jq" ]]; then
    JQ_BIN="/opt/homebrew/bin/jq"
  else
    JQ_BIN=""
  fi
fi

# Standard helpers
json_fail() {
  local message="$1"
  printf '{"success":false,"error":"%s"}\n' "$message"
  return 1
}

json_ok() {
  local payload="$1"
  printf '{"success":true,"data":%s}\n' "$payload"
}

require_arg() {
  local value="${1:-}"
  local label="$2"

  if [[ -z "$value" ]]; then
    json_fail "missing ${label}"
    return 1
  fi
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || { json_fail "required file not found: $path"; return 1; }
}

require_jq() {
  [[ -n "$JQ_BIN" ]] || { echo "jq is required" >&2; exit 1; }
}

# Backend helpers
backend_script() {
  local entity="$1"
  local action="$2"
  printf '%s/%s/%s.applescript' "$APPLETS_DIR" "$entity" "$action"
}

require_backend_script() {
  local entity="$1"
  local action="$2"
  local path
  path="$(backend_script "$entity" "$action")"

  if [[ ! -f "$path" ]]; then
    json_fail "backend script not found: $path"
    return 1
  fi

  printf '%s\n' "$path"
}

# Mail.app specific helpers
capture_osascript() {
  local script_path="$1"
  shift

  local output
  if ! output=$(/usr/bin/osascript "$script_path" "$@" 2>&1); then
    printf '%s\n' "$output" >&2
    exit 1
  fi

  printf '%s' "$output"
}

try_capture_osascript() {
  local script_path="$1"
  shift

  /usr/bin/osascript "$script_path" "$@"
}

normalize_json_input() {
  require_jq
  "$JQ_BIN" -c '.'
}

json_lines_to_array() {
  require_jq
  "$JQ_BIN" -Rsc 'split("\n") | map(select(length > 0) | fromjson)'
}

require_positive_int() {
  local label="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[0-9]+$ ]] || [[ "$value" -lt 1 ]]; then
    json_fail "Invalid ${label}: ${value}"
    return 1
  fi
}

account_names_raw() {
  local script
  script=$(require_backend_script "account" "list") || exit 1
  capture_osascript "$script"
}

account_exists_or_error() {
  local account_name="$1"
  local accounts_raw

  accounts_raw="$(account_names_raw)"
  printf '%s\n' "$accounts_raw" | grep -Fqx -- "$account_name" || {
    json_fail "Account not found: $account_name"
    exit 1
  }
}

mailbox_names_raw() {
  local account_name="${1:-}"
  local script
  script=$(require_backend_script "mailbox" "list") || exit 1

  if [[ -n "$account_name" ]]; then
    capture_osascript "$script" "$account_name"
  else
    capture_osascript "$script"
  fi
}

mailbox_exists_or_error() {
  local account_name="$1"
  local mailbox_name="$2"
  local mailboxes_raw

  mailboxes_raw="$(mailbox_names_raw "$account_name")"
  printf '%s\n' "$mailboxes_raw" | grep -Fqx -- "$mailbox_name" || {
    json_fail "Mailbox not found: $mailbox_name"
    exit 1
  }
}
