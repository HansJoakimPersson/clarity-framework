#!/usr/bin/env bash

# Runs shellcheck over every tracked shell script in the repository. Skips, rather than fails,
# when shellcheck is not installed — a missing linter on a developer machine is not a defect in
# the scripts themselves, and this repo has no CI that guarantees the tool is present.

set -euo pipefail

die() { printf '%s\n' "$1" >&2; exit 2; }

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die 'lint-shell.sh: run from a Git repository'
cd -- "$REPO_ROOT"

if ! command -v shellcheck >/dev/null 2>&1; then
  printf 'SKIP  shellcheck not installed; install it to lint shell scripts locally\n' >&2
  exit 0
fi

mapfile -t SCRIPTS < <(git ls-files '*.sh')
[ "${#SCRIPTS[@]}" -gt 0 ] || { printf 'PASS  lint-shell: no tracked *.sh files\n'; exit 0; }

if shellcheck --severity=warning "${SCRIPTS[@]}"; then
  printf 'PASS  lint-shell: %s script(s) clean\n' "${#SCRIPTS[@]}"
else
  printf 'FAIL  lint-shell: see shellcheck output above\n' >&2
  exit 1
fi
