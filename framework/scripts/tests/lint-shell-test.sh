#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
LINTER="$SCRIPT_DIR/lint-shell.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM

# A minimal PATH containing only real system tools the script itself needs, so each scenario
# below controls solely whether a `shellcheck` is resolvable — never what else is on the host.
BASE_BIN="$TEST_ROOT/base-bin"
mkdir -p "$BASE_BIN"
for tool in bash git sed mapfile cat wc tr mktemp mkdir rm chmod command sh env; do
  path=$(command -v "$tool" 2>/dev/null) || continue
  ln -sf "$path" "$BASE_BIN/$tool"
done

make_repo() {
  local name=$1 script_body=$2
  local repo="$TEST_ROOT/$name"
  mkdir -p "$repo/scripts"
  git -C "$repo" init -q
  git -C "$repo" config user.name 'Clarity test'
  git -C "$repo" config user.email 'clarity-test@example.invalid'
  printf '%s' "$script_body" > "$repo/scripts/sample.sh"
  chmod +x "$repo/scripts/sample.sh"
  git -C "$repo" add .
  git -C "$repo" commit -qm initial
  printf '%s\n' "$repo"
}

clean_repo=$(make_repo clean-script '#!/usr/bin/env bash
set -euo pipefail
printf "hello\n"
')

# Scenario 1: no shellcheck on PATH at all -> SKIP, exit 0.
(cd "$clean_repo" && PATH="$BASE_BIN" "$LINTER" > "$TEST_ROOT/skip.out" 2>&1)
grep -qF 'SKIP  shellcheck not installed' "$TEST_ROOT/skip.out"

if ! command -v shellcheck >/dev/null 2>&1; then
  printf '%s\n' 'lint-shell-test: shellcheck not installed on this machine, skipping PASS/FAIL scenarios'
  printf '%s\n' 'lint-shell-test: ok (partial)'
  exit 0
fi

SHELLCHECK_BIN="$TEST_ROOT/shellcheck-bin"
mkdir -p "$SHELLCHECK_BIN"
ln -sf "$(command -v shellcheck)" "$SHELLCHECK_BIN/shellcheck"

# Scenario 2: shellcheck present, script is clean -> PASS, exit 0.
(cd "$clean_repo" && PATH="$SHELLCHECK_BIN:$BASE_BIN" "$LINTER" > "$TEST_ROOT/pass.out" 2>&1)
grep -qF 'PASS  lint-shell' "$TEST_ROOT/pass.out"

# Scenario 3: shellcheck present, script has a real defect -> FAIL, non-zero exit.
dirty_repo=$(make_repo dirty-script '#!/usr/bin/env bash
cd /tmp
rm -rf "$dir"/*
')
if (cd "$dirty_repo" && PATH="$SHELLCHECK_BIN:$BASE_BIN" "$LINTER" > "$TEST_ROOT/fail.out" 2>&1); then
  printf '%s\n' 'expected shellcheck to flag the unset $dir expansion' >&2
  exit 1
fi
grep -qF 'FAIL  lint-shell' "$TEST_ROOT/fail.out"

printf '%s\n' 'lint-shell-test: ok'
