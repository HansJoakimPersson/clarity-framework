#!/usr/bin/env bash

# Deterministic outer loop for long Clarity missions.
# A Codex exec task is disposable: its final response never determines mission completion.
# Persistent mission state decides whether another fresh Codex cycle starts.

set -euo pipefail

die() { printf '%s\n' "$1" >&2; exit 2; }

ORIGINAL_ARGS=("$@")
SKILLDIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
MISSION="$SKILLDIR/scripts/mission-control.sh"
PROMPT_FILE="$SKILLDIR/prompts/mission-cycle.txt"
AUDIT_PROMPT_FILE="$SKILLDIR/prompts/mission-completion-audit.txt"
STATE_ROOT=${CLARITY_MISSION_DIR:-docs/plans/.runs/project-driver-mission}
STATE="$STATE_ROOT/active.tsv"
GOAL_FILE="$STATE_ROOT/goal.txt"
GATES="$STATE_ROOT/gates"
RUNNER_STATE="$STATE_ROOT/runner.tsv"
RUNNER_DIR="$STATE_ROOT/runner"
LOCK_DIR="$STATE_ROOT/runner.lock"

GOAL=''
MODE='until-complete'
DEADLINE=''
PROFILE=${CLARITY_ORCHESTRATOR_PROFILE:-cli:codex}
MODEL=${CLARITY_ORCHESTRATOR_MODEL:-}
REASONING_EFFORT=${CLARITY_ORCHESTRATOR_REASONING_EFFORT:-}
MAX_CYCLES=${CLARITY_MISSION_MAX_CYCLES:-100}
MAX_STAGNANT_CYCLES=${CLARITY_MISSION_MAX_STAGNANT_CYCLES:-2}
MAX_CYCLE_RESTARTS=${CLARITY_MISSION_MAX_CYCLE_RESTARTS:-1}
STALL_SECONDS=${CLARITY_MISSION_CYCLE_STALL_SECONDS:-1800}
WALL_SECONDS=${CLARITY_MISSION_CYCLE_WALL_SECONDS:-7200}
HEARTBEAT_SECONDS=${CLARITY_MISSION_HEARTBEAT_SECONDS:-30}
POLL_SECONDS=${CLARITY_MISSION_POLL_SECONDS:-20}
HEALTH_GRACE_SECONDS=${CLARITY_MISSION_HEALTH_GRACE_SECONDS:-10}
NETWORK=0
BACKGROUND=0
ENSURE_RUNNING=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --goal) GOAL="${2:-}"; shift 2 ;;
    --mode) MODE="${2:-}"; shift 2 ;;
    --deadline-epoch) DEADLINE="${2:-}"; shift 2 ;;
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --reasoning-effort) REASONING_EFFORT="${2:-}"; shift 2 ;;
    --max-cycles) MAX_CYCLES="${2:-}"; shift 2 ;;
    --max-stagnant-cycles) MAX_STAGNANT_CYCLES="${2:-}"; shift 2 ;;
    --max-cycle-restarts) MAX_CYCLE_RESTARTS="${2:-}"; shift 2 ;;
    --cycle-stall-seconds) STALL_SECONDS="${2:-}"; shift 2 ;;
    --cycle-wall-seconds) WALL_SECONDS="${2:-}"; shift 2 ;;
    --heartbeat-seconds) HEARTBEAT_SECONDS="${2:-}"; shift 2 ;;
    --poll-seconds) POLL_SECONDS="${2:-}"; shift 2 ;;
    --network) NETWORK=1; shift ;;
    --background) BACKGROUND=1; shift ;;
    --ensure-running) ENSURE_RUNNING=1; BACKGROUND=1; shift ;;
    *) die "mission-runner.sh: unknown argument '$1'" ;;
  esac
done

case "$MODE" in until-complete|until-deadline|until-complete-or-deadline) ;; *) die "mission-runner.sh: invalid --mode '$MODE'" ;; esac
for item in   "max-cycles:$MAX_CYCLES"   "max-stagnant-cycles:$MAX_STAGNANT_CYCLES"   "max-cycle-restarts:$MAX_CYCLE_RESTARTS"   "cycle-stall-seconds:$STALL_SECONDS"   "cycle-wall-seconds:$WALL_SECONDS"   "heartbeat-seconds:$HEARTBEAT_SECONDS"   "poll-seconds:$POLL_SECONDS"
do
  name=${item%%:*}; value=${item#*:}
  case "$value" in ''|*[!0-9]*) die "mission-runner.sh: $name must be a non-negative integer (got '$value')" ;; esac
done
[ "$MAX_CYCLES" -gt 0 ] || die 'mission-runner.sh: --max-cycles must be > 0'
[ "$MAX_STAGNANT_CYCLES" -gt 0 ] || die 'mission-runner.sh: --max-stagnant-cycles must be > 0'
[ "$STALL_SECONDS" -gt 0 ] || die 'mission-runner.sh: --cycle-stall-seconds must be > 0'
[ "$WALL_SECONDS" -gt 0 ] || die 'mission-runner.sh: --cycle-wall-seconds must be > 0'
[ "$HEARTBEAT_SECONDS" -gt 0 ] || die 'mission-runner.sh: --heartbeat-seconds must be > 0'
[ "$POLL_SECONDS" -gt 0 ] || die 'mission-runner.sh: --poll-seconds must be > 0'
[ "$STALL_SECONDS" -ge "$HEARTBEAT_SECONDS" ] || die 'mission-runner.sh: stall ceiling must be >= heartbeat'
[ "$WALL_SECONDS" -ge "$HEARTBEAT_SECONDS" ] || die 'mission-runner.sh: wall ceiling must be >= heartbeat'
if [ "$MODE" != until-complete ]; then
  case "$DEADLINE" in ''|*[!0-9]*) die 'mission-runner.sh: deadline mode requires --deadline-epoch' ;; esac
fi

find_plan_skill() {
  if [ -n "${CLARITY_DISPATCH_SH:-}" ]; then
    DISPATCH=$CLARITY_DISPATCH_SH
    HEALTH=${CLARITY_HEALTH_SH:-$(dirname -- "$DISPATCH")/dispatch-health.sh}
  elif [ -f .agents/skills/plan-driven-build/dispatch.sh ]; then
    DISPATCH=.agents/skills/plan-driven-build/dispatch.sh
    HEALTH=.agents/skills/plan-driven-build/dispatch-health.sh
  elif [ -f .claude/skills/plan-driven-build/dispatch.sh ]; then
    DISPATCH=.claude/skills/plan-driven-build/dispatch.sh
    HEALTH=.claude/skills/plan-driven-build/dispatch-health.sh
  else
    die 'mission-runner.sh: plan-driven-build dispatcher is not installed'
  fi
  [ -f "$DISPATCH" ] || die "mission-runner.sh: dispatcher not found: $DISPATCH"
  [ -f "$HEALTH" ] || die "mission-runner.sh: health probe not found: $HEALTH"
}

state_get() {
  key=$1 file=$2
  [ -r "$file" ] || return 1
  awk -F '\t' -v k="$key" '$1 == k { print substr($0, index($0, "\t") + 1); exit }' "$file"
}

runner_put() {
  key=$1 value=$2
  mkdir -p -- "$STATE_ROOT"
  touch "$RUNNER_STATE"
  tmp="$RUNNER_STATE.tmp.$$"
  awk -F '\t' -v k="$key" '$1 != k { print }' "$RUNNER_STATE" > "$tmp"
  printf '%s\t%s\n' "$key" "$value" >> "$tmp"
  mv -- "$tmp" "$RUNNER_STATE"
}

open_gate() {
  [ -d "$GATES" ] || return 1
  current_mission=$(mission_id)
  [ "$current_mission" != none ] || return 1
  for gate_file in "$GATES"/*.tsv; do
    [ -r "$gate_file" ] || continue
    gate_mission=$(state_get mission_id "$gate_file" || true)
    [ "$gate_mission" = "$current_mission" ] || continue
    status=$(state_get status "$gate_file" || true)
    if [ "$status" = open ]; then
      basename "$gate_file" .tsv
      return 0
    fi
  done
  return 1
}

fingerprint() {
  head='no-git'
  work='no-git'
  if git rev-parse --git-dir >/dev/null 2>&1; then
    head=$(git rev-parse HEAD 2>/dev/null || printf no-head)
    work=$(git status --porcelain=v1 -uall 2>/dev/null | cksum | awk '{print $1 ":" $2}')
  fi
  mission='no-state'
  [ ! -r "$STATE" ] || mission=$(cksum < "$STATE" | awk '{print $1 ":" $2}')
  gate='none'
  gate=$(open_gate 2>/dev/null || printf none)
  printf '%s|%s|%s|%s\n' "$head" "$work" "$mission" "$gate"
}

mission_status() {
  state_get status "$STATE" 2>/dev/null || printf none
}

mission_id() {
  state_get id "$STATE" 2>/dev/null || printf none
}

deadline_reached() {
  mode=$(state_get mode "$STATE" 2>/dev/null || printf until-complete)
  deadline=$(state_get deadline_epoch "$STATE" 2>/dev/null || true)
  [ "$mode" != until-complete ] || return 1
  case "$deadline" in ''|*[!0-9]*) return 1 ;; esac
  [ "$(date +%s)" -ge "$deadline" ]
}

ledger_value() {
  file=$1 key=$2
  [ -r "$file" ] || return 1
  awk -F '\t' -v wanted="$key" '
    NR == 1 {
      for (i = 1; i <= NF; i++) if ($i == wanted) col = i
      next
    }
    NR == 2 && col { print $col; exit }
  ' "$file"
}

live_lock_pid_any() {
  [ -r "$LOCK_DIR/pid" ] || return 1
  pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || true)
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$pid" 2>/dev/null || return 1
  printf '%s\n' "$pid"
}

live_runner_pid() {
  [ -r "$LOCK_DIR/ready.tsv" ] || return 1
  pid=$(state_get pid "$LOCK_DIR/ready.tsv" 2>/dev/null || true)
  lock_mission=$(state_get mission_id "$LOCK_DIR/ready.tsv" 2>/dev/null || true)
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$pid" 2>/dev/null || return 1
  current_mission=$(mission_id)
  [ "$current_mission" != none ] || return 1
  [ "$lock_mission" = "$current_mission" ] || return 1
  printf '%s\n' "$pid"
}

if [ "$ENSURE_RUNNING" -eq 1 ]; then
  mkdir -p -- "$STATE_ROOT"
  if pid=$(live_runner_pid); then
    printf 'MISSION_RUNNER decision=ALREADY_RUNNING pid=%s mission_id=%s log=%s\n'       "$pid" "$(mission_id)" "$STATE_ROOT/mission-runner.log"
    exit 0
  fi

  if pid=$(live_lock_pid_any); then
    lock_mission=$(state_get mission_id "$LOCK_DIR/owner.tsv" 2>/dev/null || printf unknown)
    active_mission=$(mission_id)
    if [ "$lock_mission" != "$active_mission" ]; then
      printf 'MISSION_RUNNER decision=OWNER_MISMATCH pid=%s lock_mission=%s active_mission=%s\n'         "$pid" "$lock_mission" "$active_mission" >&2
      exit 37
    fi

    # A same-mission process may have acquired the lock just before atomically publishing ready.tsv.
    attempt=0
    while [ "$attempt" -lt 100 ]; do
      attempt=$((attempt + 1))
      if ready_pid=$(live_runner_pid); then
        printf 'MISSION_RUNNER decision=ALREADY_RUNNING pid=%s mission_id=%s log=%s\n'           "$ready_pid" "$active_mission" "$STATE_ROOT/mission-runner.log"
        exit 0
      fi
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.1
    done
    printf 'MISSION_RUNNER decision=OWNER_UNREADY pid=%s mission_id=%s\n'       "$pid" "$active_mission" >&2
    exit 36
  fi
fi

if [ "$BACKGROUND" -eq 1 ]; then
  mkdir -p -- "$STATE_ROOT"
  bg_log="$STATE_ROOT/mission-runner.log"
  filtered=()
  for arg in "${ORIGINAL_ARGS[@]}"; do
    case "$arg" in
      --background|--ensure-running) continue ;;
    esac
    filtered+=("$arg")
  done
  nohup bash "$0" "${filtered[@]}" > "$bg_log" 2>&1 < /dev/null &
  bg_pid=$!

  if [ "$ENSURE_RUNNING" -eq 1 ]; then
    attempt=0
    while [ "$attempt" -lt 100 ]; do
      attempt=$((attempt + 1))
      if pid=$(live_runner_pid); then
        printf 'MISSION_RUNNER decision=RUNNING pid=%s launcher_pid=%s log=%s\n' "$pid" "$bg_pid" "$bg_log"
        exit 0
      fi
      sleep 0.1
    done
    printf 'MISSION_RUNNER decision=START_FAILED launcher_pid=%s log=%s\n' "$bg_pid" "$bg_log" >&2
    exit 36
  fi

  printf 'MISSION_RUNNER started pid=%s log=%s\n' "$bg_pid" "$bg_log"
  exit 0
fi

find_plan_skill
mkdir -p -- "$STATE_ROOT" "$RUNNER_DIR"

if [ -n "$GOAL" ]; then
  start_args=(start --goal "$GOAL" --mode "$MODE")
  [ -z "$DEADLINE" ] || start_args+=(--deadline-epoch "$DEADLINE")
  bash "$MISSION" "${start_args[@]}" >/dev/null
elif [ ! -r "$STATE" ]; then
  die 'mission-runner.sh: no active mission; provide --goal to start one'
fi

status=$(mission_status)
case "$status" in
  active|completion-pending) ;;
  completed)
    printf 'MISSION_RUNNER decision=COMPLETE mission_id=%s\n' "$(mission_id)"
    exit 0
    ;;
  blocked|deadline-reached)
    printf 'MISSION_RUNNER decision=STOP status=%s mission_id=%s\n' "$status" "$(mission_id)"
    exit 30
    ;;
  *) die "mission-runner.sh: mission is not runnable (status=$status)" ;;
esac

current_id=$(mission_id)
saved_id=$(state_get mission_id "$RUNNER_STATE" 2>/dev/null || true)
if [ "$saved_id" != "$current_id" ]; then
  {
    printf 'mission_id\t%s\n' "$current_id"
    printf 'status\trunning\n'
    printf 'cycle_count\t0\n'
    printf 'stagnant_count\t0\n'
    printf 'cycle_restart_count\t0\n'
  } > "$RUNNER_STATE"
fi

if mkdir "$LOCK_DIR" 2>/dev/null; then
  :
else
  lock_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || true)
  lock_mission=$(state_get mission_id "$LOCK_DIR/owner.tsv" 2>/dev/null || printf unknown)
  if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
    die "mission-runner.sh: another runner is active (pid=$lock_pid mission=$lock_mission)"
  fi
  rm -rf -- "$LOCK_DIR"
  mkdir "$LOCK_DIR"
fi
printf '%s\n' "$BASHPID" > "$LOCK_DIR/pid"
{
  printf 'mission_id\t%s\n' "$current_id"
  printf 'started_epoch\t%s\n' "$(date +%s)"
} > "$LOCK_DIR/owner.tsv"
ready_tmp="$LOCK_DIR/ready.tsv.tmp.$BASHPID"
{
  printf 'pid\t%s\n' "$BASHPID"
  printf 'mission_id\t%s\n' "$current_id"
  printf 'ready_epoch\t%s\n' "$(date +%s)"
} > "$ready_tmp"
mv -- "$ready_tmp" "$LOCK_DIR/ready.tsv"

cleanup() {
  owner_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || true)
  owner_mission=$(state_get mission_id "$LOCK_DIR/owner.tsv" 2>/dev/null || true)
  if [ "$owner_pid" = "$BASHPID" ] && [ "$owner_mission" = "$current_id" ]; then
    rm -rf -- "$LOCK_DIR"
  fi
}
trap cleanup EXIT HUP INT TERM

cycle_count=$(state_get cycle_count "$RUNNER_STATE" 2>/dev/null || printf 0)
stagnant_count=$(state_get stagnant_count "$RUNNER_STATE" 2>/dev/null || printf 0)
cycle_restart_count=$(state_get cycle_restart_count "$RUNNER_STATE" 2>/dev/null || printf 0)

while :; do
  observed_mission=$(mission_id)
  if [ "$observed_mission" != "$current_id" ]; then
    printf 'MISSION_RUNNER decision=STOP_REPLACED old_mission=%s active_mission=%s\n'       "$current_id" "$observed_mission"
    exit 39
  fi

  status=$(mission_status)
  case "$status" in
    completed)
      runner_put status completed
      printf 'MISSION_RUNNER decision=COMPLETE mission_id=%s cycles=%s\n' "$current_id" "$cycle_count"
      exit 0
      ;;
    blocked|deadline-reached)
      runner_put status "$status"
      printf 'MISSION_RUNNER decision=STOP status=%s cycles=%s\n' "$status" "$cycle_count"
      exit 30
      ;;
    active|completion-pending) ;;
    *)
      runner_put status invalid-mission-state
      printf 'MISSION_RUNNER decision=STOP_INVALID status=%s\n' "$status"
      exit 35
      ;;
  esac

  if gate=$(open_gate); then
    runner_put status human-gate
    runner_put open_gate "$gate"
    printf 'MISSION_RUNNER decision=HUMAN_GATE gate_id=%s cycles=%s\n' "$gate" "$cycle_count"
    exit 20
  fi

  if deadline_reached; then
    set +e
    bash "$MISSION" checkpoint --project-complete no --ready-work yes --recoverable no >/dev/null
    rc=$?
    set -e
    runner_put status deadline-reached
    printf 'MISSION_RUNNER decision=STOP_DEADLINE cycles=%s\n' "$cycle_count"
    exit 30
  fi

  if [ "$cycle_count" -ge "$MAX_CYCLES" ]; then
    runner_put status max-cycles
    printf 'MISSION_RUNNER decision=STOP_MAX_CYCLES cycles=%s max=%s\n' "$cycle_count" "$MAX_CYCLES"
    exit 31
  fi

  before=$(fingerprint)
  cycle_kind=work
  cycle_prompt="$PROMPT_FILE"
  if [ "$status" = completion-pending ]; then
    cycle_kind=completion-audit
    cycle_prompt="$AUDIT_PROMPT_FILE"
  fi

  cycle_count=$((cycle_count + 1))
  runner_put cycle_count "$cycle_count"
  runner_put status running
  runner_put last_cycle_kind "$cycle_kind"
  runner_put last_cycle_started_epoch "$(date +%s)"

  cycle_id=$(printf '%04d' "$cycle_count")
  log="$RUNNER_DIR/cycle-$cycle_id.log"
  ledger="$RUNNER_DIR/cycle-$cycle_id.ledger"
  rm -f "$log" "$ledger"

  args=(
    --profile "$PROFILE"
    --phase finalization
    --mode workspace-write
    --background
    --prompt-file "$cycle_prompt"
    --log "$log"
    --ledger "$ledger"
    --job-id "mission-$current_id-$cycle_kind-$cycle_id"
    --stall-timeout-seconds "$STALL_SECONDS"
    --wall-timeout-seconds "$WALL_SECONDS"
    --heartbeat-seconds "$HEARTBEAT_SECONDS"
  )
  [ -z "$MODEL" ] || args+=(--model "$MODEL")
  [ -z "$REASONING_EFFORT" ] || args+=(--reasoning-effort "$REASONING_EFFORT")
  [ "$NETWORK" -eq 0 ] || args+=(--network)

  export CLARITY_MISSION_CYCLE="$cycle_id"
  export CLARITY_MISSION_ID="$current_id"
  export CLARITY_MISSION_CYCLE_KIND="$cycle_kind"
  if [ "$cycle_kind" = completion-audit ]; then
    export CLARITY_MISSION_COMPLETION_AUDIT=1
  else
    unset CLARITY_MISSION_COMPLETION_AUDIT 2>/dev/null || true
  fi
  summary=$(bash "$DISPATCH" "${args[@]}")
  unset CLARITY_MISSION_CYCLE CLARITY_MISSION_ID CLARITY_MISSION_CYCLE_KIND
  unset CLARITY_MISSION_COMPLETION_AUDIT 2>/dev/null || true
  printf 'MISSION_RUNNER cycle=%s kind=%s dispatch=%s\n' "$cycle_count" "$cycle_kind" "$summary"

  health_started=$(date +%s)
  while :; do
    set +e
    health=$(sh "$HEALTH" --log "$log")
    health_rc=$?
    set -e
    case "$health_rc" in
      0)
        printf 'MISSION_RUNNER cycle=%s health=%s\n' "$cycle_count" "$health"
        break
        ;;
      10)
        sleep "$POLL_SECONDS"
        ;;
      20)
        runner_put status stale-supervisor
        printf 'MISSION_RUNNER decision=STOP_STALE_SUPERVISOR cycle=%s health=%s\n' "$cycle_count" "$health"
        exit 34
        ;;
      30)
        if [ $(( $(date +%s) - health_started )) -lt "$HEALTH_GRACE_SECONDS" ]; then
          sleep 1
        else
          runner_put status lost-supervisor
          printf 'MISSION_RUNNER decision=STOP_LOST_SUPERVISOR cycle=%s health=%s\n' "$cycle_count" "$health"
          exit 34
        fi
        ;;
      *)
        runner_put status health-probe-error
        printf 'MISSION_RUNNER decision=STOP_HEALTH_ERROR cycle=%s rc=%s\n' "$cycle_count" "$health_rc"
        exit 34
        ;;
    esac
  done

  exit_file="${log%.log}.exit"
  [ -r "$exit_file" ] || { runner_put status missing-sentinel; printf 'MISSION_RUNNER decision=STOP_MISSING_SENTINEL cycle=%s\n' "$cycle_count"; exit 34; }
  cycle_exit=$(cat "$exit_file")
  runner_put last_cycle_exit "$cycle_exit"
  runner_put last_cycle_finished_epoch "$(date +%s)"

  status=$(mission_status)
  if gate=$(open_gate); then
    runner_put status human-gate
    runner_put open_gate "$gate"
    printf 'MISSION_RUNNER decision=HUMAN_GATE gate_id=%s cycle=%s\n' "$gate" "$cycle_count"
    exit 20
  fi

  # A cycle may mutate mission state before its process terminates. Never accept completion or an
  # audit result from a cycle that did not itself exit successfully.
  if [ "$cycle_exit" -ne 0 ]; then
    retryable=$(ledger_value "$ledger" retryable 2>/dev/null || printf 0)
    failure_class=$(ledger_value "$ledger" failure_class 2>/dev/null || printf unknown)
    if [ "$retryable" = 1 ] && [ "$cycle_restart_count" -lt "$MAX_CYCLE_RESTARTS" ]; then
      cycle_restart_count=$((cycle_restart_count + 1))
      runner_put cycle_restart_count "$cycle_restart_count"
      runner_put status retrying-cycle
      printf 'MISSION_RUNNER decision=RETRY_CYCLE failure=%s restart=%s/%s\n' \
        "$failure_class" "$cycle_restart_count" "$MAX_CYCLE_RESTARTS"
      continue
    fi
    runner_put status cycle-failed
    runner_put failure_class "$failure_class"
    printf 'MISSION_RUNNER decision=STOP_CYCLE_FAILURE cycle=%s exit=%s failure=%s\n' \
      "$cycle_count" "$cycle_exit" "$failure_class"
    exit 33
  fi

  cycle_restart_count=0
  runner_put cycle_restart_count 0

  status=$(mission_status)
  case "$status" in
    completed)
      runner_put status completed
      printf 'MISSION_RUNNER decision=COMPLETE mission_id=%s cycles=%s\n' "$current_id" "$cycle_count"
      exit 0
      ;;
    completion-pending)
      if [ "$cycle_kind" = completion-audit ]; then
        runner_put status completion-audit-inconclusive
        printf 'MISSION_RUNNER decision=STOP_AUDIT_INCONCLUSIVE cycle=%s\n' "$cycle_count"
        exit 38
      fi
      ;;
    blocked|deadline-reached)
      runner_put status "$status"
      printf 'MISSION_RUNNER decision=STOP status=%s cycles=%s\n' "$status" "$cycle_count"
      exit 30
      ;;
  esac

  after=$(fingerprint)
  if [ "$before" = "$after" ]; then
    stagnant_count=$((stagnant_count + 1))
  else
    stagnant_count=0
  fi
  runner_put stagnant_count "$stagnant_count"
  runner_put last_fingerprint "$after"

  if [ "$stagnant_count" -ge "$MAX_STAGNANT_CYCLES" ]; then
    runner_put status stagnated
    printf 'MISSION_RUNNER decision=STOP_STAGNATED cycles=%s stagnant=%s\n' "$cycle_count" "$stagnant_count"
    exit 32
  fi

  runner_put status continuing
  printf 'MISSION_RUNNER decision=CONTINUE cycle=%s stagnant=%s\n' "$cycle_count" "$stagnant_count"
done
