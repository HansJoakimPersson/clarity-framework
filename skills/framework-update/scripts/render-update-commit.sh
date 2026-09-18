#!/usr/bin/env bash

# Render a safe, copyable commit block for the exact paths changed by framework-update.
# Active standard docs with a Clarity version marker are included automatically so legacy updater
# procedures that render before stamping cannot leave version-only edits outside the update commit.

set -euo pipefail

die() { printf '%s\n' "$1" >&2; exit 2; }

VERSION=''
declare -a UPDATE_PATHS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --version) VERSION="${2:-}"; shift 2 ;;
    --path) UPDATE_PATHS+=("${2:-}"); shift 2 ;;
    *) die "render-update-commit.sh: unknown argument '$1'" ;;
  esac
done

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'render-update-commit.sh: --version must be X.Y.Z'
[ "${#UPDATE_PATHS[@]}" -gt 0 ] || die 'render-update-commit.sh: provide at least one --path'

git rev-parse --show-toplevel >/dev/null 2>&1 ||
  die 'render-update-commit.sh: run from a Git repository'

contains_path() {
  local want=$1 existing
  for existing in "${UPDATE_PATHS[@]}"; do
    [ "$existing" = "$want" ] && return 0
  done
  return 1
}

for path in "${UPDATE_PATHS[@]}"; do
  [ -n "$path" ] || die 'render-update-commit.sh: path may not be empty'
  [[ "$path" != /* && "$path" != *$'\n'* && "$path" != ../* && "$path" != */../* ]] \
    || die "render-update-commit.sh: path must be a relative project path: '$path'"
done

# All tracked active standard docs carrying a Clarity marker will be stamped during an upgrade.
# Include them even if they are still clean at render time. Do not traverse docs/archive/.
while IFS= read -r marker_path; do
  [ -n "$marker_path" ] || continue
  contains_path "$marker_path" || UPDATE_PATHS+=("$marker_path")
done < <(git grep -lE 'Clarity Framework v[0-9]+\.[0-9]+\.[0-9]+' -- 'docs/[0-9][0-9]-*.md' 2>/dev/null || true)

printf '%s\n' 'UPDATE_PATHS=('
for path in "${UPDATE_PATHS[@]}"; do
  printf '  %q\n' "$path"
done
printf '%s\n\n' ')'
printf '%s\n' 'git add -- "${UPDATE_PATHS[@]}"'
printf '%s\n' 'git diff --cached --name-only -- "${UPDATE_PATHS[@]}"'
printf 'git commit --only -m "[minor] Update Clarity Framework to v%s" -- "${UPDATE_PATHS[@]}"\n' \
  "$VERSION"
