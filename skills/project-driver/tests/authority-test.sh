#!/usr/bin/env bash

set -euo pipefail

SKILLDIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
AUTHORITY="$SKILLDIR/scripts/authority.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM

POLICY="$TEST_ROOT/00-ai-context.md"
cat > "$POLICY" <<'EOF'
# AI Context

<!-- clarity-authority:start -->
mode=autonomous
human_gate=reserved-only
delegate=production.release
reserve=custom.danger
unknown_reversible=delegated
unknown_external=escalation
<!-- clarity-authority:end -->
EOF

out=$(bash "$AUTHORITY" --action git.commit --impact reversible-local --policy "$POLICY")
printf '%s\n' "$out" | grep -F 'decision=DELEGATED' >/dev/null

set +e
out=$(bash "$AUTHORITY" --action architecture.material-change --impact architecture --policy "$POLICY")
rc=$?
set -e
[ "$rc" -eq 10 ]
printf '%s\n' "$out" | grep -F 'decision=ORCHESTRATOR' >/dev/null

out=$(bash "$AUTHORITY" --action production.release --impact production --policy "$POLICY")
printf '%s\n' "$out" | grep -F 'decision=DELEGATED' >/dev/null
printf '%s\n' "$out" | grep -F 'source=policy' >/dev/null

set +e
out=$(bash "$AUTHORITY" --action production.deploy --impact production --policy "$POLICY")
rc=$?
set -e
[ "$rc" -eq 20 ]
printf '%s\n' "$out" | grep -F 'decision=HUMAN_GATE' >/dev/null

set +e
out=$(bash "$AUTHORITY" --action custom.danger --impact reversible-local --policy "$POLICY")
rc=$?
set -e
[ "$rc" -eq 20 ]
printf '%s\n' "$out" | grep -F 'source=policy' >/dev/null

out=$(bash "$AUTHORITY" --action local.unknown --impact reversible-local --policy "$POLICY")
printf '%s\n' "$out" | grep -F 'decision=DELEGATED' >/dev/null

set +e
out=$(bash "$AUTHORITY" --action external.unknown --impact external-reversible --policy "$POLICY")
rc=$?
set -e
[ "$rc" -eq 10 ]
printf '%s\n' "$out" | grep -F 'decision=ORCHESTRATOR' >/dev/null

printf '%s\n' 'authority-test: ok'
