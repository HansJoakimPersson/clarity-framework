#!/usr/bin/env bash

set -euo pipefail

SKILLDIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
RUNNER="$SKILLDIR/scripts/mission-runner.sh"
MISSION="$SKILLDIR/scripts/mission-control.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM

mkdir -p "$TEST_ROOT/bin"

cat > "$TEST_ROOT/bin/fake-dispatch.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log=''
ledger=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --log) log="$2"; shift 2 ;;
    --ledger) ledger="$2"; shift 2 ;;
    --profile|--phase|--mode|--prompt-file|--job-id|--stall-timeout-seconds|--wall-timeout-seconds|--heartbeat-seconds|--model|--reasoning-effort)
      shift 2 ;;
    --background|--network) shift ;;
    *) printf 'fake-dispatch: unknown arg %s\n' "$1" >&2; exit 2 ;;
  esac
done

count_file=${CLARITY_TEST_CYCLE_COUNT_FILE:?}
count=$(cat "$count_file" 2>/dev/null || printf 0)
count=$((count + 1))
printf '%s\n' "$count" > "$count_file"
mkdir -p "$(dirname -- "$log")"
delay=${CLARITY_TEST_DELAY:-0}
[ "$delay" = 0 ] || sleep "$delay"
if [ "$count" -eq 1 ]; then
  printf 'Nu är den här delen klar. Det som återstår är nästa del.\n' > "$log"
else
  printf 'fake cycle %s complete\n' "$count" > "$log"
fi

exit_code=0
retryable=0
failure_class=none

mode=${CLARITY_TEST_MODE:-complete-on-second}
if [ "${CLARITY_MISSION_COMPLETION_AUDIT:-0}" = 1 ]; then
  case "$mode" in
    complete-on-second|retry-once)
      bash "${CLARITY_TEST_MISSION_CONTROL:?}" confirm-completion         --result complete --reason 'independent audit confirms mission scope' >/dev/null
      ;;
    audit-crash)
      bash "${CLARITY_TEST_MISSION_CONTROL:?}" confirm-completion         --result complete --reason 'audit claims complete before crashing' >/dev/null
      exit_code=7
      failure_class=unknown
      ;;
    premature-completion)
      if [ "$count" -eq 2 ]; then
        bash "${CLARITY_TEST_MISSION_CONTROL:?}" confirm-completion           --result continue --reason 'remaining application work exists' >/dev/null
      else
        bash "${CLARITY_TEST_MISSION_CONTROL:?}" confirm-completion           --result complete --reason 'remaining application work is now complete' >/dev/null
      fi
      ;;
    completion-crash|signal-stop)
      printf 'fake-dispatch: completion audit must not run for mode %s\n' "$mode" >&2
      exit 2
      ;;
    *)
      printf 'fake-dispatch: unexpected completion audit for mode %s\n' "$mode" >&2
      exit 2
      ;;
  esac
else
  case "$mode" in
    complete-on-second)
      if [ "$count" -eq 1 ]; then
        printf 'cycle 1\n' >> progress.txt
        git add progress.txt
        git -c user.name=test -c user.email=test@example.invalid commit -m cycle-1 >/dev/null
      else
        bash "${CLARITY_TEST_MISSION_CONTROL:?}" checkpoint           --project-complete yes --ready-work no --recoverable no >/dev/null
      fi
      ;;
    premature-completion)
      if [ "$count" -eq 1 ]; then
        # Reproduce the real defect: a work cycle mistakes one local increment for the whole mission.
        bash "${CLARITY_TEST_MISSION_CONTROL:?}" checkpoint           --project-complete yes --ready-work no --recoverable no >/dev/null
      else
        printf 'remaining mission work\n' >> progress.txt
        git add progress.txt
        git -c user.name=test -c user.email=test@example.invalid commit -m remaining-work >/dev/null
        bash "${CLARITY_TEST_MISSION_CONTROL:?}" checkpoint           --project-complete yes --ready-work no --recoverable no >/dev/null
      fi
      ;;
    audit-crash)
      bash "${CLARITY_TEST_MISSION_CONTROL:?}" checkpoint           --project-complete yes --ready-work no --recoverable no >/dev/null
      ;;
    completion-crash)
      bash "${CLARITY_TEST_MISSION_CONTROL:?}" checkpoint           --project-complete yes --ready-work no --recoverable no >/dev/null
      exit_code=7
      failure_class=unknown
      ;;
    signal-stop)
      ;;
    stagnant)
      ;;
    retry-once)
      if [ "$count" -eq 1 ]; then
        exit_code=124
        retryable=1
        failure_class=timeout.stalled
      else
        printf 'cycle retry success\n' >> progress.txt
        git add progress.txt
        git -c user.name=test -c user.email=test@example.invalid commit -m cycle-retry >/dev/null
        bash "${CLARITY_TEST_MISSION_CONTROL:?}" checkpoint           --project-complete yes --ready-work no --recoverable no >/dev/null
      fi
      ;;
    *)
      printf 'fake-dispatch: bad CLARITY_TEST_MODE\n' >&2
      exit 2
      ;;
  esac
fi

printf 'job_id\tstatus\tphase\tprofile\tcli\trequested_model\teffective_model\treasoning_effort\trollout_budget_tokens\tattempts\tretryable\tfailure_class\tmodel_policy\tinput_tokens\tcached_input_tokens\tcache_write_input_tokens\toutput_tokens\treasoning_output_tokens\ttotal_tokens\texit_status\n' > "$ledger"
printf 'test\t%s\tfinalization\ttest\tcodex\tprofile-default\tprofile-default\tprofile-default\tunbounded\t1\t%s\t%s\tprofile-default\tunavailable\tunavailable\tunavailable\tunavailable\tunavailable\tunavailable\t%s\n' \
  "$([ "$exit_code" -eq 0 ] && printf passed || printf failed)" "$retryable" "$failure_class" "$exit_code" >> "$ledger"
if [ "$mode" = signal-stop ]; then
  (
    sleep 2
    printf '%s\n' "$exit_code" > "${log%.log}.exit"
  ) &
else
  printf '%s\n' "$exit_code" > "${log%.log}.exit"
fi
printf 'DISPATCH started log=%s\n' "$log"
EOF
chmod +x "$TEST_ROOT/bin/fake-dispatch.sh"

cat > "$TEST_ROOT/bin/fake-health.sh" <<'EOF'
#!/usr/bin/env sh
set -eu
log=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --log) log=$2; shift 2 ;;
    *) exit 2 ;;
  esac
done
exit_file=$(printf '%s' "$log" | sed 's/\.log$/.exit/')
if [ -r "$exit_file" ]; then
  printf 'DISPATCH_HEALTH\tstate=finished\texit=%s\treason=test\n' "$(cat "$exit_file")"
  exit 0
fi
printf 'DISPATCH_HEALTH\tstate=running\n'
exit 10
EOF
chmod +x "$TEST_ROOT/bin/fake-health.sh"

new_repo() {
  repo=$1
  mkdir -p "$repo"
  (
    cd "$repo"
    git init -q
    printf 'base\n' > README.md
    git add README.md
    git -c user.name=test -c user.email=test@example.invalid commit -m base >/dev/null
  )
}

# 1. A successful Codex task is only one cycle. The runner starts another task until mission state is complete.
REPO1="$TEST_ROOT/repo1"
new_repo "$REPO1"
export CLARITY_MISSION_DIR="$TEST_ROOT/state1"
export CLARITY_DISPATCH_SH="$TEST_ROOT/bin/fake-dispatch.sh"
export CLARITY_HEALTH_SH="$TEST_ROOT/bin/fake-health.sh"
export CLARITY_TEST_CYCLE_COUNT_FILE="$TEST_ROOT/cycles1"
export CLARITY_TEST_MISSION_CONTROL="$MISSION"
export CLARITY_TEST_MODE=complete-on-second
out=$(
  cd "$REPO1"
  bash "$RUNNER" --goal 'Build the whole app' --max-cycles 5 --max-stagnant-cycles 2 --poll-seconds 1
)
test "$(cat "$TEST_ROOT/cycles1")" = 3
printf '%s\n' "$out" | grep -F 'decision=CONTINUE cycle=1' >/dev/null
printf '%s\n' "$out" | grep -F 'decision=COMPLETE' >/dev/null
test "$(awk -F '\t' '$1=="status"{print $2}' "$CLARITY_MISSION_DIR/runner.tsv")" = completed

# 2. Repeated successful-but-empty cycles are bounded instead of looping forever.
REPO2="$TEST_ROOT/repo2"
new_repo "$REPO2"
export CLARITY_MISSION_DIR="$TEST_ROOT/state2"
export CLARITY_TEST_CYCLE_COUNT_FILE="$TEST_ROOT/cycles2"
export CLARITY_TEST_MODE=stagnant
set +e
out=$(
  cd "$REPO2"
  bash "$RUNNER" --goal 'Do all remaining work' --max-cycles 10 --max-stagnant-cycles 2 --poll-seconds 1
)
rc=$?
set -e
test "$rc" -eq 32
test "$(cat "$TEST_ROOT/cycles2")" = 2
printf '%s\n' "$out" | grep -F 'decision=STOP_STAGNATED' >/dev/null

# 3. A retryable outer-cycle timeout gets one fresh Codex cycle; the mission can then complete.
REPO3="$TEST_ROOT/repo3"
new_repo "$REPO3"
export CLARITY_MISSION_DIR="$TEST_ROOT/state3"
export CLARITY_TEST_CYCLE_COUNT_FILE="$TEST_ROOT/cycles3"
export CLARITY_TEST_MODE=retry-once
out=$(
  cd "$REPO3"
  bash "$RUNNER" --goal 'Build release scope' --max-cycles 5 --max-cycle-restarts 1 --poll-seconds 1
)
test "$(cat "$TEST_ROOT/cycles3")" = 3
printf '%s\n' "$out" | grep -F 'decision=RETRY_CYCLE failure=timeout.stalled restart=1/1' >/dev/null
printf '%s\n' "$out" | grep -F 'decision=COMPLETE' >/dev/null

# 4. An already-open Reserved gate prevents a new Codex cycle from launching.
REPO4="$TEST_ROOT/repo4"
new_repo "$REPO4"
export CLARITY_MISSION_DIR="$TEST_ROOT/state4"
export CLARITY_TEST_CYCLE_COUNT_FILE="$TEST_ROOT/cycles4"
export CLARITY_TEST_MODE=complete-on-second
(
  cd "$REPO4"
  bash "$MISSION" start --goal 'Deploy when ready' --mode until-complete >/dev/null
)
mkdir -p "$CLARITY_MISSION_DIR/gates"
mission4=$(awk -F '\t' '$1=="id"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")
cat > "$CLARITY_MISSION_DIR/gates/HG-test.tsv" <<EOF
id	HG-test
status	open
action	production.deploy
impact	production
mission_id	$mission4
EOF
set +e
out=$(
  cd "$REPO4"
  bash "$RUNNER" --max-cycles 5 --poll-seconds 1
)
rc=$?
set -e
test "$rc" -eq 20
test ! -e "$TEST_ROOT/cycles4"
printf '%s\n' "$out" | grep -F 'decision=HUMAN_GATE gate_id=HG-test' >/dev/null

# 5. --ensure-running is idempotent only when a live runner lock owns the active mission.
export CLARITY_MISSION_DIR="$TEST_ROOT/state5"
bash "$MISSION" start --goal 'Mission five' --mode until-complete >/dev/null
mission5=$(awk -F '\t' '$1=="id"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")
mkdir -p "$CLARITY_MISSION_DIR/runner.lock"
sleep 30 &
fake_runner_pid=$!
printf '%s\n' "$fake_runner_pid" > "$CLARITY_MISSION_DIR/runner.lock/pid"
printf 'mission_id\t%s\n' "$mission5" > "$CLARITY_MISSION_DIR/runner.lock/owner.tsv"
{
  printf 'pid\t%s\n' "$fake_runner_pid"
  printf 'mission_id\t%s\n' "$mission5"
  printf 'ready_epoch\t1\n'
} > "$CLARITY_MISSION_DIR/runner.lock/ready.tsv"
out=$(bash "$RUNNER" --ensure-running)
printf '%s\n' "$out" | grep -F 'decision=ALREADY_RUNNING' >/dev/null

# The same live PID cannot claim a different active mission.
bash "$MISSION" start --replace --goal 'Mission five replacement' --mode until-complete >/dev/null
set +e
out=$(bash "$RUNNER" --ensure-running 2>&1)
rc=$?
set -e
test "$rc" -eq 37
printf '%s\n' "$out" | grep -F 'decision=OWNER_MISMATCH' >/dev/null
kill "$fake_runner_pid" 2>/dev/null || true
wait "$fake_runner_pid" 2>/dev/null || true
rm -rf "$CLARITY_MISSION_DIR"

# 6. A premature completion claim is rejected by an independent completion audit.
REPO6A="$TEST_ROOT/repo6a"
new_repo "$REPO6A"
export CLARITY_MISSION_DIR="$TEST_ROOT/state6a"
export CLARITY_TEST_CYCLE_COUNT_FILE="$TEST_ROOT/cycles6a"
export CLARITY_TEST_MODE=premature-completion
out=$(
  cd "$REPO6A"
  bash "$RUNNER" --goal 'Build the entire application, not just one increment'     --max-cycles 8 --max-stagnant-cycles 2 --poll-seconds 1
)
test "$(cat "$TEST_ROOT/cycles6a")" = 4
printf '%s\n' "$out" | grep -F 'kind=completion-audit' >/dev/null
printf '%s\n' "$out" | grep -F 'decision=COMPLETE' >/dev/null
grep -F 'remaining mission work' "$REPO6A/progress.txt" >/dev/null

# 7. --ensure-running starts a detached owner and waits until the runner lock proves it is alive.
REPO6="$TEST_ROOT/repo6"
new_repo "$REPO6"
export CLARITY_MISSION_DIR="$TEST_ROOT/state6"
export CLARITY_TEST_CYCLE_COUNT_FILE="$TEST_ROOT/cycles6"
export CLARITY_TEST_MODE=stagnant
export CLARITY_TEST_DELAY=2
set +e
out=$(
  cd "$REPO6"
  bash "$RUNNER" --goal 'Build all remaining parts' --ensure-running --max-cycles 1 --poll-seconds 1
)
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  printf 'mission-runner-test: ensure-running failed rc=%s\n' "$rc" >&2
  cat "$CLARITY_MISSION_DIR/mission-runner.log" >&2 2>/dev/null || true
  exit "$rc"
fi
printf '%s\n' "$out" | grep -F 'decision=RUNNING' >/dev/null
runner_pid=$(printf '%s\n' "$out" | sed -n 's/.*decision=RUNNING pid=\([0-9][0-9]*\).*/\1/p')
test -n "$runner_pid"
attempt=0
while kill -0 "$runner_pid" 2>/dev/null && [ "$attempt" -lt 100 ]; do
  attempt=$((attempt + 1))
  sleep 0.05
done
unset CLARITY_TEST_DELAY

# 8. A completion audit that records "complete" but exits non-zero cannot finalize the mission.
REPO8="$TEST_ROOT/repo8"
new_repo "$REPO8"
export CLARITY_MISSION_DIR="$TEST_ROOT/state8"
export CLARITY_TEST_CYCLE_COUNT_FILE="$TEST_ROOT/cycles8"
export CLARITY_TEST_MODE=audit-crash
set +e
out=$(
  cd "$REPO8"
  bash "$RUNNER" --goal 'Audit must finish cleanly' --max-cycles 4 --poll-seconds 1
)
rc=$?
set -e
test "$rc" -eq 33
test "$(awk -F '\t' '$1=="status"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")" = completion-pending
printf '%s\n' "$out" | grep -F 'decision=STOP_CYCLE_FAILURE' >/dev/null

# 9. An open gate from a replaced mission is ignored by the new mission.
REPO9="$TEST_ROOT/repo9"
new_repo "$REPO9"
export CLARITY_MISSION_DIR="$TEST_ROOT/state9"
export CLARITY_TEST_CYCLE_COUNT_FILE="$TEST_ROOT/cycles9"
export CLARITY_TEST_MODE=stagnant
bash "$MISSION" start --goal 'Old mission' --mode until-complete >/dev/null
old_mission=$(awk -F '\t' '$1=="id"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")
mkdir -p "$CLARITY_MISSION_DIR/gates"
cat > "$CLARITY_MISSION_DIR/gates/HG-old.tsv" <<EOF
id	HG-old
status	open
action	production.deploy
impact	production
mission_id	$old_mission
EOF
bash "$MISSION" start --replace --goal 'New mission' --mode until-complete >/dev/null
set +e
out=$(
  cd "$REPO9"
  bash "$RUNNER" --max-cycles 1 --poll-seconds 1
)
rc=$?
set -e
test "$rc" -eq 31
test "$(cat "$TEST_ROOT/cycles9")" = 1
if printf '%s\n' "$out" | grep -F 'decision=HUMAN_GATE' >/dev/null; then
  printf '%s\n' 'mission-runner-test: stale gate stopped replacement mission' >&2
  exit 1
fi


# 10. A work cycle that requests completion and then fails cannot advance the mission.
REPO10="$TEST_ROOT/repo10"
new_repo "$REPO10"
export CLARITY_MISSION_DIR="$TEST_ROOT/state10"
export CLARITY_TEST_CYCLE_COUNT_FILE="$TEST_ROOT/cycles10"
export CLARITY_TEST_MODE=completion-crash
set +e
out=$(
  cd "$REPO10"
  bash "$RUNNER" --goal 'Failed work must not request completion' --max-cycles 4 --poll-seconds 1
)
rc=$?
set -e
test "$rc" -eq 33
test "$(awk -F '\t' '$1=="status"{print $2}' "$CLARITY_MISSION_DIR/active.tsv")" = active
if awk -F '\t' '$1=="completion_requested_by_cycle"{found=1} END{exit !found}' "$CLARITY_MISSION_DIR/active.tsv"; then
  printf '%s\n' 'mission-runner-test: failed work left a completion request behind' >&2
  exit 1
fi
printf '%s\n' "$out" | grep -F 'decision=STOP_CYCLE_FAILURE' >/dev/null

# 11. TERM requests a graceful stop without dropping the ownership lock while a cycle is still alive.
REPO11="$TEST_ROOT/repo11"
new_repo "$REPO11"
export CLARITY_MISSION_DIR="$TEST_ROOT/state11"
export CLARITY_TEST_CYCLE_COUNT_FILE="$TEST_ROOT/cycles11"
export CLARITY_TEST_MODE=signal-stop
signal_out="$TEST_ROOT/signal.out"
set +e
(
  cd "$REPO11"
  bash "$RUNNER" --goal 'Signal-safe mission ownership' --max-cycles 4 --poll-seconds 1
) >"$signal_out" 2>&1 &
signal_launcher=$!
set -e
attempt=0
while [ ! -r "$CLARITY_MISSION_DIR/runner.lock/pid" ] && [ "$attempt" -lt 100 ]; do
  attempt=$((attempt + 1))
  sleep 0.05
done
test -r "$CLARITY_MISSION_DIR/runner.lock/pid"
signal_runner=$(cat "$CLARITY_MISSION_DIR/runner.lock/pid")
kill -TERM "$signal_runner"
sleep 0.2
test -d "$CLARITY_MISSION_DIR/runner.lock"
kill -0 "$signal_runner" 2>/dev/null
set +e
wait "$signal_launcher"
rc=$?
set -e
test "$rc" -eq 143
test ! -d "$CLARITY_MISSION_DIR/runner.lock"
grep -F 'decision=STOP_SIGNAL signal=TERM' "$signal_out" >/dev/null

printf '%s\n' 'mission-runner-test: ok'
