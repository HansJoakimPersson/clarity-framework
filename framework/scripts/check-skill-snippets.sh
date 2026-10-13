#!/usr/bin/env bash

# Checks the shell snippets in tracked Markdown for constructs that behave differently in zsh.
#
# An orchestrator pastes these snippets into whatever shell its client gives it, and on macOS that
# is zsh. Three constructs have each cost a real run:
#
#   colon-modifier   "$NEW:skills"  zsh applies ':s' as a history-style modifier to $NEW.
#                                   Write "${NEW}:skills".
#   unquoted-list    $model_args    zsh does not split an unquoted variable into words, so the
#                                   whole list arrives as one argument. Build the list with
#                                   `set --` and pass "$@".
#   equals-word      echo ====      zsh expands a word that starts with '=' as a command path.
#                                   Quote it or use another separator.
#
# Only fenced blocks tagged bash, sh, shell, or zsh are read. A line ending in `# zsh-ok` is
# exempt, for the rare snippet that documents the trap itself.

set -euo pipefail

die() { printf '%s\n' "$1" >&2; exit 2; }

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) ||
  die 'check-skill-snippets.sh: run from a Git repository'
cd -- "$ROOT"

files=()
while IFS= read -r file; do
  case "$file" in framework/CHANGELOG.md) continue ;; esac
  files+=("$file")
done < <(git ls-files '*.md')
[ "${#files[@]}" -gt 0 ] || { printf 'PASS  skill-snippets: no tracked Markdown\n'; exit 0; }

findings=$(awk '
  function report(rule, text) {
    printf "FAIL  skill-snippets: %s:%d: %s: %s\n", FILENAME, FNR, rule, text
  }
  FNR == 1 { inside = 0 }
  /^[[:space:]]*(```|~~~)/ {
    if (inside) { inside = 0; next }
    tag = $0
    sub(/^[[:space:]]*(```|~~~)[[:space:]]*/, "", tag)
    sub(/[[:space:]].*$/, "", tag)
    if (tag == "bash" || tag == "sh" || tag == "shell" || tag == "zsh") inside = 1
    else inside = 2
    next
  }
  inside != 1 { next }
  /#[[:space:]]*zsh-ok[[:space:]]*$/ { next }
  {
    line = $0
    sub(/^[[:space:]]+/, "", line)
    if (line ~ /^#/) next
    if (line ~ /\$[A-Za-z_][A-Za-z0-9_]*:[A-Za-z]/) report("colon-modifier", line)
    if (line ~ /(^|[[:space:]])\$[A-Za-z_][A-Za-z0-9_]*(_args|_ARGS|_opts|_OPTS|_flags|_FLAGS)([[:space:]]|\\|$)/)
      report("unquoted-list", line)
    if (line ~ /(^|[[:space:]])=[A-Za-z=]/) report("equals-word", line)
  }
' "${files[@]}")

if [ -n "$findings" ]; then
  printf '%s\n' "$findings" >&2
  printf 'FAIL  skill-snippets: %s construct(s) that zsh reads differently; see the header of this script\n' \
    "$(printf '%s\n' "$findings" | wc -l | tr -d ' ')" >&2
  exit 1
fi
printf 'PASS  skill-snippets: %s Markdown file(s), shell snippets are zsh-safe\n' "${#files[@]}"
