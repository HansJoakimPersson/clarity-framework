#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
RENDERER="$SCRIPT_DIR/scripts/render-update-commit.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM

REPO="$TEST_ROOT/repo"
mkdir -p "$REPO/docs/archive" "$REPO/src"
git -C "$REPO" init -q
git -C "$REPO" config user.name 'Clarity test'
git -C "$REPO" config user.email 'clarity-test@example.invalid'

printf '# Agent\n\n*Clarity Framework v4.2.0*\n' > "$REPO/AGENTS.md"
printf '# AI Context\n\n| **Framework version** | Clarity Framework v4.2.0 |\n\n*Clarity Framework v4.2.0*\n' > "$REPO/docs/00-ai-context.md"
printf '# Scope\n\nProject prose.\n\n*Clarity Framework v4.2.0*\n' > "$REPO/docs/01-vision-scope.md"
printf '# Historical story\n\n*Clarity Framework v4.2.0*\n' > "$REPO/docs/archive/stories-2026.md"
printf 'class App {}\n' > "$REPO/src/App.java"
git -C "$REPO" add .
git -C "$REPO" commit -qm initial

printf '// local work\n' >> "$REPO/src/App.java"
git -C "$REPO" add src/App.java

OUTPUT="$TEST_ROOT/commit.sh"
(
  cd "$REPO"
  bash "$RENDERER" --version 4.3.0 \
    --path AGENTS.md \
    --path .agents/skills/framework-update \
    --path .claude/skills/framework-update > "$OUTPUT"
)

bash -n "$OUTPUT"
grep -Fx '  .agents/skills/framework-update' "$OUTPUT" >/dev/null
grep -Fx '  .claude/skills/framework-update' "$OUTPUT" >/dev/null
grep -Fx '  docs/00-ai-context.md' "$OUTPUT" >/dev/null
grep -Fx '  docs/01-vision-scope.md' "$OUTPUT" >/dev/null
if grep -F 'docs/archive/' "$OUTPUT" >/dev/null; then
  printf '%s\n' 'render-update-commit-test: cold archive must not be auto-included' >&2
  exit 1
fi
grep -Fx 'git add -- "${UPDATE_PATHS[@]}"' "$OUTPUT" >/dev/null
grep -Fx 'git commit --only -m "[minor] Update Clarity Framework to v4.3.0" -- "${UPDATE_PATHS[@]}"' "$OUTPUT" >/dev/null

ARRAY_ONLY="$TEST_ROOT/array.sh"
sed -n '/^UPDATE_PATHS=(/,/^)/p' "$OUTPUT" > "$ARRAY_ONLY"
# shellcheck disable=SC1090
source "$ARRAY_ONLY"
test "${#UPDATE_PATHS[@]}" -eq 5
test "${UPDATE_PATHS[3]}" = 'docs/00-ai-context.md'
test "${UPDATE_PATHS[4]}" = 'docs/01-vision-scope.md'

mkdir -p "$REPO/.agents/skills/framework-update" "$REPO/.claude/skills/framework-update"
printf 'new updater\n' > "$REPO/.agents/skills/framework-update/SKILL.md"
printf 'new updater\n' > "$REPO/.claude/skills/framework-update/SKILL.md"
printf '# Agent\n\n*Clarity Framework v4.3.0*\n' > "$REPO/AGENTS.md"
sed -i 's/Clarity Framework v4\.2\.0/Clarity Framework v4.3.0/g' "$REPO/docs/00-ai-context.md"
sed -i 's/Clarity Framework v4\.2\.0/Clarity Framework v4.3.0/g' "$REPO/docs/01-vision-scope.md"

(
  cd "$REPO"
  bash "$OUTPUT"
)

committed=$(git -C "$REPO" show --pretty='' --name-only HEAD | sort)
printf '%s\n' "$committed" | grep -Fx 'AGENTS.md' >/dev/null
printf '%s\n' "$committed" | grep -Fx '.agents/skills/framework-update/SKILL.md' >/dev/null
printf '%s\n' "$committed" | grep -Fx '.claude/skills/framework-update/SKILL.md' >/dev/null
printf '%s\n' "$committed" | grep -Fx 'docs/00-ai-context.md' >/dev/null
printf '%s\n' "$committed" | grep -Fx 'docs/01-vision-scope.md' >/dev/null
if printf '%s\n' "$committed" | grep -Fx 'src/App.java' >/dev/null; then
  printf '%s\n' 'render-update-commit-test: unrelated staged source was committed' >&2
  exit 1
fi
git -C "$REPO" diff --cached --name-only | grep -Fx 'src/App.java' >/dev/null

if (
  cd "$REPO"
  bash "$RENDERER" --version 4.3.0 --path ../outside >/dev/null 2>&1
); then
  printf '%s\n' 'expected relative-path validation failure' >&2
  exit 1
fi

printf '%s\n' 'render-update-commit-test: ok'
