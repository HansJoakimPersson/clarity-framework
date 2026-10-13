#!/usr/bin/env sh

# Clarity Framework – record one orchestrator-run command as verification evidence.
#
# The verification agent runs read-only and cannot build, start a browser, or run the project gate.
# Commands the plan assigns to the orchestrator therefore need a record the verifier can read: this
# script runs one command, keeps its full output out of the orchestrator's context, and appends a
# bounded entry (command, exit code, commit, last lines) to an evidence file.
#
# The same script measures a baseline: run a plan's verification command on the baseline commit
# before the plan is approved, with a label such as `baseline`.
#
# Usage:
#   evidence.sh --out FILE --label NAME [--env-file FILE] [--tail N] [--timeout-seconds N]
#               --cmd 'COMMAND'
#
# Exit: 0 when the entry was recorded (whatever the command returned), 2 on a usage error. The
# command's own exit code is in the EVIDENCE summary line and in the entry.

set -eu

die() { printf '%s\n' "$1" >&2; exit 2; }

OUT=''; LABEL=''; CMD=''; ENV_FILE=''; TAIL_N=15; TIMEOUT=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --out) OUT="${2:-}"; shift 2 ;;
    --label) LABEL="${2:-}"; shift 2 ;;
    --cmd) CMD="${2:-}"; shift 2 ;;
    --env-file) ENV_FILE="${2:-}"; shift 2 ;;
    --tail) TAIL_N="${2:-}"; shift 2 ;;
    --timeout-seconds) TIMEOUT="${2:-}"; shift 2 ;;
    *) die "evidence.sh: unknown argument '$1'" ;;
  esac
done
[ -n "$OUT" ] || die 'evidence.sh: --out is required'
[ -n "$LABEL" ] || die 'evidence.sh: --label is required'
[ -n "$CMD" ] || die 'evidence.sh: --cmd is required'
case "$LABEL" in *[!A-Za-z0-9._-]*) die "evidence.sh: --label may contain only letters, digits, dot, underscore, and hyphen (got '$LABEL')" ;; esac
case "$TAIL_N:$TIMEOUT" in
  *[!0-9:]*|:*|*:) die 'evidence.sh: --tail and --timeout-seconds must be non-negative integers' ;;
esac

if [ -n "$ENV_FILE" ]; then
  [ -r "$ENV_FILE" ] || die "evidence.sh: env file not readable: $ENV_FILE"
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

out_dir=$(dirname "$OUT")
log_dir="$out_dir/evidence"
mkdir -p "$log_dir"
n=1
while [ -e "$log_dir/$n-$LABEL.log" ]; do n=$((n + 1)); done
log="$log_dir/$n-$LABEL.log"

commit=$(git rev-parse --short HEAD 2>/dev/null || printf 'no-git')
dirty='clean'
if [ "$commit" != no-git ] && [ -n "$(git status --porcelain 2>/dev/null | head -1)" ]; then
  dirty='dirty'
fi

started=$(date +%s)
rc=0
timed_out=0
# stdin is closed so a command that reads it cannot hang the orchestrator.
if [ "$TIMEOUT" -gt 0 ]; then
  # The watchdog runs in a subshell whose stderr is discarded: the shell's own "Terminated" job
  # notice would otherwise land in the orchestrator's context. The command's stderr is in the log.
  (
    sh -c "$CMD" > "$log" 2>&1 < /dev/null &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
      if [ $(($(date +%s) - started)) -ge "$TIMEOUT" ]; then
        children=$(pgrep -P "$pid" 2>/dev/null || true)
        kill -TERM "$pid" 2>/dev/null || true
        for child in $children; do kill -TERM "$child" 2>/dev/null || true; done
        sleep 1
        kill -KILL "$pid" 2>/dev/null || true
        for child in $children; do kill -KILL "$child" 2>/dev/null || true; done
        wait "$pid" 2>/dev/null || true
        exit 124
      fi
      sleep 1
    done
    wait "$pid"
  ) 2>/dev/null || rc=$?
  [ "$rc" -ne 124 ] || timed_out=1
else
  sh -c "$CMD" > "$log" 2>&1 < /dev/null || rc=$?
fi
duration=$(($(date +%s) - started))

{
  printf '## %s\n\n' "$LABEL"
  printf -- '- command: `%s`\n' "$CMD"
  printf -- '- exit: %s%s\n' "$rc" "$([ "$timed_out" -eq 1 ] && printf ' (timed out after %ss)' "$TIMEOUT" || true)"
  printf -- '- commit: %s (%s tree)\n' "$commit" "$dirty"
  printf -- '- recorded: %s, %ss, by the orchestrator outside the dispatch sandbox\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$duration"
  printf -- '- full output: `%s`\n\n' "$log"
  if [ "$TAIL_N" -gt 0 ]; then
    printf '```text\n'
    tail -n "$TAIL_N" "$log" | cut -c 1-240
    printf '```\n'
  fi
  printf '\n'
} >> "$OUT"

printf 'EVIDENCE label=%s exit=%s seconds=%s commit=%s tree=%s log=%s out=%s\n' \
  "$LABEL" "$rc" "$duration" "$commit" "$dirty" "$log" "$OUT"
