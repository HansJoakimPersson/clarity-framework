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

out=$("$MISSION" start --goal 'Build the whole app' --mode until-complete)
printf '%s\n' "$out" | grep -F 'decision=STARTED' >/dev/null

out=$("$MISSION" start --goal 'Build the whole app' --mode until-complete)
printf '%s\n' "$out" | grep -F 'decision=RESUME' >/dev/null

out=$("$MISSION" checkpoint --project-complete no --ready-work yes --recoverable no)
printf '%s\n' "$out" | grep -F 'decision=CONTINUE' >/dev/null

set +e
out=$("$MISSION" authorize --action architecture.material-change --impact architecture --reason 'Choose a boundary' --policy "$POLICY")
rc=$?
set -e
[ "$rc" -eq 10 ]
printf '%s\n' "$out" | grep -F 'decision=ORCHESTRATOR' >/dev/null
if find "$CLARITY_MISSION_DIR/gates" -name '*.tsv' -print -quit | grep -q .; then
  printf '%s\n' 'mission-control-test: orchestrator escalation created a human gate' >&2
  exit 1
fi

set +e
out=$("$MISSION" authorize --action production.deploy --impact production --reason 'Deploy to production' --policy "$POLICY")
rc=$?
set -e
[ "$rc" -eq 20 ]
printf '%s\n' "$out" | grep -F 'decision=HUMAN_GATE' >/dev/null
gate=$(printf '%s\n' "$out" | sed -n 's/.*gate_id=\([^[:space:]]*\).*/\1/p' | tail -1)
[ -n "$gate" ]
[ -r "$CLARITY_MISSION_DIR/gates/$gate.tsv" ]

set +e
out=$("$MISSION" checkpoint --project-complete no --ready-work yes --recoverable no --gate "$gate")
rc=$?
set -e
[ "$rc" -eq 20 ]
printf '%s\n' "$out" | grep -F 'decision=HUMAN_GATE' >/dev/null

out=$("$MISSION" resolve-gate --gate "$gate" --resolution approved)
printf '%s\n' "$out" | grep -F 'decision=GATE_RESOLVED' >/dev/null

out=$("$MISSION" checkpoint --project-complete no --ready-work yes --recoverable no)
printf '%s\n' "$out" | grep -F 'decision=CONTINUE' >/dev/null

out=$("$MISSION" checkpoint --project-complete yes --ready-work no --recoverable no)
printf '%s\n' "$out" | grep -F 'decision=COMPLETE' >/dev/null

out=$("$MISSION" start --replace --goal 'Work until deadline' --mode until-complete-or-deadline --deadline-epoch 1)
printf '%s\n' "$out" | grep -F 'decision=STARTED' >/dev/null
set +e
out=$("$MISSION" checkpoint --project-complete no --ready-work yes --recoverable no)
rc=$?
set -e
[ "$rc" -eq 30 ]
printf '%s\n' "$out" | grep -F 'decision=STOP_DEADLINE' >/dev/null

printf '%s\n' 'mission-control-test: ok'
