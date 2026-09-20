#!/usr/bin/env bash

set -euo pipefail

SKILLDIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
MISSION="$SKILLDIR/scripts/mission-control.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM

export CLARITY_MISSION_DIR="$TEST_ROOT/mission"
POLICY="$TEST_ROOT/00-ai-context.md"
cat > "$POLICY" <<'EOF'
# AI Context

<!-- clarity-authority:start -->
mode=autonomous
human_gate=reserved-only
unknown_reversible=delegated
unknown_external=escalation
<!-- clarity-authority:end -->
EOF

out=$(bash "$MISSION" start --goal 'Build the whole app' --mode until-complete)
printf '%s\n' "$out" | grep -F 'decision=STARTED' >/dev/null

out=$(bash "$MISSION" start --goal 'Build the whole app' --mode until-complete)
printf '%s\n' "$out" | grep -F 'decision=RESUME' >/dev/null

out=$(bash "$MISSION" checkpoint --project-complete no --ready-work yes --recoverable no)
printf '%s\n' "$out" | grep -F 'decision=CONTINUE' >/dev/null

set +e
out=$(bash "$MISSION" authorize --action architecture.material-change --impact architecture --reason 'Choose a boundary' --policy "$POLICY")
rc=$?
set -e
[ "$rc" -eq 10 ]
printf '%s\n' "$out" | grep -F 'decision=ORCHESTRATOR' >/dev/null
if find "$CLARITY_MISSION_DIR/gates" -name '*.tsv' -print -quit | grep -q .; then
  printf '%s\n' 'mission-control-test: orchestrator escalation created a human gate' >&2
  exit 1
fi

set +e
out=$(bash "$MISSION" authorize --action production.deploy --impact production --reason 'Deploy to production' --policy "$POLICY")
rc=$?
set -e
[ "$rc" -eq 20 ]
printf '%s\n' "$out" | grep -F 'decision=HUMAN_GATE' >/dev/null
gate=$(printf '%s\n' "$out" | sed -n 's/.*gate_id=\([^[:space:]]*\).*/\1/p' | tail -1)
[ -n "$gate" ]
[ -r "$CLARITY_MISSION_DIR/gates/$gate.tsv" ]

set +e
out=$(bash "$MISSION" checkpoint --project-complete no --ready-work yes --recoverable no --gate "$gate")
rc=$?
set -e
[ "$rc" -eq 20 ]
printf '%s\n' "$out" | grep -F 'decision=HUMAN_GATE' >/dev/null

out=$(bash "$MISSION" resolve-gate --gate "$gate" --resolution approved)
printf '%s\n' "$out" | grep -F 'decision=GATE_RESOLVED' >/dev/null

out=$(bash "$MISSION" checkpoint --project-complete no --ready-work yes --recoverable no)
printf '%s\n' "$out" | grep -F 'decision=CONTINUE' >/dev/null

out=$(bash "$MISSION" checkpoint --project-complete yes --ready-work no --recoverable no)
printf '%s\n' "$out" | grep -F 'decision=COMPLETE' >/dev/null

# A runner-owned execution cycle may only request completion; a separate audit must confirm it.
out=$(bash "$MISSION" start --replace --goal 'Build all remaining application work' --mode until-complete)
printf '%s\n' "$out" | grep -F 'decision=STARTED' >/dev/null
export CLARITY_MISSION_CYCLE=0001
out=$(bash "$MISSION" checkpoint --project-complete yes --ready-work no --recoverable no)
printf '%s\n' "$out" | grep -F 'decision=COMPLETION_PENDING' >/dev/null
test "$(awk -F '\t' '$1=="status"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")" = completion-pending

# A different goal cannot silently reuse an active/pending mission.
set +e
out=$(bash "$MISSION" start --goal 'Build a different product' --mode until-complete 2>&1)
rc=$?
set -e
test "$rc" -eq 40
printf '%s\n' "$out" | grep -F 'decision=GOAL_CONFLICT' >/dev/null

# Only a completion-audit cycle may resolve completion-pending.
set +e
out=$(bash "$MISSION" confirm-completion --result complete --reason 'not an audit' 2>&1)
rc=$?
set -e
test "$rc" -eq 2

export CLARITY_MISSION_COMPLETION_AUDIT=1
export CLARITY_MISSION_CYCLE=0002
out=$(bash "$MISSION" confirm-completion --result continue --reason 'FR-002 is still incomplete')
printf '%s\n' "$out" | grep -F 'decision=AUDIT_RECORDED' >/dev/null
test "$(awk -F '\t' '$1=="status"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")" = completion-pending
out=$(bash "$MISSION" finalize-completion-audit --cycle 0002)
printf '%s\n' "$out" | grep -F 'decision=CONTINUE_AFTER_AUDIT' >/dev/null
test "$(awk -F '\t' '$1=="status"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")" = active

unset CLARITY_MISSION_COMPLETION_AUDIT
export CLARITY_MISSION_CYCLE=0003
out=$(bash "$MISSION" checkpoint --project-complete yes --ready-work no --recoverable no)
printf '%s\n' "$out" | grep -F 'decision=COMPLETION_PENDING' >/dev/null
export CLARITY_MISSION_COMPLETION_AUDIT=1
export CLARITY_MISSION_CYCLE=0004
out=$(bash "$MISSION" confirm-completion --result complete --reason 'all mission scope verified')
printf '%s\n' "$out" | grep -F 'decision=AUDIT_RECORDED' >/dev/null
test "$(awk -F '\t' '$1=="status"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")" = completion-pending
out=$(bash "$MISSION" finalize-completion-audit --cycle 0004)
printf '%s\n' "$out" | grep -F 'decision=COMPLETE_CONFIRMED' >/dev/null
test "$(awk -F '\t' '$1=="status"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")" = completed
unset CLARITY_MISSION_CYCLE CLARITY_MISSION_COMPLETION_AUDIT

out=$(bash "$MISSION" start --replace --goal 'Work until deadline' --mode until-complete-or-deadline --deadline-epoch 1)
printf '%s\n' "$out" | grep -F 'decision=STARTED' >/dev/null
set +e
out=$(bash "$MISSION" checkpoint --project-complete no --ready-work yes --recoverable no)
rc=$?
set -e
[ "$rc" -eq 30 ]
printf '%s\n' "$out" | grep -F 'decision=STOP_DEADLINE' >/dev/null

printf '%s\n' 'mission-control-test: ok'
