#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
VERIFY="$SCRIPT_DIR/scripts/verify-managed-runtime.sh"
REPO_ROOT=$(git rev-parse --show-toplevel)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM

TARGET="$TEST_ROOT/target"
PROJECT="$TEST_ROOT/project"
mkdir -p "$TARGET/skills" "$PROJECT/.agents/skills" "$PROJECT/.claude/skills"

for skill in project-driver plan-driven-build; do
  cp -R "$REPO_ROOT/skills/$skill" "$TARGET/skills/$skill"
  cp -R "$REPO_ROOT/skills/$skill" "$PROJECT/.agents/skills/$skill"
  cp -R "$REPO_ROOT/skills/$skill" "$PROJECT/.claude/skills/$skill"
done

# Exact copied managed runtimes, including nested prompts/scripts, must verify and run their smoke tests.
(
  cd "$PROJECT"
  bash "$VERIFY"     --target-root "$TARGET"     --managed-skills project-driver,plan-driven-build     --smoke yes
) > "$TEST_ROOT/ok.out"
grep -F 'RUNTIME-VERIFY: ok managed_skills=project-driver,plan-driven-build smoke=yes' "$TEST_ROOT/ok.out" >/dev/null

# Omitting a newly shipped nested runtime file must fail even if SKILL.md itself exists.
rm "$PROJECT/.claude/skills/project-driver/prompts/mission-completion-audit.txt"
set +e
(
  cd "$PROJECT"
  bash "$VERIFY"     --target-root "$TARGET"     --managed-skills project-driver,plan-driven-build     --smoke no
) > "$TEST_ROOT/missing.out" 2>&1
rc=$?
set -e
test "$rc" -eq 2
grep -E 'differs from target release|payload missing' "$TEST_ROOT/missing.out" >/dev/null
cp "$TARGET/skills/project-driver/prompts/mission-completion-audit.txt"   "$PROJECT/.claude/skills/project-driver/prompts/mission-completion-audit.txt"

# project-driver may not be declared managed without its plan-driven-build runtime dependency.
set +e
(
  cd "$PROJECT"
  bash "$VERIFY"     --target-root "$TARGET"     --managed-skills project-driver     --smoke no
) > "$TEST_ROOT/dependency.out" 2>&1
rc=$?
set -e
test "$rc" -eq 2
grep -F 'project-driver requires managed plan-driven-build' "$TEST_ROOT/dependency.out" >/dev/null

printf '%s\n' 'verify-managed-runtime-test: ok'
