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
git -C "$PROJECT" init -q
git -C "$PROJECT" config user.name 'Clarity test'
git -C "$PROJECT" config user.email 'clarity-test@example.invalid'
printf '# Runtime verification fixture\n' > "$PROJECT/README.md"
git -C "$PROJECT" add README.md
git -C "$PROJECT" commit -qm initial

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


# An exact runtime copy still fails if any managed nested file is ignored by Git.
printf '%s\n' '/.claude/skills/project-driver/prompts/mission-completion-audit.txt' > "$PROJECT/.gitignore"
set +e
(
  cd "$PROJECT"
  bash "$VERIFY"     --target-root "$TARGET"     --managed-skills project-driver,plan-driven-build     --smoke no
) > "$TEST_ROOT/ignored.out" 2>&1
rc=$?
set -e
test "$rc" -eq 2
grep -F 'managed runtime file is ignored by Git: .claude/skills/project-driver/prompts/mission-completion-audit.txt' "$TEST_ROOT/ignored.out" >/dev/null
rm "$PROJECT/.gitignore"

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

verify_plan_only() {
  (
    cd "$PROJECT"
    bash "$VERIFY" --target-root "$TARGET" --managed-skills plan-driven-build --smoke no
  )
}

# plan-driven-build is verified on its own, not only as a project-driver dependency.
verify_plan_only > "$TEST_ROOT/plan-only.out"
grep -F 'RUNTIME-VERIFY: ok managed_skills=plan-driven-build smoke=no' "$TEST_ROOT/plan-only.out" >/dev/null

# Finder metadata is not a difference.
: > "$PROJECT/.agents/skills/plan-driven-build/.DS_Store"
verify_plan_only > /dev/null
rm "$PROJECT/.agents/skills/plan-driven-build/.DS_Store"

# A sync-conflict copy is a difference, and the message says what it is.
cp "$PROJECT/.agents/skills/plan-driven-build/SKILL.md" "$PROJECT/.agents/skills/plan-driven-build/SKILL 2.md"
if verify_plan_only > "$TEST_ROOT/copy.out" 2>&1; then
  printf '%s\n' 'expected a sync-conflict copy to fail verification' >&2
  exit 1
fi
grep -F 'sync-conflict copy' "$TEST_ROOT/copy.out" >/dev/null
rm "$PROJECT/.agents/skills/plan-driven-build/SKILL 2.md"

# A release whose payload lacks a required file fails even when both copies match it exactly.
for root in "$TARGET/skills" "$PROJECT/.agents/skills" "$PROJECT/.claude/skills"; do
  rm "$root/plan-driven-build/evidence.sh"
done
if verify_plan_only > "$TEST_ROOT/payload.out" 2>&1; then
  printf '%s\n' 'expected a missing plan-driven-build payload file to fail' >&2
  exit 1
fi
grep -F 'plan-driven-build payload missing: .agents/skills/plan-driven-build/evidence.sh' "$TEST_ROOT/payload.out" >/dev/null
for root in "$TARGET/skills" "$PROJECT/.agents/skills" "$PROJECT/.claude/skills"; do
  cp "$REPO_ROOT/skills/plan-driven-build/evidence.sh" "$root/plan-driven-build/evidence.sh"
done

# dispatch.sh is run by path: a copy that lost its mode is caught here, not at the first dispatch.
for root in "$TARGET/skills" "$PROJECT/.agents/skills" "$PROJECT/.claude/skills"; do
  chmod -x "$root/plan-driven-build/dispatch.sh"
done
if verify_plan_only > "$TEST_ROOT/mode.out" 2>&1; then
  printf '%s\n' 'expected a non-executable dispatch.sh to fail' >&2
  exit 1
fi
grep -F 'not executable: .agents/skills/plan-driven-build/dispatch.sh' "$TEST_ROOT/mode.out" >/dev/null

printf '%s\n' 'verify-managed-runtime-test: ok'
