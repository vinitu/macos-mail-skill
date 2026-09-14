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
# A fixed subject, deliberately not per-PID: deleting from Drafts is unreliable on some machines,
# and a unique subject per run would accumulate one orphan draft per run. With a constant subject
# the sweep below also collects whatever a previous run failed to remove, so the litter is bounded
# at one draft rather than growing.
# Removing a draft is unreliable in Mail's AppleScript: `delete` can throw while still having
# removed one message, and deleting from a `whose` collection invalidates the rest of it. What
# works is one removal per call, re-querying each time, with `move` to the trash as the fallback.
remove_drafts_matching() {
  local acc="$1" subj="$2"
  osascript <<APPLESCRIPT >/dev/null 2>&1 || true
tell application "Mail"
  set acct to account "$acc"
  repeat 8 times
    set hits to (every message of mailbox "Drafts" of acct whose subject contains "$subj")
    if (count of hits) is 0 then exit repeat
    try
      delete (last item of hits)
    on error
      try
        move (last item of hits) to mailbox "Deleted Messages" of acct
      end try
    end try
    delay 0.3
  end repeat
end tell
APPLESCRIPT
}

attach_subject="smoke_mail attachment probe"
attach_file="$(mktemp -t smoke_mail_attach)"
printf 'smoke_mail attachment probe\n' > "$attach_file"

# `whose subject is "..."` silently deletes nothing in Mail's AppleScript, while
# `whose subject contains "..."` works — the first version of this test used `is`, swallowed the
# failure with `|| true`, and left a probe draft in the user's Drafts on every run.
cleanup_attach_probe() {
  remove_drafts_matching "$1" "$attach_subject"
  rm -f "$attach_file"
}

# Deleting from Drafts is unreliable enough that the test has to police itself: report a leftover
# rather than hide it, or the next run adds another one.
warn_if_probe_left() {
  local left
  left="$(osascript -e "tell application \"Mail\" to get count of (every message of mailbox \"Drafts\" of account \"$1\" whose subject contains \"$attach_subject\")" 2>/dev/null || echo 0)"
  if [ "${left:-0}" != "0" ]; then
    echo "smoke_mail: WARNING - could not remove the probe draft \"$attach_subject\" from $1/Drafts; delete it by hand." >&2
  fi
}

if [ -n "$first_acc" ]; then
  # Sweep first, in case an earlier run could not clean up after itself.
  cleanup_attach_probe "$first_acc"
  printf 'smoke_mail attachment probe\n' > "$attach_file"
  trap 'cleanup_attach_probe "$first_acc"; warn_if_probe_left "$first_acc"' EXIT
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
  warn_if_probe_left "$first_acc"
  trap - EXIT
fi

# Cc, Bcc, sender, and the save that used to be skipped.
# Before v0.4.0 `save` sat inside the attachment branch, so a draft with no attachment was
# never written to Drafts — it lived only as an unsaved window, and with visible=false there
# was no window to save it from. This probe carries no attachment on purpose.
hdr_subject="smoke_mail header probe"

cleanup_hdr_probe() {
  remove_drafts_matching "$1" "$hdr_subject"
}

warn_if_hdr_probe_left() {
  local left
  left="$(osascript -e "tell application \"Mail\" to get count of (every message of mailbox \"Drafts\" of account \"$1\" whose subject contains \"$hdr_subject\")" 2>/dev/null || echo 0)"
  if [ "${left:-0}" != "0" ]; then
    echo "smoke_mail: WARNING - could not remove the probe draft \"$hdr_subject\" from $1/Drafts; delete it by hand." >&2
  fi
}

if [ -n "$first_acc" ]; then
  cleanup_hdr_probe "$first_acc"
  trap 'cleanup_hdr_probe "$first_acc"; warn_if_hdr_probe_left "$first_acc"' EXIT

  own_addr="$(osascript "$ROOT_DIR/scripts/applescripts/account/addresses.applescript" "$first_acc" 2>/dev/null | head -1)"
  [ -n "$own_addr" ] || { echo "smoke_mail: account $first_acc reports no send addresses." >&2; exit 1; }

  hdr_json="$("$ROOT_DIR/scripts/commands/message/create.sh" \
    --cc "cc-one@example.invalid, cc-two@example.invalid" \
    --bcc "bcc@example.invalid" \
    --from "$own_addr" \
    "$first_acc" "nobody@example.invalid" "$hdr_subject" "probe" false 2>&1)" \
    || { echo "smoke_mail: create with headers failed: $hdr_json" >&2; exit 1; }
  printf '%s\n' "$hdr_json" | "$JQ_BIN" -e '.cc != "" and .bcc != "" and .from != ""' >/dev/null \
    || { echo "smoke_mail: create did not echo cc/bcc/from." >&2; exit 1; }

  # The regression that matters: it must exist in Drafts at all.
  saved="$(osascript -e "tell application \"Mail\" to get count of (every message of mailbox \"Drafts\" of account \"$first_acc\" whose subject contains \"$hdr_subject\")" 2>/dev/null || echo 0)"
  [ "${saved:-0}" != "0" ] \
    || { echo "smoke_mail: an attachment-less draft was not saved to Drafts." >&2; exit 1; }

  hdr_actual="$(osascript -e "tell application \"Mail\"
    set m to item 1 of (messages of mailbox \"Drafts\" of account \"$first_acc\" whose subject contains \"$hdr_subject\")
    set o to (sender of m) & \"|\"
    repeat with r in (cc recipients of m)
      set o to o & (address of r) & \" \"
    end repeat
    set o to o & \"|\"
    repeat with r in (bcc recipients of m)
      set o to o & (address of r) & \" \"
    end repeat
    return o
  end tell" 2>/dev/null || true)"
  case "$hdr_actual" in
    *"cc-one@example.invalid"*"cc-two@example.invalid"*) ;;
    *) echo "smoke_mail: both Cc addresses did not reach the draft (got: $hdr_actual)" >&2; exit 1 ;;
  esac
  case "$hdr_actual" in
    *"bcc@example.invalid"*) ;;
    *) echo "smoke_mail: the Bcc address did not reach the draft (got: $hdr_actual)" >&2; exit 1 ;;
  esac
  case "$hdr_actual" in
    "$own_addr"*) ;;
    *) echo "smoke_mail: --from did not set the sender (got: $hdr_actual)" >&2; exit 1 ;;
  esac

  # A sender the account cannot send as must be refused before Mail is involved,
  # because Mail silently falls back to the account default instead of failing.
  if "$ROOT_DIR/scripts/commands/message/create.sh" --from "not-mine@example.invalid" \
      "$first_acc" "nobody@example.invalid" "$hdr_subject" "probe" false >/dev/null 2>&1; then
    echo "smoke_mail: a sender outside the account was accepted." >&2
    exit 1
  fi

  cleanup_hdr_probe "$first_acc"
  warn_if_hdr_probe_left "$first_acc"
  trap - EXIT
fi

echo "smoke_mail: headers ok"
