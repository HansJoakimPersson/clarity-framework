#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
CHECKER="$SCRIPT_DIR/scripts/check-update-scope.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM

make_repo() {
  local name=$1
  local repo="$TEST_ROOT/$name"
  mkdir -p "$repo/src" "$repo/docs" "$repo/.agents/skills/planstyrt-bygge"
  git -C "$repo" init -q
  git -C "$repo" config user.name 'Clarity test'
  git -C "$repo" config user.email 'clarity-test@example.invalid'
  printf 'class App {}\n' > "$repo/src/App.java"
  printf '# Scope\n' > "$repo/docs/01-vision-scope.md"
  printf '%s\n' 'tracked skill' > "$repo/.agents/skills/planstyrt-bygge/SKILL.md"
  git -C "$repo" add .
  git -C "$repo" commit -qm initial
  printf '%s\n' "$repo"
}

run_checker() {
  local repo=$1
  (cd "$repo" && "$CHECKER" --framework-skills ramverksuppdatering,planstyrt-bygge)
}

source_repo=$(make_repo source-dirty)
printf '// local work\n' >> "$source_repo/src/App.java"
git -C "$source_repo" add src/App.java
run_checker "$source_repo" > "$TEST_ROOT/source.out"
grep -F 'allowed unrelated dirty paths: 1' "$TEST_ROOT/source.out" >/dev/null

bootstrap_repo=$(make_repo bootstrap)
mkdir -p "$bootstrap_repo/.agents/skills/ramverksuppdatering" "$bootstrap_repo/.claude/skills/ramverksuppdatering"
printf '%s\n' skill > "$bootstrap_repo/.agents/skills/ramverksuppdatering/SKILL.md"
printf '%s\n' skill > "$bootstrap_repo/.claude/skills/ramverksuppdatering/SKILL.md"
run_checker "$bootstrap_repo" > "$TEST_ROOT/bootstrap.out"
grep -F 'allowed untracked updater bootstrap paths: 2' "$TEST_ROOT/bootstrap.out" >/dev/null

docs_repo=$(make_repo docs-conflict)
printf '// local documentation\n' >> "$docs_repo/docs/01-vision-scope.md"
if run_checker "$docs_repo" > "$TEST_ROOT/docs.out" 2>&1; then
  printf '%s\n' 'expected docs conflict' >&2
  exit 1
fi
grep -F 'docs/01-vision-scope.md' "$TEST_ROOT/docs.out" >/dev/null

skill_repo=$(make_repo skill-conflict)
printf '// local skill edit\n' >> "$skill_repo/.agents/skills/planstyrt-bygge/SKILL.md"
if run_checker "$skill_repo" > "$TEST_ROOT/skill.out" 2>&1; then
  printf '%s\n' 'expected managed skill conflict' >&2
  exit 1
fi
grep -F '.agents/skills/planstyrt-bygge/SKILL.md' "$TEST_ROOT/skill.out" >/dev/null

printf '%s\n' 'check-update-scope-test: ok'
