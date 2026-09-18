#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
CHECKER="$SCRIPT_DIR/check-context-budgets.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM

make_repo() {
  local name=$1
  local repo="$TEST_ROOT/$name"
  mkdir -p "$repo/agents" "$repo/templates"
  git -C "$repo" init -q
  printf '# starter\n' > "$repo/agents/generic.md"
  printf '# readme\n' > "$repo/agents/README.md"
  printf '# ai context\n' > "$repo/templates/00-ai-context.md"
  git -C "$repo" add .
  git -C "$repo" -c user.name='Clarity test' -c user.email='clarity-test@example.invalid' commit -qm initial
  printf '%s\n' "$repo"
}

ok=$(make_repo ok)
(cd "$ok" && CLARITY_MAX_AGENT_BYTES=64 CLARITY_MAX_AI_CONTEXT_BYTES=64 "$CHECKER" > "$TEST_ROOT/ok.out")
grep -F 'PASS  context-budget' "$TEST_ROOT/ok.out" >/dev/null

bad_agent=$(make_repo bad-agent)
awk 'BEGIN { for (i=0; i<100; i++) printf "x" }' >> "$bad_agent/agents/generic.md"
if (cd "$bad_agent" && CLARITY_MAX_AGENT_BYTES=64 CLARITY_MAX_AI_CONTEXT_BYTES=1000 "$CHECKER" > "$TEST_ROOT/bad-agent.out" 2>&1); then
  printf 'context-budget-test: oversized agent starter should fail\n' >&2
  exit 1
fi
grep -F 'agents/generic.md' "$TEST_ROOT/bad-agent.out" >/dev/null

bad_context=$(make_repo bad-context)
awk 'BEGIN { for (i=0; i<100; i++) printf "x" }' >> "$bad_context/templates/00-ai-context.md"
if (cd "$bad_context" && CLARITY_MAX_AGENT_BYTES=1000 CLARITY_MAX_AI_CONTEXT_BYTES=64 "$CHECKER" > "$TEST_ROOT/bad-context.out" 2>&1); then
  printf 'context-budget-test: oversized AI context should fail\n' >&2
  exit 1
fi
grep -F 'templates/00-ai-context.md' "$TEST_ROOT/bad-context.out" >/dev/null

printf 'context-budget-test: ok\n'
