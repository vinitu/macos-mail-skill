#!/usr/bin/env bash
# Resolve a message ROWID from the Envelope Index to its RFC Message-ID header.
#
# Why this exists: `search.sh` and `search-global.sh` read the SQLite Envelope
# Index and emit `messages.ROWID` as the `id` field. Every id-consuming command
# (`get`, `show`, `exists`, `flag`, `move`, `delete`, `reply`, ...) resolves ids
# through `find-index.applescript`, which matches on `message id` — the RFC
# header. The two never met, so no id returned by a search could be fed to any
# reader.
#
# The SQL does try to emit the header, via
# `COALESCE(mgd.message_id_header, CAST(m.ROWID AS TEXT))`, but on macOS 26
# `message_global_data.message_id_header` is NULL for every row — measured at
# 0 of 269 513 messages — so the ROWID fallback fires 100 % of the time.
#
# The bridge is the on-disk message file, whose name IS the ROWID.

# Root of the Mail store. Overridable so tests need not touch the real one.
MAIL_STORE_ROOT="${MAIL_STORE_ROOT:-$HOME/Library/Mail/V10}"

# Directory path Mail uses for a given ROWID.
#
# Layout: <account>/<Mailbox>.mbox/<uuid>/Data/<d>/<d>/<d>/<d>/Messages/<rowid>.emlx
# where the digit directories are the digits of floor(rowid / 1000), reversed.
# Verified against 400 real message files on 2026-09-01: 400 matches, 0 misses.
#
# Untested edge: a ROWID below 1000 gives floor() == 0 and so the path "0/". No
# such message exists in this store (the lowest ROWID is 2977), so the form is
# unconfirmed. If it is wrong the glob simply finds nothing and the caller gets a
# clean "not found" — never a wrong message.
emlx_data_subpath() {
  local rowid="$1"
  local head="$((rowid / 1000))"
  local out="" i
  for ((i = ${#head} - 1; i >= 0; i--)); do
    out+="${head:i:1}/"
  done
  printf '%s' "$out"
}

# Absolute path of the .emlx file for a ROWID, or empty if it is not on disk.
#
# A bounded glob rather than `find`: computing the digit path prunes the walk to
# one small directory. A recursive search of the whole store is not viable — a
# recursive glob over ~/Library/Mail/V10 did not finish inside 120 s.
emlx_path_for_rowid() {
  local rowid="$1"
  [[ "$rowid" =~ ^[0-9]+$ ]] || return 1

  local sub
  sub="$(emlx_data_subpath "$rowid")"

  local candidate
  # Mailbox nesting depth varies: a top-level mailbox, one level ([Gmail]/Drafts),
  # and a third for deeper user hierarchies. This store has depths 1 and 2;
  # the third is there so a deeper tree elsewhere is not silently missed.
  for candidate in \
    "$MAIL_STORE_ROOT"/*/*.mbox/*/Data/"$sub"Messages/"$rowid".emlx \
    "$MAIL_STORE_ROOT"/*/*.mbox/*/Data/"$sub"Messages/"$rowid".partial.emlx \
    "$MAIL_STORE_ROOT"/*/*.mbox/*.mbox/*/Data/"$sub"Messages/"$rowid".emlx \
    "$MAIL_STORE_ROOT"/*/*.mbox/*.mbox/*/Data/"$sub"Messages/"$rowid".partial.emlx \
    "$MAIL_STORE_ROOT"/*/*.mbox/*.mbox/*.mbox/*/Data/"$sub"Messages/"$rowid".emlx \
    "$MAIL_STORE_ROOT"/*/*.mbox/*.mbox/*.mbox/*/Data/"$sub"Messages/"$rowid".partial.emlx
  do
    [[ -f "$candidate" ]] && { printf '%s' "$candidate"; return 0; }
  done

  return 1
}

# RFC Message-ID header for a ROWID, without the angle brackets.
#
# An .emlx begins with a byte count on its own line; the headers follow. Reading
# only up to the blank line keeps this cheap even for a large message, and a
# folded header (RFC 5322 continuation lines) is joined before matching.
message_id_from_rowid() {
  local rowid="$1"
  local path
  path="$(emlx_path_for_rowid "$rowid")" || return 1

  # Line 1 is the .emlx byte count; stop at the blank line that ends the
  # headers, so a large body is never read. Folded continuation lines
  # (RFC 5322) are joined onto the field before it is emitted.
  local raw
  raw="$(/usr/bin/sed -n '2,/^[[:space:]]*$/p' "$path" 2>/dev/null \
    | /usr/bin/awk '
        /^[Mm]essage-[Ii][Dd]:/ { found = 1; buf = $0; next }
        found && /^[ \t]/ { buf = buf " " $0; next }
        found { print buf; found = 0; exit }
        END { if (found) print buf }   # header was the last line before the body
      ')"

  [[ -n "$raw" ]] || return 1

  # Strip the field name, surrounding whitespace and the angle brackets.
  printf '%s' "$raw" \
    | /usr/bin/sed -e 's/^[Mm]essage-[Ii][Dd]:[[:space:]]*//' \
                   -e 's/^<//' -e 's/>[[:space:]]*$//' \
                   -e 's/[[:space:]]//g'
}
