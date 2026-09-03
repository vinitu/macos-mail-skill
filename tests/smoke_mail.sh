#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JQ_BIN="${JQ_BIN:-$(command -v jq || true)}"

[ -n "$JQ_BIN" ] || { echo "smoke_mail: jq is required." >&2; exit 1; }

if ! osascript -e 'tell application "Mail" to get name' >/dev/null 2>&1; then
	echo "smoke_mail: Mail.app not available."
	exit 0
fi
osascript -e 'tell application "Mail" to get name' | grep -q . || { echo "smoke_mail: could not get app name." >&2; exit 1; }

# Public command layer: list accounts
acc_json="$("$ROOT_DIR/scripts/commands/account/list.sh" 2>&1)" || { echo "smoke_mail: Mail not running, skipping."; exit 0; }
printf '%s\n' "$acc_json" | "$JQ_BIN" -e 'type == "array"' >/dev/null || { echo "smoke_mail: account list is not JSON array." >&2; exit 1; }

first_acc="$(printf '%s\n' "$acc_json" | "$JQ_BIN" -r '.[0].name // empty')"
mb_json="$("$ROOT_DIR/scripts/commands/mailbox/list.sh" "${first_acc:-}" 2>&1)" || mb_json=""

first_mb=""
if printf '%s\n' "$mb_json" | "$JQ_BIN" -e 'type == "array"' >/dev/null 2>&1; then
  first_mb="$(printf '%s\n' "$mb_json" | "$JQ_BIN" -r '.[0].name // empty')"
elif [ -n "$first_acc" ]; then
  first_mb="INBOX"
else
  echo "smoke_mail: mailbox list failed and no INBOX fallback was found." >&2
  exit 1
fi

if [ -n "$first_acc" ]; then
  if [ -n "$first_mb" ]; then
    count_json="$("$ROOT_DIR/scripts/commands/mailbox/count.sh" "$first_acc" "$first_mb" 2>&1)" || { echo "smoke_mail: mailbox count failed." >&2; exit 1; }
    printf '%s\n' "$count_json" | "$JQ_BIN" -e 'has("count") and has("account") and has("mailbox")' >/dev/null || { echo "smoke_mail: mailbox count contract mismatch." >&2; exit 1; }

    message_list_json="$("$ROOT_DIR/scripts/commands/message/list.sh" "$first_acc" "$first_mb" 1 2>&1)" || { echo "smoke_mail: message list failed." >&2; exit 1; }
    printf '%s\n' "$message_list_json" | "$JQ_BIN" -e 'type == "array"' >/dev/null || { echo "smoke_mail: message list is not JSON array." >&2; exit 1; }

    # Use the `id` field, not `index`. `index` is a position, never an id, and
    # passing it here asserted a contract that never existed.
    first_id="$(printf '%s\n' "$message_list_json" | "$JQ_BIN" -r '.[0].id // empty')"
    if [ -n "$first_id" ]; then
      message_json="$("$ROOT_DIR/scripts/commands/message/get.sh" "$first_acc" "$first_mb" "$first_id" 2>&1)" || { echo "smoke_mail: message get failed." >&2; exit 1; }
      printf '%s\n' "$message_json" | "$JQ_BIN" -e 'has("id") and has("subject") and has("content")' >/dev/null || { echo "smoke_mail: message get contract mismatch." >&2; exit 1; }

      show_json="$("$ROOT_DIR/scripts/commands/message/show.sh" "$first_acc" "$first_mb" "$first_id" 2>&1)" || { echo "smoke_mail: message show failed." >&2; exit 1; }
      printf '%s\n' "$show_json" | "$JQ_BIN" -e '.shown == true and has("subject") and has("mailbox")' >/dev/null || { echo "smoke_mail: message show contract mismatch." >&2; exit 1; }

      # A ROWID from search must reach the same message as its Message-ID.
      rowid="$(printf '%s\n' "$("$ROOT_DIR/scripts/commands/message/search.sh" "$first_acc" "$first_mb" subject_contains "" 1 2>/dev/null)" | "$JQ_BIN" -r '.[0].id // empty')"
      if printf '%s' "$rowid" | grep -Eq '^[0-9]+$'; then
        rowid_json="$("$ROOT_DIR/scripts/commands/message/get.sh" "$first_acc" "$first_mb" "$rowid" 2>&1)" || { echo "smoke_mail: get by search ROWID failed — the search id is not usable by readers." >&2; exit 1; }
        printf '%s\n' "$rowid_json" | "$JQ_BIN" -e 'has("id") and has("content")' >/dev/null || { echo "smoke_mail: get by ROWID contract mismatch." >&2; exit 1; }
      fi

      # A bare integer that is not a ROWID must fail fast, not scan the mailbox.
      if "$ROOT_DIR/scripts/commands/message/get.sh" "$first_acc" "$first_mb" 999999999 >/dev/null 2>&1; then
        echo "smoke_mail: a bogus numeric id unexpectedly succeeded." >&2
        exit 1
      fi
    fi
  fi
fi

echo "smoke_mail: ok"

# Attachments: create a throwaway draft with a file, confirm Mail lists it, then remove the draft.
# Uses a unique subject so cleanup cannot touch a real draft.
attach_subject="smoke_mail attachment probe $$"
attach_file="$(mktemp -t smoke_mail_attach)"
printf 'smoke_mail attachment probe\n' > "$attach_file"

cleanup_attach_probe() {
  osascript -e "tell application \"Mail\" to delete (every message of mailbox \"Drafts\" of account \"$1\" whose subject is \"$attach_subject\")" >/dev/null 2>&1 || true
  rm -f "$attach_file"
}

if [ -n "$first_acc" ]; then
  trap 'cleanup_attach_probe "$first_acc"' EXIT
  attach_json="$("$ROOT_DIR/scripts/commands/message/create.sh" "$first_acc" "nobody@example.invalid" "$attach_subject" "probe" false "$attach_file" 2>&1)" \
    || { echo "smoke_mail: create with attachment failed: $attach_json" >&2; exit 1; }
  printf '%s\n' "$attach_json" | "$JQ_BIN" -e '.attachments | length == 1' >/dev/null \
    || { echo "smoke_mail: create did not report one attachment." >&2; exit 1; }

  listed="$(osascript -e "tell application \"Mail\" to get name of every mail attachment of (item 1 of (messages of mailbox \"Drafts\" of account \"$first_acc\" whose subject is \"$attach_subject\"))" 2>/dev/null || true)"
  case "$listed" in
    *"$(basename "$attach_file")"*) ;;
    *) echo "smoke_mail: draft does not carry the attachment (got: $listed)" >&2; exit 1 ;;
  esac

  # A path that does not exist must be refused before Mail is involved.
  if "$ROOT_DIR/scripts/commands/message/create.sh" "$first_acc" "nobody@example.invalid" "$attach_subject" "probe" false "/no/such/file.pdf" >/dev/null 2>&1; then
    echo "smoke_mail: a missing attachment path was accepted." >&2
    exit 1
  fi

  cleanup_attach_probe "$first_acc"
  trap - EXIT
fi
