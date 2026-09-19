#!/usr/bin/env sh

# Background worker supervisor for dispatch.sh. Runs one CLI process, emits a heartbeat/health file,
# and converts stalled or overlong workers into classified exit 124 instead of waiting forever.

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
  } > "$tmp"
  mv -- "$tmp" "$CFD_HEALTH_FILE"
}

terminate_tree() {
  pid=$1
  if command -v pgrep >/dev/null 2>&1; then
    children=$(pgrep -P "$pid" 2>/dev/null || true)
    for child in $children; do
      terminate_tree "$child"
    done
  fi
  kill -TERM "$pid" 2>/dev/null || true
}

force_kill_tree() {
  pid=$1
  if command -v pgrep >/dev/null 2>&1; then
    children=$(pgrep -P "$pid" 2>/dev/null || true)
    for child in $children; do
      force_kill_tree "$child"
    done
  fi
  kill -KILL "$pid" 2>/dev/null || true
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
      [ -z "${CFD_MAX_ROLLOUT_TOKENS:-}" ] || set -- "$@" -c "features.rollout_budget={enabled=true,limit_tokens=$CFD_MAX_ROLLOUT_TOKENS,reminder_at_remaining_tokens=[],sampling_token_weight=1.0,prefill_token_weight=1.0}"
      [ "${CFD_NETWORK:-0}" -eq 0 ] || set -- "$@" -c "sandbox_workspace_write.network_access=true"
      set -- "$@" exec --json -s "$CFD_MODE"
      [ -z "${CFD_MODEL:-}" ] || set -- "$@" -m "$CFD_MODEL"
      set -- "$@" "$CFD_PROMPT"
    else
      set -- codex -a never
      [ -z "${CFD_REASONING_EFFORT:-}" ] || set -- "$@" -c "model_reasoning_effort=$CFD_REASONING_EFFORT"
      [ -z "${CFD_MAX_ROLLOUT_TOKENS:-}" ] || set -- "$@" -c "features.rollout_budget={enabled=true,limit_tokens=$CFD_MAX_ROLLOUT_TOKENS,reminder_at_remaining_tokens=[],sampling_token_weight=1.0,prefill_token_weight=1.0}"
      [ "${CFD_NETWORK:-0}" -eq 0 ] || set -- "$@" -c "sandbox_workspace_write.network_access=true"
      set -- "$@" exec --json -s "$CFD_MODE"
      [ -z "${CFD_MODEL:-}" ] || set -- "$@" -m "$CFD_MODEL"
      set -- "$@" "$CFD_PROMPT"
    fi
    ;;
  *) die "background-supervisor.sh: cli $CFD_CLI has no adapter" ;;
esac

rm -f "$CFD_EVENTS" "$CFD_EXIT_FILE" "$CFD_HEALTH_FILE"
"$@" >"$CFD_EVENTS" 2>>"$CFD_LOG" &
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
    sleep 2
    if kill -0 "$worker_pid" 2>/dev/null; then force_kill_tree "$worker_pid"; fi
    wait "$worker_pid" 2>/dev/null || true
    status=124
    break
  fi

  if [ $((now - last_heartbeat)) -ge "$CFD_HEARTBEAT_SECONDS" ]; then
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
  if grep -Eiq 'shared rollout token budget exhausted|rollout.?budget.*exhaust' "$CFD_LOG" "$CFD_EVENTS" 2>/dev/null; then
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

input_tokens=${CF_INPUT_TOKENS:-unavailable}
cached_input_tokens=${CF_CACHED_INPUT_TOKENS:-unavailable}
cache_write_input_tokens=${CF_CACHE_WRITE_INPUT_TOKENS:-unavailable}
output_tokens=${CF_OUTPUT_TOKENS:-unavailable}
reasoning_output_tokens=${CF_REASONING_OUTPUT_TOKENS:-unavailable}
total_tokens=${CF_TOTAL_TOKENS:-unavailable}
if [ -r "$CFD_EVENTS" ]; then
  u_input=0; u_cached=0; u_cache_write=0; u_output=0; u_reasoning=0; u_found=0
  while IFS= read -r line; do
    case "$line" in
      *'"type":"turn.completed"'*|*'"type": "turn.completed"'*)
        n=$(printf '%s\n' "$line" | sed -n 's/.*"input_tokens":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
        [ -n "$n" ] || continue
        c=$(printf '%s\n' "$line" | sed -n 's/.*"cached_input_tokens":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
        w=$(printf '%s\n' "$line" | sed -n 's/.*"cache_write_input_tokens":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
        o=$(printf '%s\n' "$line" | sed -n 's/.*"output_tokens":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
        q=$(printf '%s\n' "$line" | sed -n 's/.*"reasoning_output_tokens":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
        u_found=1
        u_input=$((u_input + n))
        u_cached=$((u_cached + ${c:-0}))
        u_cache_write=$((u_cache_write + ${w:-0}))
        u_output=$((u_output + ${o:-0}))
        u_reasoning=$((u_reasoning + ${q:-0}))
        ;;
    esac
  done < "$CFD_EVENTS"
  if [ "$u_found" -eq 1 ]; then
    input_tokens=$u_input
    cached_input_tokens=$u_cached
    cache_write_input_tokens=$u_cache_write
    output_tokens=$u_output
    reasoning_output_tokens=$u_reasoning
    total_tokens=$((u_input + u_output))
  fi
fi

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
