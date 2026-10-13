#!/usr/bin/env sh

set -eu

PLAN=''
OUT=''
MAX_BYTES=65536
MAX_FILE_BYTES=24576

die() { printf '%s\n' "$1" >&2; exit 2; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --plan) PLAN=${2:-}; shift 2 ;;
    --out) OUT=${2:-}; shift 2 ;;
    --max-bytes) MAX_BYTES=${2:-}; shift 2 ;;
    --max-file-bytes) MAX_FILE_BYTES=${2:-}; shift 2 ;;
    *) die "context-pack.sh: unknown argument: $1" ;;
  esac
done

[ -n "$PLAN" ] || die 'context-pack.sh: --plan is required'
[ -n "$OUT" ] || die 'context-pack.sh: --out is required'
case "$MAX_BYTES:$MAX_FILE_BYTES" in
  *[!0-9:]*|:*|*:) die 'context-pack.sh: byte limits must be positive integers' ;;
esac
[ "$MAX_BYTES" -gt 0 ] || die 'context-pack.sh: --max-bytes must be positive'
[ "$MAX_FILE_BYTES" -gt 0 ] || die 'context-pack.sh: --max-file-bytes must be positive'

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die 'context-pack.sh: run from a Git repository'
cd "$ROOT"
[ -r "$PLAN" ] || die "context-pack.sh: plan not readable: $PLAN"

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
REFS="$TMP_ROOT/refs"
PACK="$TMP_ROOT/pack"
SECTION="$TMP_ROOT/section"

awk '
  /^## Context to read first[[:space:]]*$/ { in_context=1; next }
  in_context && /^##[[:space:]]/ { exit }
  in_context && /^\|/ {
    if (match($0, /`[^`]+`/)) {
      ref=substr($0, RSTART+1, RLENGTH-2)
      if (ref != "Reference" && ref != "Document") print ref
    }
  }
' "$PLAN" | awk '!seen[$0]++' > "$REFS"

[ -s "$REFS" ] || die 'context-pack.sh: plan has no context references'

BASELINE=$(git rev-parse HEAD 2>/dev/null || printf unknown)
{
  printf '# Context Pack\n\n'
  printf 'Plan: %s\n' "$PLAN"
  printf 'Baseline: %s\n' "$BASELINE"
  printf 'Policy: max-pack-bytes=%s; max-whole-file-bytes=%s; archive=explicitly-forbidden\n' "$MAX_BYTES" "$MAX_FILE_BYTES"
} > "$PACK"

ref_count=0
while IFS= read -r ref; do
  [ -n "$ref" ] || continue

  case "$ref" in
    AGENTS.md|CLAUDE.md)
      # Runtime instruction files are injected by the agent harness and must not be duplicated.
      continue
      ;;
  esac

  case "$ref" in
    /*|../*|*/../*|*/..)
      die "context-pack.sh: unsafe reference: $ref"
      ;;
  esac

  case "$ref" in
    *'#'*)
      path=${ref%%#*}
      selector=${ref#*#}
      [ -n "$selector" ] || die "context-pack.sh: empty selector in reference: $ref"
      ;;
    *)
      path=$ref
      selector=''
      ;;
  esac

  case "$path" in
    docs/archive/*|*/docs/archive/*)
      die "context-pack.sh: archive content is cold context and cannot be packed automatically: $path"
      ;;
  esac

  [ -r "$path" ] || die "context-pack.sh: referenced file not readable: $path"
  : > "$SECTION"

  if [ -z "$selector" ]; then
    file_bytes=$(wc -c < "$path" | tr -d ' ')
    [ "$file_bytes" -le "$MAX_FILE_BYTES" ] || die "context-pack.sh: whole-file reference exceeds $MAX_FILE_BYTES bytes; add a #heading selector: $path ($file_bytes bytes)"
    cat "$path" > "$SECTION"
  else
    # Resolve the selector to one heading line. A planner writes what it sees: the exact heading
    # text, a GitHub-style slug of it, or the heading without the backticks a reference cannot
    # carry. All three must find the same section, and an exact match must beat a looser one.
    # Case folding covers ASCII only; non-ASCII letters must match as written.
    target=$(awk -v selector="$selector" '
      function plain(t) {
        gsub(/`/, "", t)
        gsub(/[[:space:]]+/, " ", t)
        sub(/^ /, "", t); sub(/ $/, "", t)
        return tolower(t)
      }
      function slug(t) {
        t = plain(t)
        gsub(/[][!"#$%&\047()*+,.\/:;<=>?@\\^{|}~]/, "", t)
        gsub(/ /, "-", t)
        return t
      }
      BEGIN { want_plain = plain(selector); want_slug = slug(selector); best = 9 }
      /^```/ { fenced = !fenced; next }
      fenced { next }
      /^#+[[:space:]]/ {
        title = $0
        sub(/^#+[[:space:]]+/, "", title)
        sub(/[[:space:]]+#*[[:space:]]*$/, "", title)
        rank = 9
        if (title == selector) rank = 1
        else if (plain(title) == want_plain) rank = 2
        else if (slug(title) == want_slug) rank = 3
        else if (index(title, selector) > 0) rank = 4
        else if (index(plain(title), want_plain) > 0) rank = 5
        if (rank < best) { best = rank; line = NR }
      }
      END { if (best < 9) print line }
    ' "$path")
    [ -n "$target" ] || die "context-pack.sh: heading selector not found: $ref (cite the heading text as written, without backticks, or its slug)"
    awk -v target="$target" '
      function heading_level(line, x) {
        x=line
        sub(/[^#].*$/, "", x)
        return length(x)
      }
      /^```/ { fenced = !fenced }
      NR == target { found=1; selected_level=heading_level($0); print; next }
      found && !fenced && /^#+[[:space:]]/ && heading_level($0) <= selected_level { exit }
      found { print }
    ' "$path" > "$SECTION"
  fi

  {
    printf '\n---\n\n## %s\n\n' "$ref"
    cat "$SECTION"
    printf '\n'
  } >> "$PACK"
  ref_count=$((ref_count + 1))

  bytes=$(wc -c < "$PACK" | tr -d ' ')
  [ "$bytes" -le "$MAX_BYTES" ] || die "context-pack.sh: context pack exceeds $MAX_BYTES bytes after $ref ($bytes bytes)"
done < "$REFS"

[ "$ref_count" -gt 0 ] || die 'context-pack.sh: all context references were runtime instructions; add project context references'

mkdir -p "$(dirname "$OUT")"
mv "$PACK" "$OUT"
bytes=$(wc -c < "$OUT" | tr -d ' ')
printf 'CONTEXT_PACK refs=%s bytes=%s max=%s out=%s\n' "$ref_count" "$bytes" "$MAX_BYTES" "$OUT"
