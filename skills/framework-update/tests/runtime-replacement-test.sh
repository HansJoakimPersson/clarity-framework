#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
VERIFY="$SCRIPT_DIR/scripts/verify-managed-runtime.sh"
REPO_ROOT=$(git rev-parse --show-toplevel)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM

TARGET="$TEST_ROOT/target"
PROJECT="$TEST_ROOT/project"
mkdir -p "$TARGET/skills" "$PROJECT/.agents/skills" "$PROJECT/.claude/skills" "$PROJECT/docs"
git -C "$PROJECT" init -q
git -C "$PROJECT" config user.name 'Clarity test'
git -C "$PROJECT" config user.email 'clarity-test@example.invalid'
printf '# Update fixture\n' > "$PROJECT/README.md"
cat > "$PROJECT/docs/00-ai-context.md" <<'EOF'
# AI Context

| **Framework version** | Clarity Framework v4.3.0 |

```text
agents-starter: java-application
skills: project-driver,plan-driven-build
skill-paths: .agents/skills, .claude/skills
```
EOF

for skill in project-driver plan-driven-build; do
  cp -R "$REPO_ROOT/skills/$skill" "$TARGET/skills/$skill"
  for runtime_root in .agents/skills .claude/skills; do
    mkdir -p "$PROJECT/$runtime_root/$skill"
    printf 'legacy runtime for %s\n' "$skill" > "$PROJECT/$runtime_root/$skill/SKILL.md"
    printf 'must be removed\n' > "$PROJECT/$runtime_root/$skill/stale-v430-file.txt"
  done
done
git -C "$PROJECT" add .
git -C "$PROJECT" commit -qm initial

# Model the target release's exact name-scoped replacement rule used by framework-update.
for skill in project-driver plan-driven-build; do
  for runtime_root in .agents/skills .claude/skills; do
    rm -rf -- "$PROJECT/$runtime_root/$skill"
    cp -R "$TARGET/skills/$skill" "$PROJECT/$runtime_root/$skill"
  done
done

(
  cd "$PROJECT"
  bash "$VERIFY"     --target-root "$TARGET"     --managed-skills project-driver,plan-driven-build     --smoke yes
) > "$TEST_ROOT/verify.out"

grep -F 'RUNTIME-VERIFY: ok managed_skills=project-driver,plan-driven-build smoke=yes' "$TEST_ROOT/verify.out" >/dev/null
for runtime_root in .agents/skills .claude/skills; do
  test -f "$PROJECT/$runtime_root/project-driver/prompts/mission-completion-audit.txt"
  test -f "$PROJECT/$runtime_root/project-driver/scripts/mission-runner.sh"
  test -f "$PROJECT/$runtime_root/plan-driven-build/dispatch.sh"
  test ! -e "$PROJECT/$runtime_root/project-driver/stale-v430-file.txt"
  test ! -e "$PROJECT/$runtime_root/plan-driven-build/stale-v430-file.txt"
done

printf '%s\n' 'runtime-replacement-test: ok'
