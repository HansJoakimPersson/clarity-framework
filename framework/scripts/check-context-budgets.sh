#!/usr/bin/env bash

set -euo pipefail

MAX_AGENT_BYTES=${CLARITY_MAX_AGENT_BYTES:-24576}
MAX_AI_CONTEXT_BYTES=${CLARITY_MAX_AI_CONTEXT_BYTES:-16384}

die() { printf '%s\n' "$1" >&2; exit 2; }

[[ "$MAX_AGENT_BYTES" =~ ^[0-9]+$ ]] && (( MAX_AGENT_BYTES > 0 )) ||
  die 'check-context-budgets.sh: CLARITY_MAX_AGENT_BYTES must be a positive integer'
[[ "$MAX_AI_CONTEXT_BYTES" =~ ^[0-9]+$ ]] && (( MAX_AI_CONTEXT_BYTES > 0 )) ||
  die 'check-context-budgets.sh: CLARITY_MAX_AI_CONTEXT_BYTES must be a positive integer'

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) ||
  die 'check-context-budgets.sh: run from a Git repository'
cd -- "$ROOT"

fail=0
count=0
for file in agents/*.md; do
  [[ -e "$file" ]] || continue
  [[ "$file" == "agents/README.md" ]] && continue
  bytes=$(wc -c < "$file" | tr -d ' ')
  count=$((count + 1))
  if (( bytes > MAX_AGENT_BYTES )); then
    printf 'FAIL  context-budget: %s is %s bytes (max %s)\n' "$file" "$bytes" "$MAX_AGENT_BYTES" >&2
    fail=1
  else
    printf 'PASS  context-budget: %s %s/%s bytes\n' "$file" "$bytes" "$MAX_AGENT_BYTES"
  fi
done

(( count > 0 )) || die 'check-context-budgets.sh: no agent starters found'

AI_CONTEXT=templates/00-ai-context.md
[[ -r "$AI_CONTEXT" ]] || die "check-context-budgets.sh: missing $AI_CONTEXT"
bytes=$(wc -c < "$AI_CONTEXT" | tr -d ' ')
if (( bytes > MAX_AI_CONTEXT_BYTES )); then
  printf 'FAIL  context-budget: %s is %s bytes (max %s)\n' "$AI_CONTEXT" "$bytes" "$MAX_AI_CONTEXT_BYTES" >&2
  fail=1
else
  printf 'PASS  context-budget: %s %s/%s bytes\n' "$AI_CONTEXT" "$bytes" "$MAX_AI_CONTEXT_BYTES"
fi

(( fail == 0 )) || exit 1
printf 'PASS  context-budget: %s agent starter(s) and AI context within limits\n' "$count"
