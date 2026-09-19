#!/usr/bin/env bash

# Persistent continuation state for project-driver.
# Normal successful checkpoints return CONTINUE. A user-facing question is valid only when
# 'authorize' has issued an open HUMAN_GATE token for a Reserved action.

set -euo pipefail

die() { printf '%s\n' "$1" >&2; exit 2; }

SKILLDIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
AUTHORITY="$SKILLDIR/scripts/authority.sh"
STATE_ROOT=${CLARITY_MISSION_DIR:-docs/plans/.runs/project-driver-mission}
STATE="$STATE_ROOT/active.tsv"
GOAL="$STATE_ROOT/goal.txt"
GATES="$STATE_ROOT/gates"

get_state() {
  local key=$1
  [ -r "$STATE" ] || return 1
  awk -F '\t' -v k="$key" '$1 == k { print substr($0, index($0, "\t") + 1); exit }' "$STATE"
}

put_state() {
  local key=$1 value=$2 tmp
  tmp="$STATE.tmp.$$"
  awk -F '\t' -v k="$key" '$1 != k { print }' "$STATE" > "$tmp"
  printf '%s\t%s\n' "$key" "$value" >> "$tmp"
  mv -- "$tmp" "$STATE"
}

require_active() {
  [ -r "$STATE" ] || die 'mission-control.sh: no active mission'
  [ "$(get_state status)" = active ] || die "mission-control.sh: mission is not active (status=$(get_state status))"
}

bool() {
  case "$1" in yes|no) ;; *) die "mission-control.sh: expected yes or no, got '$1'" ;; esac
}

command=${1:-}
[ -n "$command" ] || die 'mission-control.sh: command required'
shift

case "$command" in
  start)
    goal=''
    mode='until-complete'
    deadline=''
    gate_policy='reserved-only'
    replace='no'
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --goal) goal="${2:-}"; shift 2 ;;
        --mode) mode="${2:-}"; shift 2 ;;
        --deadline-epoch) deadline="${2:-}"; shift 2 ;;
        --human-gate-policy) gate_policy="${2:-}"; shift 2 ;;
        --replace) replace='yes'; shift ;;
        *) die "mission-control.sh start: unknown argument '$1'" ;;
      esac
    done
    [ -n "$goal" ] || die 'mission-control.sh start: --goal is required'
    case "$mode" in until-complete|until-deadline|until-complete-or-deadline) ;; *) die "mission-control.sh start: invalid mode '$mode'" ;; esac
    [ "$gate_policy" = reserved-only ] || die 'mission-control.sh start: only reserved-only human gates are supported'
    if [ "$mode" != until-complete ]; then
      [[ "$deadline" =~ ^[0-9]+$ ]] || die 'mission-control.sh start: deadline mode requires --deadline-epoch'
    fi

    if [ -r "$STATE" ] && [ "$(get_state status || true)" = active ] && [ "$replace" != yes ]; then
      printf 'MISSION\tdecision=RESUME\tid=%s\tmode=%s\n' "$(get_state id)" "$(get_state mode)"
      exit 0
    fi

    mkdir -p -- "$GATES"
    id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
    {
      printf 'id\t%s\n' "$id"
      printf 'status\tactive\n'
      printf 'mode\t%s\n' "$mode"
      printf 'started_epoch\t%s\n' "$(date +%s)"
      printf 'deadline_epoch\t%s\n' "$deadline"
      printf 'human_gate_policy\t%s\n' "$gate_policy"
    } > "$STATE"
    printf '%s\n' "$goal" > "$GOAL"
    printf 'MISSION\tdecision=STARTED\tid=%s\tmode=%s\n' "$id" "$mode"
    ;;

  status)
    [ -r "$STATE" ] || { printf '%s\n' 'MISSION decision=NONE'; exit 0; }
    printf 'MISSION\tid=%s\tstatus=%s\tmode=%s\thuman_gate_policy=%s\n' \
      "$(get_state id)" "$(get_state status)" "$(get_state mode)" "$(get_state human_gate_policy)"
    ;;

  authorize)
    require_active
    action=''
    impact='unknown'
    reason=''
    policy='docs/00-ai-context.md'
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --action) action="${2:-}"; shift 2 ;;
        --impact) impact="${2:-}"; shift 2 ;;
        --reason) reason="${2:-}"; shift 2 ;;
        --policy) policy="${2:-}"; shift 2 ;;
        *) die "mission-control.sh authorize: unknown argument '$1'" ;;
      esac
    done
    [ -n "$action" ] || die 'mission-control.sh authorize: --action is required'

    set +e
    auth=$("$AUTHORITY" --action "$action" --impact "$impact" --policy "$policy")
    rc=$?
    set -e

    case "$rc" in
      0)
        printf '%s\n' "$auth"
        ;;
      10)
        printf '%s\n' "$auth"
        printf 'MISSION\tdecision=ORCHESTRATOR\taction=%s\n' "$action"
        exit 10
        ;;
      20)
        mkdir -p -- "$GATES"
        gate_id="HG-$(date -u +%Y%m%dT%H%M%SZ)-$$"
        {
          printf 'id\t%s\n' "$gate_id"
          printf 'status\topen\n'
          printf 'action\t%s\n' "$action"
          printf 'impact\t%s\n' "$impact"
          printf 'mission_id\t%s\n' "$(get_state id)"
        } > "$GATES/$gate_id.tsv"
        printf '%s\n' "$reason" > "$GATES/$gate_id.reason.txt"
        printf '%s\n' "$auth"
        printf 'MISSION\tdecision=HUMAN_GATE\tgate_id=%s\taction=%s\n' "$gate_id" "$action"
        exit 20
        ;;
      *)
        printf '%s\n' "$auth" >&2
        exit "$rc"
        ;;
    esac
    ;;

  resolve-gate)
    require_active
    gate=''
    resolution=''
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --gate) gate="${2:-}"; shift 2 ;;
        --resolution) resolution="${2:-}"; shift 2 ;;
        *) die "mission-control.sh resolve-gate: unknown argument '$1'" ;;
      esac
    done
    [ -n "$gate" ] || die 'mission-control.sh resolve-gate: --gate is required'
    case "$resolution" in approved|declined) ;; *) die 'mission-control.sh resolve-gate: --resolution must be approved or declined' ;; esac
    gate_file="$GATES/$gate.tsv"
    [ -r "$gate_file" ] || die "mission-control.sh resolve-gate: unknown gate '$gate'"
    tmp="$gate_file.tmp.$$"
    awk -F '\t' '$1 != "status" && $1 != "resolution" { print }' "$gate_file" > "$tmp"
    printf 'status\tclosed\nresolution\t%s\n' "$resolution" >> "$tmp"
    mv -- "$tmp" "$gate_file"
    printf 'MISSION\tdecision=GATE_RESOLVED\tgate_id=%s\tresolution=%s\n' "$gate" "$resolution"
    ;;

  checkpoint)
    require_active
    project_complete='no'
    ready_work='no'
    recoverable='no'
    gate='none'
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --project-complete) project_complete="${2:-}"; shift 2 ;;
        --ready-work) ready_work="${2:-}"; shift 2 ;;
        --recoverable) recoverable="${2:-}"; shift 2 ;;
        --gate) gate="${2:-}"; shift 2 ;;
        *) die "mission-control.sh checkpoint: unknown argument '$1'" ;;
      esac
    done
    bool "$project_complete"
    bool "$ready_work"
    bool "$recoverable"

    if [ "$project_complete" = yes ]; then
      put_state status completed
      printf 'MISSION\tdecision=COMPLETE\tid=%s\n' "$(get_state id)"
      exit 0
    fi

    mode=$(get_state mode)
    deadline=$(get_state deadline_epoch)
    if [ "$mode" != until-complete ] && [ -n "$deadline" ] && [ "$(date +%s)" -ge "$deadline" ]; then
      put_state status deadline-reached
      printf 'MISSION\tdecision=STOP_DEADLINE\tid=%s\n' "$(get_state id)"
      exit 30
    fi

    if [ "$gate" != none ]; then
      gate_file="$GATES/$gate.tsv"
      [ -r "$gate_file" ] || die "mission-control.sh checkpoint: unknown gate '$gate'"
      gate_status=$(awk -F '\t' '$1 == "status" { print $2; exit }' "$gate_file")
      [ "$gate_status" = open ] || die "mission-control.sh checkpoint: gate '$gate' is not open"
      printf 'MISSION\tdecision=HUMAN_GATE\tgate_id=%s\n' "$gate"
      exit 20
    fi

    if [ "$ready_work" = yes ]; then
      printf 'MISSION\tdecision=CONTINUE\treason=ready-work\n'
      exit 0
    fi

    if [ "$recoverable" = yes ]; then
      printf 'MISSION\tdecision=CONTINUE\treason=recovery\n'
      exit 0
    fi

    put_state status blocked
    printf 'MISSION\tdecision=STOP_BLOCKED\tid=%s\n' "$(get_state id)"
    exit 30
    ;;

  *)
    die "mission-control.sh: unknown command '$command'"
    ;;
esac
