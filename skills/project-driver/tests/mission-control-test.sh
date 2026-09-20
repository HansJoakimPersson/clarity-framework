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

set +e
out=$(bash "$MISSION" checkpoint --project-complete yes --ready-work no --recoverable no 2>&1)
rc=$?
set -e
test "$rc" -eq 2
printf '%s\n' "$out" | grep -F 'completion must be requested by a runner-owned work cycle' >/dev/null

# A runner-owned execution cycle may only request completion; Mission Runner must accept the
# provisional request after a clean process exit, then a separate audit must confirm it.
out=$(bash "$MISSION" start --replace --goal 'Build all remaining application work' --mode until-complete)
printf '%s\n' "$out" | grep -F 'decision=STARTED' >/dev/null
export CLARITY_MISSION_CYCLE=0001
mission_id=$(awk -F '\t' '$1=="id"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")
export CLARITY_MISSION_ID="$mission_id"
runner_owner_pid=$BASHPID
mkdir -p "$CLARITY_MISSION_DIR/runner.lock"
printf '%s\n' "$runner_owner_pid" > "$CLARITY_MISSION_DIR/runner.lock/pid"
printf 'mission_id\t%s\n' "$mission_id" > "$CLARITY_MISSION_DIR/runner.lock/owner.tsv"

runner_finalize() {
  runner_finalize_out="$TEST_ROOT/runner-finalize.out"
  CLARITY_MISSION_RUNNER_FINALIZE=1 CLARITY_MISSION_RUNNER_PID="$runner_owner_pid"     bash "$MISSION" "$@" >"$runner_finalize_out" 2>&1
  out=$(cat "$runner_finalize_out")
}

out=$(bash "$MISSION" checkpoint --project-complete yes --ready-work no --recoverable no)
printf '%s\n' "$out" | grep -F 'decision=COMPLETION_REQUESTED' >/dev/null
test "$(awk -F '\t' '$1=="status"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")" = active

# A work cycle cannot finalize its own completion request.
set +e
out=$(bash "$MISSION" finalize-completion-request --cycle 0001 2>&1)
rc=$?
set -e
test "$rc" -eq 2
printf '%s\n' "$out" | grep -F 'only Mission Runner may finalize' >/dev/null

# Even a worker that copies the finalize flag/PID cannot finalize through a child shell: its direct
# parent is not the runner owner recorded in runner.lock.
set +e
out=$(CLARITY_MISSION_RUNNER_FINALIZE=1 CLARITY_MISSION_RUNNER_PID="$runner_owner_pid"   bash "$MISSION" finalize-completion-request --cycle 0001 2>&1)
rc=$?
set -e
test "$rc" -eq 2
printf '%s\n' "$out" | grep -F 'is not the runner owner' >/dev/null

runner_finalize finalize-completion-request --cycle 0001
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
# The audit cycle may record a result but cannot apply it itself.
set +e
out=$(bash "$MISSION" finalize-completion-audit --cycle 0002 2>&1)
rc=$?
set -e
test "$rc" -eq 2
printf '%s\n' "$out" | grep -F 'only Mission Runner may finalize' >/dev/null

runner_finalize finalize-completion-audit --cycle 0002
printf '%s\n' "$out" | grep -F 'decision=CONTINUE_AFTER_AUDIT' >/dev/null
test "$(awk -F '\t' '$1=="status"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")" = active

unset CLARITY_MISSION_COMPLETION_AUDIT
export CLARITY_MISSION_CYCLE=0003
out=$(bash "$MISSION" checkpoint --project-complete yes --ready-work no --recoverable no)
printf '%s\n' "$out" | grep -F 'decision=COMPLETION_REQUESTED' >/dev/null
runner_finalize finalize-completion-request --cycle 0003
printf '%s\n' "$out" | grep -F 'decision=COMPLETION_PENDING' >/dev/null
export CLARITY_MISSION_COMPLETION_AUDIT=1
export CLARITY_MISSION_CYCLE=0004
out=$(bash "$MISSION" confirm-completion --result complete --reason 'all mission scope verified')
printf '%s\n' "$out" | grep -F 'decision=AUDIT_RECORDED' >/dev/null
test "$(awk -F '\t' '$1=="status"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")" = completion-pending
runner_finalize finalize-completion-audit --cycle 0004
printf '%s\n' "$out" | grep -F 'decision=COMPLETE_CONFIRMED' >/dev/null
test "$(awk -F '\t' '$1=="status"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")" = completed
rm -rf "$CLARITY_MISSION_DIR/runner.lock"
unset CLARITY_MISSION_CYCLE CLARITY_MISSION_COMPLETION_AUDIT CLARITY_MISSION_ID

# A stale runner-owned cycle cannot mutate a replacement mission.
out=$(bash "$MISSION" start --replace --goal 'Old runner mission' --mode until-complete)
old_id=$(awk -F '\t' '$1=="id"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")
out=$(bash "$MISSION" start --replace --goal 'Replacement mission' --mode until-complete)
replacement_id=$(awk -F '\t' '$1=="id"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")
export CLARITY_MISSION_ID="$old_id"
export CLARITY_MISSION_CYCLE=0099
set +e
out=$(bash "$MISSION" checkpoint --project-complete no --ready-work yes --recoverable no 2>&1)
rc=$?
set -e
test "$rc" -eq 2
printf '%s\n' "$out" | grep -F "cycle belongs to mission $old_id, active mission is $replacement_id" >/dev/null
test "$(awk -F '\t' '$1=="status"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")" = active
unset CLARITY_MISSION_ID CLARITY_MISSION_CYCLE

out=$(bash "$MISSION" start --replace --goal 'Work until deadline' --mode until-complete-or-deadline --deadline-epoch 1)
printf '%s\n' "$out" | grep -F 'decision=STARTED' >/dev/null
set +e
out=$(bash "$MISSION" checkpoint --project-complete no --ready-work yes --recoverable no)
rc=$?
set -e
[ "$rc" -eq 30 ]
printf '%s\n' "$out" | grep -F 'decision=STOP_DEADLINE' >/dev/null

printf '%s\n' 'mission-control-test: ok'
