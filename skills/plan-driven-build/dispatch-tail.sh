#!/usr/bin/env sh

# Clarity Framework – readable tail of a dispatch event stream.
#
# A dispatch's stdout is a JSONL event stream, not prose, so `tail` on it costs the reader far more
# context than it returns. This prints the last N events as one bounded line each: the event type,
# and whichever of command, exit code, message, or text the event carries.
#
# Usage: dispatch-tail.sh --events FILE [--lines N] [--width N]

set -eu

die() { printf '%s\n' "$1" >&2; exit 2; }

EVENTS=''
LINES_N=15
WIDTH=200
while [ "$#" -gt 0 ]; do
  case "$1" in
    --events) EVENTS="${2:-}"; shift 2 ;;
    --lines) LINES_N="${2:-}"; shift 2 ;;
    --width) WIDTH="${2:-}"; shift 2 ;;
    *) die "dispatch-tail.sh: unknown argument '$1'" ;;
  esac
done
[ -n "$EVENTS" ] || die 'dispatch-tail.sh: --events is required'
case "$LINES_N:$WIDTH" in
  *[!0-9:]*|:*|*:) die 'dispatch-tail.sh: --lines and --width must be positive integers' ;;
esac
[ "$LINES_N" -gt 0 ] || die 'dispatch-tail.sh: --lines must be positive'
[ "$WIDTH" -gt 0 ] || die 'dispatch-tail.sh: --width must be positive'
[ -r "$EVENTS" ] || die "dispatch-tail.sh: events file not readable: $EVENTS"

tail -n "$LINES_N" "$EVENTS" | awk -v width="$WIDTH" '
  # Value of the first JSON string field named key, with escapes left as written.
  function str(s, key,   p, r, out, ch, i) {
    p = index(s, "\"" key "\"")
    if (!p) return ""
    r = substr(s, p + length(key) + 2)
    sub(/^[[:space:]]*:[[:space:]]*/, "", r)
    if (substr(r, 1, 1) != "\"") return ""
    out = ""
    for (i = 2; i <= length(r); i++) {
      ch = substr(r, i, 1)
      if (ch == "\\") { out = out ch substr(r, i + 1, 1); i++; continue }
      if (ch == "\"") break
      out = out ch
    }
    return out
  }
  function num(s, key,   p, r) {
    p = index(s, "\"" key "\"")
    if (!p) return ""
    r = substr(s, p + length(key) + 2)
    sub(/^[[:space:]]*:[[:space:]]*/, "", r)
    if (r !~ /^-?[0-9]/) return ""
    sub(/[^0-9-].*$/, "", r)
    return r
  }
  function clip(s) {
    gsub(/\\n/, " ", s)
    gsub(/[[:space:]]+/, " ", s)
    return length(s) > width ? substr(s, 1, width) "…" : s
  }
  {
    type = str($0, "type")
    rest = substr($0, index($0, "\"type\"") + 6)
    kind = str(rest, "type")
    line = type == "" ? "event" : type
    if (kind != "") line = line "/" kind
    cmd = str($0, "command")
    if (cmd != "") line = line "  $ " clip(cmd)
    code = num($0, "exit_code")
    if (code != "") line = line "  exit=" code
    msg = str($0, "message")
    if (msg != "") line = line "  " clip(msg)
    txt = str($0, "text")
    if (txt != "") line = line "  " clip(txt)
    print line
  }
'
