#!/usr/bin/env sh

# Read one background dispatch's sentinel/health files without tailing its logs.
# Exit codes: 0 finished, 10 healthy/running, 20 stale heartbeat, 30 lost/unknown, 2 usage.

set -eu

die() { printf '%s\n' "$1" >&2; exit 2; }

LOG=''
NOW=''
STALE_SECONDS=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --log) LOG="${2:-}"; shift 2 ;;
    --now-epoch) NOW="${2:-}"; shift 2 ;;
    --stale-seconds) STALE_SECONDS="${2:-}"; shift 2 ;;
    *) die "dispatch-health.sh: unknown argument '$1'" ;;
  esac
done
[ -n "$LOG" ] || die 'dispatch-health.sh: --log is required'

base=$(printf '%s' "$LOG" | sed 's/\.log$//')
exit_file="$base.exit"
health_file="$base.health"

if [ -r "$exit_file" ]; then
  code=$(cat "$exit_file")
  reason=unknown
  if [ -r "$health_file" ]; then
    reason=$(awk -F '\t' '$1 == "reason" { print $2; exit }' "$health_file")
    [ -n "$reason" ] || reason=unknown
  fi
  printf 'DISPATCH_HEALTH\tstate=finished\texit=%s\treason=%s\n' "$code" "$reason"
  exit 0
fi

if [ ! -r "$health_file" ]; then
  printf '%s\n' 'DISPATCH_HEALTH state=unknown reason=no-health-or-sentinel'
  exit 30
fi

field() { awk -F '\t' -v k="$1" '$1 == k { print $2; exit }' "$health_file"; }
state=$(field state)
heartbeat=$(field heartbeat_epoch)
supervisor_pid=$(field supervisor_pid)
heartbeat_seconds=$(field heartbeat_seconds)
[ -n "$NOW" ] || NOW=$(date +%s)
case "$NOW:$heartbeat" in *[!0-9:]*|:*) die 'dispatch-health.sh: invalid heartbeat metadata' ;; esac

if [ -z "$STALE_SECONDS" ]; then
  case "$heartbeat_seconds" in ''|*[!0-9]*) heartbeat_seconds=30 ;; esac
  STALE_SECONDS=$((heartbeat_seconds * 3 + 5))
fi
case "$STALE_SECONDS" in ''|*[!0-9]*) die 'dispatch-health.sh: --stale-seconds must be an integer' ;; esac

age=$((NOW - heartbeat))
if [ "$age" -le "$STALE_SECONDS" ]; then
  printf 'DISPATCH_HEALTH\tstate=%s\theartbeat_age=%s\tsupervisor_pid=%s\n' "$state" "$age" "$supervisor_pid"
  exit 10
fi

if [ -n "$supervisor_pid" ] && kill -0 "$supervisor_pid" 2>/dev/null; then
  printf 'DISPATCH_HEALTH\tstate=stale\theartbeat_age=%s\tsupervisor_pid=%s\n' "$age" "$supervisor_pid"
  exit 20
fi

printf 'DISPATCH_HEALTH\tstate=lost\theartbeat_age=%s\tsupervisor_pid=%s\n' "$age" "$supervisor_pid"
exit 30
