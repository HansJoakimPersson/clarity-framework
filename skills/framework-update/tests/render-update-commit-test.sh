#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
RENDERER="$SCRIPT_DIR/scripts/render-update-commit.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM

OUTPUT="$TEST_ROOT/commit.sh"
"$RENDERER" --version 1.5.2 \
  --path AGENTS.md \
  --path .agents/skills/framework-update \
  --path .claude/skills/framework-update \
  --path docs/00-ai-context.md > "$OUTPUT"

bash -n "$OUTPUT"
grep -Fx '  .agents/skills/framework-update' "$OUTPUT" >/dev/null
grep -Fx '  .claude/skills/framework-update' "$OUTPUT" >/dev/null
grep -Fx 'git add -- "${UPDATE_PATHS[@]}"' "$OUTPUT" >/dev/null
grep -Fx 'git commit --only -m "[minor] Update Clarity Framework to v1.5.2" -- "${UPDATE_PATHS[@]}"' "$OUTPUT" >/dev/null

ARRAY_ONLY="$TEST_ROOT/array.sh"
sed -n '/^UPDATE_PATHS=(/,/^)/p' "$OUTPUT" > "$ARRAY_ONLY"
source "$ARRAY_ONLY"
test "${#UPDATE_PATHS[@]}" -eq 4
test "${UPDATE_PATHS[1]}" = '.agents/skills/framework-update'
test "${UPDATE_PATHS[2]}" = '.claude/skills/framework-update'

if "$RENDERER" --version 1.5.2 --path ../outside >/dev/null 2>&1; then
  printf '%s\n' 'expected relative-path validation failure' >&2
  exit 1
fi

printf '%s\n' 'render-update-commit-test: ok'
