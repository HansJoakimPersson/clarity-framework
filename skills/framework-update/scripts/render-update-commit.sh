#!/usr/bin/env bash

# Render a safe, copyable commit block for the exact paths changed by framework-update.

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

for path in "${UPDATE_PATHS[@]}"; do
  [ -n "$path" ] || die 'render-update-commit.sh: path may not be empty'
  [[ "$path" != /* && "$path" != *$'\n'* && "$path" != ../* && "$path" != */../* ]] \
    || die "render-update-commit.sh: path must be a relative project path: '$path'"
done

printf '%s\n' 'UPDATE_PATHS=('
for path in "${UPDATE_PATHS[@]}"; do
  printf '  %q\n' "$path"
done
printf '%s\n\n' ')'
printf '%s\n' 'git add -- "${UPDATE_PATHS[@]}"'
printf '%s\n' 'git diff --cached --name-only -- "${UPDATE_PATHS[@]}"'
printf 'git commit --only -m "[minor] Uppdatera Clarity Framework till v%s" -- "${UPDATE_PATHS[@]}"\n' \
  "$VERSION"
