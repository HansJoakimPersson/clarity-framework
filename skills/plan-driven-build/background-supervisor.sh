#!/usr/bin/env sh

# Background worker supervisor for dispatch.sh. Runs one CLI process, emits a heartbeat/health file,
# and converts stalled or overlong workers into classified exit 124 instead of waiting forever.
# When the worker ends it restores any protected file the worker changed, and appends a readable
# summary to the log so that the log, not the raw event stream, is what a human or agent reads.

set -eu

die() { printf '%s\n' "$1" >&2; exit 2; }

for v in CFD_CLI CFD_MODE CFD_LOG CFD_EVENTS CFD_EXIT_FILE CFD_HEALTH_FILE CFD_LEDGER CFD_JOB_ID CFD_PHASE CFD_EFFECTIVE_MODEL CFD_STALL_TIMEOUT_SECONDS CFD_WALL_TIMEOUT_SECONDS CFD_HEARTBEAT_SECONDS; do
  eval "value=\${$v:-}"
  [ -n "$value" ] || die "background-supervisor.sh: missing $v"
done

progress_bytes() {
  total=0
  for f in "$CFD_LOG" "$CFD_EVENTS"; do
    if [ -r "$f" ]; then
      n=$(wc -c < "$f" 2>/dev/null || printf 0)
      total=$((total + n))
    fi
  done
  printf '%s\n' "$total"
}

write_health() {
  state=$1
  reason=$2
  now=$3
  bytes=$4
  tmp="$CFD_HEALTH_FILE.tmp.$$"
  {
    printf 'state\t%s\n' "$state"
    printf 'reason\t%s\n' "$reason"
    printf 'job_id\t%s\n' "$CFD_JOB_ID"
    printf 'supervisor_pid\t%s\n' "$$"
    printf 'worker_pid\t%s\n' "${worker_pid:-}"
    printf 'started_epoch\t%s\n' "$started"
    printf 'heartbeat_epoch\t%s\n' "$now"
    printf 'last_progress_epoch\t%s\n' "$last_progress"
    printf 'progress_bytes\t%s\n' "$bytes"
    printf 'heartbeat_seconds\t%s\n' "$CFD_HEARTBEAT_SECONDS"
    printf 'stall_timeout_seconds\t%s\n' "$CFD_STALL_TIMEOUT_SECONDS"
    printf 'wall_timeout_seconds\t%s\n' "$CFD_WALL_TIMEOUT_SECONDS"
    printf 'steps_complete\t%s\n' "$(steps_complete)"
    printf 'input_tokens\t%s\n' "$input_tokens"
    printf 'cached_input_tokens\t%s\n' "$cached_input_tokens"
    printf 'output_tokens\t%s\n' "$output_tokens"
    printf 'total_tokens\t%s\n' "$total_tokens"
  } > "$tmp"
  mv -- "$tmp" "$CFD_HEALTH_FILE"
}

# The build prompt asks the worker to write this exact marker line to its report once every plan
# step is done. It is what separates "stopped half-way" from "finished, then ran out of budget
# talking about it".
steps_complete() {
  if [ -n "${CFD_REPORT_FILE:-}" ] && [ -r "$CFD_REPORT_FILE" ]; then
    if grep -Fxq 'IMPLEMENTATION_STEPS_COMPLETE' "$CFD_REPORT_FILE" 2>/dev/null; then
      printf yes
    else
      printf no
    fi
  else
    printf unknown
  fi
}

input_tokens=${CF_INPUT_TOKENS:-unavailable}
cached_input_tokens=${CF_CACHED_INPUT_TOKENS:-unavailable}
cache_write_input_tokens=${CF_CACHE_WRITE_INPUT_TOKENS:-unavailable}
output_tokens=${CF_OUTPUT_TOKENS:-unavailable}
reasoning_output_tokens=${CF_REASONING_OUTPUT_TOKENS:-unavailable}
total_tokens=${CF_TOTAL_TOKENS:-unavailable}

# Refresh the token fields from the event stream. Called on every heartbeat as well as at the end,
# so consumption is visible while the build runs and survives a worker that dies on its budget.
read_usage() {
  [ -r "$CFD_EVENTS" ] || return 0
  usage=$(awk -f "${CFD_SKILLDIR:-$(dirname "$0")}/usage.awk" "$CFD_EVENTS" 2>/dev/null || true)
  [ -n "$usage" ] || return 0
  # shellcheck disable=SC2086
  set -- $usage
  input_tokens=$1
  cached_input_tokens=$2
  cache_write_input_tokens=$3
  output_tokens=$4
  reasoning_output_tokens=$5
  total_tokens=$(($1 + $4))
}

terminate_tree() {
  pid=$1
  children=''
  if command -v pgrep >/dev/null 2>&1; then
    children=$(pgrep -P "$pid" 2>/dev/null || true)
  fi
  # Stop the parent first so a shell loop cannot spawn replacement children while teardown walks
  # the tree. Then terminate the child snapshot captured immediately before the parent stop.
  kill -TERM "$pid" 2>/dev/null || true
  for child in $children; do
    terminate_tree "$child"
  done
}

force_kill_tree() {
  pid=$1
  children=''
  if command -v pgrep >/dev/null 2>&1; then
    children=$(pgrep -P "$pid" 2>/dev/null || true)
  fi
  kill -KILL "$pid" 2>/dev/null || true
  for child in $children; do
    force_kill_tree "$child"
  done
}

printf '%s\n' 'DISPATCH supervisor started'
status=0
timeout_class=''

case "$CFD_CLI" in
  codex)
    if [ -n "${CFD_PROFILE:-}" ]; then
      set -- aimux run "$CFD_PROFILE"
      [ -z "${CFD_MODEL:-}" ] || set -- "$@" -m "$CFD_MODEL"
      set -- "$@" -- codex -a never
      [ -z "${CFD_REASONING_EFFORT:-}" ] || set -- "$@" -c "model_reasoning_effort=$CFD_REASONING_EFFORT"
      [ -z "${CFD_ROLLOUT_CONFIG:-}" ] || set -- "$@" -c "$CFD_ROLLOUT_CONFIG"
      [ "${CFD_NETWORK:-0}" -eq 0 ] || set -- "$@" -c "sandbox_workspace_write.network_access=true"
      set -- "$@" exec --json -s "$CFD_MODE"
      [ -z "${CFD_MODEL:-}" ] || set -- "$@" -m "$CFD_MODEL"
      [ -z "${CFD_FINAL_FILE:-}" ] || set -- "$@" -o "$CFD_FINAL_FILE"
      set -- "$@" "$CFD_PROMPT"
    else
      set -- codex -a never
      [ -z "${CFD_REASONING_EFFORT:-}" ] || set -- "$@" -c "model_reasoning_effort=$CFD_REASONING_EFFORT"
      [ -z "${CFD_ROLLOUT_CONFIG:-}" ] || set -- "$@" -c "$CFD_ROLLOUT_CONFIG"
      [ "${CFD_NETWORK:-0}" -eq 0 ] || set -- "$@" -c "sandbox_workspace_write.network_access=true"
      set -- "$@" exec --json -s "$CFD_MODE"
      [ -z "${CFD_MODEL:-}" ] || set -- "$@" -m "$CFD_MODEL"
      [ -z "${CFD_FINAL_FILE:-}" ] || set -- "$@" -o "$CFD_FINAL_FILE"
      set -- "$@" "$CFD_PROMPT"
    fi
    ;;
  *) die "background-supervisor.sh: cli $CFD_CLI has no adapter" ;;
esac

rm -f "$CFD_EVENTS" "$CFD_EXIT_FILE" "$CFD_HEALTH_FILE"
[ -z "${CFD_FINAL_FILE:-}" ] || rm -f "$CFD_FINAL_FILE"
"$@" >"$CFD_EVENTS" 2>>"$CFD_LOG" </dev/null &
worker_pid=$!
started=$(date +%s)
last_progress=$started
last_bytes=$(progress_bytes)
write_health running none "$started" "$last_bytes"
last_heartbeat=$started

while kill -0 "$worker_pid" 2>/dev/null; do
  # Process completion and timeout checks use a short poll. The health file itself is written only
  # at the configured heartbeat cadence, so fast completion is not delayed by a 30-second heartbeat.
  sleep 1
  now=$(date +%s)
  bytes=$(progress_bytes)
  if [ "$bytes" -gt "$last_bytes" ]; then
    last_progress=$now
    last_bytes=$bytes
  fi

  if [ $((now - started)) -ge "$CFD_WALL_TIMEOUT_SECONDS" ]; then
    timeout_class='timeout.wall'
  elif [ $((now - last_progress)) -ge "$CFD_STALL_TIMEOUT_SECONDS" ]; then
    timeout_class='timeout.stalled'
  fi

  if [ -n "$timeout_class" ]; then
    write_health terminating "$timeout_class" "$now" "$bytes"
    printf 'DISPATCH watchdog terminating worker pid=%s reason=%s\n' "$worker_pid" "$timeout_class" >> "$CFD_LOG"
    terminate_tree "$worker_pid"
    sleep 1
    # Do not wait for kill -0 to become false: an exited-but-unreaped child may still satisfy it.
    # Bound teardown mechanically and then reap the direct worker.
    force_kill_tree "$worker_pid"
    wait "$worker_pid" 2>/dev/null || true
    status=124
    break
  fi

  if [ $((now - last_heartbeat)) -ge "$CFD_HEARTBEAT_SECONDS" ]; then
    read_usage
    write_health running none "$now" "$bytes"
    last_heartbeat=$now
  fi
done

if [ -z "$timeout_class" ]; then
  wait "$worker_pid" || status=$?
fi

failure_class=none
retryable=0
model_policy=profile-default
[ -n "${CFD_MODEL:-}" ] && model_policy=pinned
if [ -n "$timeout_class" ]; then
  failure_class=$timeout_class
  retryable=1
elif [ "$status" -ne 0 ]; then
  if [ ! -s "$CFD_EVENTS" ] && grep -Eiq 'operation not permitted' "$CFD_LOG" 2>/dev/null; then
    # Died before the first event: the CLI was launched from inside another sandbox.
    failure_class=environment.sandbox-nested
  elif grep -Eiq 'shared rollout token budget exhausted|rollout.?budget.*exhaust' "$CFD_LOG" "$CFD_EVENTS" 2>/dev/null; then
    failure_class=budget
  elif grep -Eiq 'rate.?limit|too many requests|quota exceeded|temporarily unavailable|server overloaded|try again later' "$CFD_LOG" "$CFD_EVENTS" 2>/dev/null; then
    failure_class=environment.rate_limit
  elif grep -Eiq 'timeout|timed out|deadline exceeded' "$CFD_LOG" "$CFD_EVENTS" 2>/dev/null; then
    failure_class=timeout.external
    retryable=1
  elif grep -Eiq 'unknown model|model.*not found|invalid.*model' "$CFD_LOG" "$CFD_EVENTS" 2>/dev/null; then
    failure_class=model-routing
  else
    failure_class=unknown
  fi
fi

if [ "$status" -eq 0 ] && [ -n "${CFD_MODEL_EVIDENCE:-}" ]; then
  if [ ! -r "$CFD_MODEL_EVIDENCE" ]; then
    printf '%s\n' "dispatch supervisor: model evidence file not readable: $CFD_MODEL_EVIDENCE" >&2
    status=78; failure_class=model-routing; model_policy=failed
  else
    observed_models=$(sed '/^[[:space:]]*$/d' "$CFD_MODEL_EVIDENCE" | tr '\n' ',' | sed 's/,$//')
    if [ -z "$observed_models" ] || sed '/^[[:space:]]*$/d' "$CFD_MODEL_EVIDENCE" | grep -Fvx "$CFD_EFFECTIVE_MODEL" >/dev/null; then
      status=78; failure_class=model-routing; model_policy=failed
    else
      model_policy=passed
    fi
  fi
fi

read_usage

# Restore anything the worker was told to leave alone. The manifest pairs a snapshot with its
# original path; a changed or deleted original is put back and the violation is recorded.
protected_changed=''
if [ -n "${CFD_PROTECT_MANIFEST:-}" ] && [ -s "$CFD_PROTECT_MANIFEST" ]; then
  while IFS='	' read -r snapshot original; do
    [ -n "$snapshot" ] && [ -n "$original" ] || continue
    if [ ! -f "$original" ] || ! cmp -s "$snapshot" "$original"; then
      mkdir -p "$(dirname "$original")"
      cp -p -- "$snapshot" "$original"
      protected_changed="$protected_changed $original"
    fi
  done < "$CFD_PROTECT_MANIFEST"
fi

steps=$(steps_complete)

# Readable summary. Everything above this point in the log is supervisor and CLI stderr noise.
{
  printf '\nDISPATCH finished  status=%s  failure_class=%s  steps_complete=%s  total_tokens=%s  rollout_budget=%s\n' \
    "$status" "$failure_class" "$steps" "$total_tokens" "${CFD_MAX_ROLLOUT_TOKENS:-unbounded}"
  if [ "$failure_class" = budget ]; then
    if [ "$steps" = yes ]; then
      printf '%s\n' 'DISPATCH budget stop after the report marked every plan step complete: verify the tree before re-dispatching.'
    else
      printf '%s\n' 'DISPATCH budget stop before every plan step was reported complete: read the build report for what remains.'
    fi
  fi
  if [ -n "$protected_changed" ]; then
    printf 'DISPATCH protected file(s) changed by the worker and restored:%s\n' "$protected_changed"
  fi
  if [ -n "${CFD_UNTRACKED_BEFORE:-}" ] && [ -r "$CFD_UNTRACKED_BEFORE" ]; then
    new_untracked=$(git ls-files --others --exclude-standard 2>/dev/null | sort | comm -13 "$CFD_UNTRACKED_BEFORE" - 2>/dev/null || true)
    printf '\n--- untracked files new since launch (any other untracked file predates this build) ---\n'
    if [ -n "$new_untracked" ]; then
      printf '%s\n' "$new_untracked" | head -40
      extra=$(($(printf '%s\n' "$new_untracked" | wc -l) - 40))
      [ "$extra" -le 0 ] || printf '… and %s more\n' "$extra"
    else
      printf 'none\n'
    fi
  fi
  if [ -n "${CFD_REPORT_FILE:-}" ] && [ -s "$CFD_REPORT_FILE" ]; then
    printf '\n--- build report (%s), last 30 lines ---\n' "$CFD_REPORT_FILE"
    tail -n 30 "$CFD_REPORT_FILE" | cut -c 1-300
  else
    printf '\n--- build report: not written ---\n'
  fi
  if [ "$status" -ne 0 ] && [ -s "$CFD_EVENTS" ]; then
    printf '\n--- last events (%s) ---\n' "$CFD_EVENTS"
    sh "${CFD_SKILLDIR:-$(dirname "$0")}/dispatch-tail.sh" --events "$CFD_EVENTS" --lines 12 2>/dev/null || true
  fi
  if [ -n "${CFD_FINAL_FILE:-}" ] && [ -s "$CFD_FINAL_FILE" ]; then
    printf '\n--- final message (%s) ---\n' "$CFD_FINAL_FILE"
    head -n 40 "$CFD_FINAL_FILE" | cut -c 1-300
  fi
} >> "$CFD_LOG"

printf '%s\n' "$status" > "$CFD_EXIT_FILE"
if [ -n "${CFD_LEDGER:-}" ]; then
  printf 'job_id\tstatus\tphase\tprofile\tcli\trequested_model\teffective_model\treasoning_effort\trollout_budget_tokens\tattempts\tretryable\tfailure_class\tmodel_policy\tinput_tokens\tcached_input_tokens\tcache_write_input_tokens\toutput_tokens\treasoning_output_tokens\ttotal_tokens\texit_status\n' > "$CFD_LEDGER"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t1\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$CFD_JOB_ID" "$([ "$status" -eq 0 ] && printf passed || printf failed)" "$CFD_PHASE" \
    "${CFD_PROFILE:-cli:$CFD_CLI}" "$CFD_CLI" "${CFD_MODEL:-profile-default}" \
    "$CFD_EFFECTIVE_MODEL" "${CFD_REASONING_EFFORT:-profile-default}" \
    "${CFD_MAX_ROLLOUT_TOKENS:-unbounded}" "$retryable" "$failure_class" "$model_policy" \
    "$input_tokens" "$cached_input_tokens" "$cache_write_input_tokens" "$output_tokens" \
    "$reasoning_output_tokens" "$total_tokens" "$status" >> "$CFD_LEDGER"
fi

finished=$(date +%s)
bytes=$(progress_bytes)
write_health finished "$failure_class" "$finished" "$bytes"
exit "$status"
