#!/usr/bin/env sh
# Clarity Framework – dispatch for plan-driven-build.
#
# One stable entry point for every dispatch in the workflow. It exists for four reasons:
#   1. The prompt lives in prompts/*.txt, not in SKILL.md. That keeps roughly a thousand words of
#      instruction text out of the orchestrator's context entirely — the orchestrator names a
#      prompt file and fills its placeholders, it never reads the prompt.
#   2. Subscription separation is verified, not assumed. Which CLI runs and which subscription pays
#      both come from one aimux profile, resolved from ~/.aimux/config.yaml at dispatch time. A
#      pool entry that is not in that file is reported as a FALLBACK line rather than the dispatch
#      silently running under whatever profile happens to be active. An aimux profile is not a persona and
#      does not change how an agent behaves; it unifies the CLI, the model, the authentication and
#      the subscription in one object.
#   3. Sandbox and approval policy are always set together. Setting only the sandbox leaves the
#      approval policy at its default, which is what makes an unattended dispatch stop and ask.
#   4. The orchestrator gets a one-line result with a line count measured against the budget, so it
#      learns whether a report fits before opening it.
#
# A single stable command prefix is also what a permission allowlist can match reliably; an
# env-prefixed, backgrounded compound command is not.
#
# Usage:
#   dispatch.sh --profile NAME[,NAME...]
#               --mode read-only|workspace-write|danger-full-access
#               (--prompt-file FILE [--var KEY=VALUE ...] | --prompt TEXT) [--model NAME]
#               [--reasoning-effort none|low|medium|high|xhigh]
#               --out FILE [--max-lines N] [--env-file FILE] [--preflight FILE]
#               [--model-evidence FILE] [--ledger FILE] [--job-id ID] [--phase PHASE] [--max-retries N]
#               [--max-rollout-tokens N]
#   dispatch.sh --profile NAME[,NAME...]
#               --mode workspace-write|danger-full-access
#               (--prompt-file FILE [--var KEY=VALUE ...] | --prompt TEXT) [--model NAME]
#               --log FILE --background [--network] [--env-file FILE]
#               [--model-evidence FILE] [--max-rollout-tokens N]
#
# --profile is an ordered, comma-separated pool of aimux profile names, e.g.
# `--profile codework1,codework2,codework3`. This is priority order, resolved once per dispatch —
# not round-robin, and not a rotation the caller manages between runs. Each name is looked up in
# ~/.aimux/config.yaml (override with AIMUX_CONFIG); the first present wins, and its `cli:` field
# selects the adapter. Because an aimux profile carries the CLI, moving a level from codex to
# gemini is `aimux profile update <name> --cli gemini` with no change to this file. A pool spreads
# cost across interchangeable subscriptions; it does not bind a level to one persona. Nothing about
# review needing a *different* profile from reasoning is enforced here — separate that with the
# prompt file's content.
#
# A pool entry written `cli:NAME` (for example `--profile codework1,cli:codex`) is an explicit,
# opt-in fallback: run NAME directly, with no aimux wrapper and no subscription separation. It is
# consulted only after every real profile ahead of it fails to resolve, and using it fires a
# FALLBACK: line.
#
# --mode danger-full-access removes codex's macOS Seatbelt sandbox entirely (full filesystem and
# network access, no workspace confinement). Use it ONLY for a narrowly scoped dispatch that must
# spawn a real macOS GUI subprocess — concretely, Playwright launching Chromium. codex's
# workspace-write sandbox denies Chromium's Mach-port rendezvous IPC (`bootstrap_check_in ...
# MachPortRendezvousServer: Permission denied (1100)`), confirmed by running the same Chromium binary
# unsandboxed on the same machine, which launches cleanly. There is no known `-c` config override for
# this under workspace-write — network access has one (`sandbox_workspace_write.network_access`),
# Mach IPC does not. Keep the danger-full-access prompt to exactly the one command that needs it
# (e.g. `cd frontend && npm run test:e2e`) — never use it for a step that writes application code,
# since it forfeits the workspace confinement that makes workspace-write safe to leave unattended.
#
# --mode read-only dispatches are side-effect-free, so a failed attempt retries the next resolvable
# profile in the pool automatically until one succeeds or the pool is exhausted. --mode
# workspace-write never retries after launch: a build can fail partway through, and retrying it
# blindly on a different subscription would compound a real failure instead of a rate limit. The
# pool still decides which profile *starts* a workspace-write dispatch — the first one that resolves.
#
# The retry-on-failure path treats any non-zero CLI exit as grounds to try the next profile. This
# is unverified: it has not been checked against a real rate-limit error, so it may also retry a
# genuine prompt or task failure on a different subscription instead of surfacing it. Read this
# skill's setup notes before trusting it unattended, and watch the DISPATCH summary line the first
# few times it fires.
#
# --model NAME overrides the profile's own stored model for this one dispatch, independent of which
# profile ends up paying. For a resolved profile it is passed to `aimux run` as `-m NAME` and to
# the CLI's own model flag as well. For a `cli:NAME` fallback entry the adapter passes it to the
# CLI's own model flag (codex: `-m`, after `exec`). `--reasoning-effort LEVEL` is sent as Codex's
# `model_reasoning_effort` configuration.
# Check
# `codex exec --help` if a dispatch fails fast with an unrecognized-argument error.
#
# --prompt TEXT still works for an ad-hoc dispatch. Placeholders in a prompt file are written
# {{KEY}}; every placeholder must be supplied with --var or the dispatch aborts. Values are
# single-line. Keys are A-Z and underscore.
#
# Background mode writes the exit code to the log path with .log replaced by .exit. Poll that
# sentinel — never tail a running build. It uses `nohup` so the build is not tied to the
# short-lived shell that launched it; `aimux run <profile> -- <codex exec>` was verified to run to
# completion under `nohup` with no TTY (aimux 0.25.0). Some CLI harnesses clean up ordinary
# background children as soon as the spawning command returns; that leaves an empty log and no
# sentinel.
#
# --env-file sources one project-owned shell file before launching the CLI. Use it for language or
# toolchain bootstrap such as JAVA_HOME, Node version managers, or Go toolchain variables. The file
# is explicit per dispatch so environment corrections stay visible in the run journal.
# --preflight runs a project-owned, read-only shell check before dispatch. A non-zero result blocks
# the job and is never retried. --model-evidence is a newline-separated list of observed parent and
# child models; every non-empty line must equal the requested/effective model. Background dispatches
# validate the same evidence before writing their completion sentinel. --ledger writes one
# tab-separated, machine-readable completion record. --max-retries caps read-only pool retries.
# --max-rollout-tokens N enables Codex's native rollout budget for the dispatch. Implementation
# requires both an explicit --model and a positive rollout budget: profile selection decides which
# subscription pays, while the level policy decides which model may run and how much it may consume.

set -eu

die() { printf '%s\n' "$1" >&2; exit 2; }

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/clarity-dispatch.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

PROFILE=''; MODE=''; OUT=''; LOG=''; PROMPT=''; PROMPT_FILE=''; ENV_FILE=''
MAX_LINES=''; BACKGROUND=0; NETWORK=0; KEYS=''; MODEL=''; REASONING_EFFORT=''
PREFLIGHT=''; MODEL_EVIDENCE=''; LEDGER=''; JOB_ID=''; PHASE='dispatch'; MAX_RETRIES=''
MAX_ROLLOUT_TOKENS=''

while [ $# -gt 0 ]; do
  case "$1" in
    --profile)     PROFILE="${2:-}";     shift 2 ;;
    --mode)        MODE="${2:-}";        shift 2 ;;
    --model)       MODEL="${2:-}";       shift 2 ;;
    --reasoning-effort) REASONING_EFFORT="${2:-}"; shift 2 ;;
    --out)         OUT="${2:-}";         shift 2 ;;
    --log)         LOG="${2:-}";         shift 2 ;;
    --max-lines)   MAX_LINES="${2:-}";   shift 2 ;;
    --prompt)      PROMPT="${2:-}";      shift 2 ;;
    --prompt-file) PROMPT_FILE="${2:-}"; shift 2 ;;
    --env-file)    ENV_FILE="${2:-}";    shift 2 ;;
    --preflight)   PREFLIGHT="${2:-}";   shift 2 ;;
    --model-evidence) MODEL_EVIDENCE="${2:-}"; shift 2 ;;
    --ledger)      LEDGER="${2:-}";      shift 2 ;;
    --job-id)      JOB_ID="${2:-}";      shift 2 ;;
    --phase)       PHASE="${2:-}";       shift 2 ;;
    --max-retries) MAX_RETRIES="${2:-}"; shift 2 ;;
    --max-rollout-tokens) MAX_ROLLOUT_TOKENS="${2:-}"; shift 2 ;;
    --background)  BACKGROUND=1;         shift ;;
    --network)     NETWORK=1;            shift ;;
    --var)
      pair="${2:-}"
      key="${pair%%=*}"; val="${pair#*=}"
      case "$pair" in *=*) ;; *) die "dispatch.sh: --var expects KEY=VALUE (got '$pair')" ;; esac
      case "$key" in *[!A-Z_]*|'') die "dispatch.sh: --var key must be A-Z and underscore (got '$key')" ;; esac
      export "CFV_$key=$val"
      KEYS="$KEYS $key"
      shift 2 ;;
    *) die "dispatch.sh: unknown argument '$1'" ;;
  esac
done

[ -n "$PROFILE" ] || die 'dispatch.sh: --profile is required'
case "$PHASE" in
  dispatch|planning|implementation|verification|review|finalization) ;;
  *) die "dispatch.sh: --phase must be planning, implementation, verification, review, or finalization (got '$PHASE')" ;;
esac
[ -n "$JOB_ID" ] || JOB_ID=$(basename "${OUT:-$LOG}")
[ -n "$JOB_ID" ] || JOB_ID='dispatch'
[ -n "$LEDGER" ] || {
  ledger_source=${OUT:-$LOG}
  case "$ledger_source" in
    *.*) LEDGER=$(printf '%s' "$ledger_source" | sed 's/\.[^.]*$/.ledger/') ;;
    *) LEDGER="$ledger_source.ledger" ;;
  esac
}
case "$MAX_RETRIES" in
  ''|*[!0-9]*) [ -z "$MAX_RETRIES" ] || die "dispatch.sh: --max-retries must be a non-negative integer (got '$MAX_RETRIES')" ;;
esac
case "$MAX_ROLLOUT_TOKENS" in
  '') ;;
  *[!0-9]*) die "dispatch.sh: --max-rollout-tokens must be a positive integer (got '$MAX_ROLLOUT_TOKENS')" ;;
  *) [ "$MAX_ROLLOUT_TOKENS" -gt 0 ] || die "dispatch.sh: --max-rollout-tokens must be a positive integer (got '$MAX_ROLLOUT_TOKENS')" ;;
esac
case "$REASONING_EFFORT" in
  ''|none|low|medium|high|xhigh) ;;
  *) die "dispatch.sh: --reasoning-effort must be none, low, medium, high, or xhigh (got '$REASONING_EFFORT')" ;;
esac
case "$MODE" in
  read-only|workspace-write|danger-full-access) ;;
  *) die "dispatch.sh: --mode must be read-only, workspace-write, or danger-full-access (got '$MODE')" ;;
esac
if [ "$BACKGROUND" -eq 1 ]; then
  [ -n "$LOG" ] || die 'dispatch.sh: --background requires --log'
  [ "$MODE" != read-only ] || die 'dispatch.sh: --background requires --mode workspace-write or danger-full-access'
else
  [ -n "$OUT" ] || die 'dispatch.sh: --out is required unless --background'
fi
if [ "$NETWORK" -eq 1 ] && [ "$MODE" = read-only ]; then
  die 'dispatch.sh: --network applies to --mode workspace-write or danger-full-access only'
fi

# Phase is policy, not only metadata. Read-only phases cannot silently widen permissions, and
# Implementation cannot start unless its model and execution budget are explicit.
case "$PHASE" in
  planning|review|verification)
    [ "$MODE" = read-only ] || die "dispatch.sh: --phase $PHASE requires --mode read-only"
    [ "$BACKGROUND" -eq 0 ] || die "dispatch.sh: --phase $PHASE cannot run in background"
    ;;
  implementation)
    case "$MODE" in
      workspace-write|danger-full-access) ;;
      *) die 'dispatch.sh: --phase implementation requires --mode workspace-write or danger-full-access' ;;
    esac
    [ "$BACKGROUND" -eq 1 ] || die 'dispatch.sh: --phase implementation requires --background'
    [ -n "$MODEL" ] || die 'dispatch.sh: --phase implementation requires explicit --model'
    [ -n "$MAX_ROLLOUT_TOKENS" ] || die 'dispatch.sh: --phase implementation requires --max-rollout-tokens'
    ;;
esac

# Render the prompt.
if [ -n "$PROMPT_FILE" ]; then
  [ -z "$PROMPT" ] || die 'dispatch.sh: use --prompt or --prompt-file, not both'
  [ -f "$PROMPT_FILE" ] || die "dispatch.sh: prompt file not found: $PROMPT_FILE"
  PROMPT=$(awk -v keys="$KEYS" '
    function repl(s, from, to,   out, p) {
      while ((p = index(s, from)) > 0) {
        out = out substr(s, 1, p - 1) to
        s = substr(s, p + length(from))
      }
      return out s
    }
    BEGIN { n = split(keys, k, " ") }
    {
      line = $0
      for (i = 1; i <= n; i++) line = repl(line, "{{" k[i] "}}", ENVIRON["CFV_" k[i]])
      print line
    }' "$PROMPT_FILE")
  # An unfilled placeholder means the dispatched agent gets a literal {{...}} in its instructions.
  # That is a silent wrong-scope build, so stop instead.
  missing=$(printf '%s\n' "$PROMPT" | grep -o '{{[A-Z_]*}}' | sort -u | tr '\n' ' ' || true)
  [ -z "$missing" ] || die "dispatch.sh: unfilled placeholders in $PROMPT_FILE: $missing"
fi
[ -n "$PROMPT" ] || die 'dispatch.sh: --prompt or --prompt-file is required'

# ---------------------------------------------------------------------------
# Profile resolution
#
# ~/.aimux/config.yaml is aimux's own machine-readable source of truth (aimux 0.25.0). `aimux
# profile list` renders a decorated table only — there is no --json. The format is block-style
# YAML: a two-space-indented profile key under `profiles:`, then four-space `key: value` lines,
# until the indentation returns to column 0. aimux owns this file; if its format changes this
# parser is the framework fix, and the regression test's fake config.yaml is what surfaces it.
# Only `cli` is read here — `aimux run` resolves the profile's own config directory itself.
# ---------------------------------------------------------------------------

AIMUX_CONFIG="${AIMUX_CONFIG:-$HOME/.aimux/config.yaml}"

# Echo the `cli` value for profile $1, or nothing if the profile is absent from config.yaml.
profile_cli() {
  [ -f "$AIMUX_CONFIG" ] || return 0
  awk -v want="$1" '
    $0 == "profiles:" { inp = 1; next }
    inp && /^[^ ]/ { exit }
    inp && /^  [A-Za-z0-9._-]+:[ ]*$/ {
      pname = $1; sub(/:$/, "", pname)
      cur = (pname == want)
      next
    }
    inp && cur && /^    cli:[ ]/ {
      v = $0; sub(/^    cli:[ ]*/, "", v)
      print v
      exit
    }
  ' "$AIMUX_CONFIG"
}

# Echo the profile's configured model when aimux exposes it in the profile block.
profile_model() {
  [ -f "$AIMUX_CONFIG" ] || return 0
  awk -v want="$1" '
    $0 == "profiles:" { inp = 1; next }
    inp && /^[^ ]/ { exit }
    inp && /^  [A-Za-z0-9._-]+:[ ]*$/ {
      pname = $1; sub(/:$/, "", pname)
      cur = (pname == want)
      next
    }
    inp && cur && /^    model:[ ]/ {
      v = $0; sub(/^    model:[ ]*/, "", v)
      print v
      exit
    }
  ' "$AIMUX_CONFIG"
}

POOL=$(printf '%s' "$PROFILE" | tr ',' ' ')
remaining_pool="$POOL"
RESOLVED_PROFILE=''; RESOLVED_CLI=''; BARE_CLI=''; TARGET_KIND=''
PROFILE_MODEL=''; EFFECTIVE_MODEL=''
missing_log=''; deferred_bare=''; bare_used=0

# Pop the next attempt target off remaining_pool. On success sets TARGET_KIND and either
# RESOLVED_PROFILE + RESOLVED_CLI (a real aimux profile) or BARE_CLI + RESOLVED_CLI (the cli:NAME
# fallback, always tried last regardless of its position in the pool). Returns 1 when nothing is
# left. Every skipped profile name is recorded in missing_log.
advance_target() {
  RESOLVED_PROFILE=''; RESOLVED_CLI=''; TARGET_KIND=''
  while [ -n "$remaining_pool" ]; do
    entry=${remaining_pool%% *}
    case "$remaining_pool" in
      *' '*) remaining_pool=${remaining_pool#* } ;;
      *) remaining_pool='' ;;
    esac
    [ -n "$entry" ] || continue
    case "$entry" in
      cli:*)
        [ -n "$deferred_bare" ] || deferred_bare=${entry#cli:}
        continue ;;
    esac
    c=$(profile_cli "$entry")
    if [ -n "$c" ]; then
      RESOLVED_PROFILE="$entry"; RESOLVED_CLI="$c"; TARGET_KIND=profile
      PROFILE_MODEL=$(profile_model "$entry")
      return 0
    fi
    missing_log="$missing_log $entry"
  done
  if [ -n "$deferred_bare" ] && [ "$bare_used" -eq 0 ]; then
    bare_used=1
    BARE_CLI="$deferred_bare"; RESOLVED_CLI="$deferred_bare"; TARGET_KIND=bare
    PROFILE_MODEL=''
    return 0
  fi
  return 1
}

target_label() {
  if [ "$TARGET_KIND" = bare ]; then printf 'cli:%s' "$BARE_CLI"; else printf '%s' "$RESOLVED_PROFILE"; fi
}

advance_target || die "dispatch.sh: no profile in pool [$PROFILE] found in $AIMUX_CONFIG — add one with 'aimux profile add <name> --cli <cli>' or pass a cli:<name> fallback entry"

LAST_LABEL=$(target_label)
LAST_KIND=$TARGET_KIND

# ---------------------------------------------------------------------------
# Adapter: (mode, network, out, prompt) -> argv for the resolved CLI. Only codex is implemented.
# Adding gemini / claude / opencode is one more `case` arm here and in the background child below;
# levels, plan, journal, budgets and gates are unaffected.
# ---------------------------------------------------------------------------

adapter_check() {
  case "$RESOLVED_CLI" in
    codex) ;;
    *)
      if [ -n "$RESOLVED_PROFILE" ]; then
        die "dispatch.sh: profile '$RESOLVED_PROFILE' uses cli '$RESOLVED_CLI', which has no dispatch adapter (supported: codex)"
      fi
      die "dispatch.sh: cli '$RESOLVED_CLI' has no dispatch adapter (supported: codex)" ;;
  esac
  if [ -n "$RESOLVED_PROFILE" ]; then
    command -v aimux >/dev/null 2>&1 || die "dispatch.sh: aimux not on PATH (needed for profile '$RESOLVED_PROFILE')"
  fi
  command -v codex >/dev/null 2>&1 || die 'dispatch.sh: codex not on PATH'
}

# Native Codex JSONL usage is accumulated across retries. Environment-provided CF_* token fields
# remain a compatibility fallback for adapters/runtimes that do not expose usage events.
USAGE_AVAILABLE=0
USAGE_INPUT=0
USAGE_CACHED_INPUT=0
USAGE_CACHE_WRITE_INPUT=0
USAGE_OUTPUT=0
USAGE_REASONING_OUTPUT=0

json_number() {
  printf '%s\n' "$1" | sed -n "s/.*\"$2\":[[:space:]]*\([0-9][0-9]*\).*/\\1/p"
}

accumulate_usage() {
  _events=$1
  [ -r "$_events" ] || return 0
  while IFS= read -r _line; do
    case "$_line" in
      *'\"type\":\"turn.completed\"'*|*'\"type\": \"turn.completed\"'*)
        _input=$(json_number "$_line" input_tokens)
        _cached=$(json_number "$_line" cached_input_tokens)
        _cache_write=$(json_number "$_line" cache_write_input_tokens)
        _output=$(json_number "$_line" output_tokens)
        _reasoning=$(json_number "$_line" reasoning_output_tokens)
        [ -n "$_input" ] || continue
        USAGE_AVAILABLE=1
        USAGE_INPUT=$((USAGE_INPUT + _input))
        USAGE_CACHED_INPUT=$((USAGE_CACHED_INPUT + ${_cached:-0}))
        USAGE_CACHE_WRITE_INPUT=$((USAGE_CACHE_WRITE_INPUT + ${_cache_write:-0}))
        USAGE_OUTPUT=$((USAGE_OUTPUT + ${_output:-0}))
        USAGE_REASONING_OUTPUT=$((USAGE_REASONING_OUTPUT + ${_reasoning:-0}))
        ;;
    esac
  done < "$_events"
}

# One foreground attempt with the current target. `set --` sets this function's own positional
# parameters, not the caller's. Reads MODE, NETWORK, MODEL, OUT and PROMPT from above.
run_cli() {
  _rc=0
  adapter_check
  case "$RESOLVED_CLI" in
    codex)
      if [ -n "$RESOLVED_PROFILE" ]; then
        set -- aimux run "$RESOLVED_PROFILE"
        [ -z "$MODEL" ] || set -- "$@" -m "$MODEL"
        set -- "$@" -- codex -a never
        [ -z "$REASONING_EFFORT" ] || set -- "$@" -c "model_reasoning_effort=$REASONING_EFFORT"
        [ -z "$MAX_ROLLOUT_TOKENS" ] || set -- "$@" -c "features.rollout_budget={enabled=true,limit_tokens=$MAX_ROLLOUT_TOKENS,reminder_at_remaining_tokens=[],sampling_token_weight=1.0,prefill_token_weight=1.0}"
        [ "$NETWORK" -eq 0 ] || set -- "$@" -c 'sandbox_workspace_write.network_access=true'
        set -- "$@" exec --json -s "$MODE"
        [ -z "$MODEL" ] || set -- "$@" -m "$MODEL"
        set -- "$@" -o "$OUT" "$PROMPT"
      else
        set -- codex -a never
        [ -z "$REASONING_EFFORT" ] || set -- "$@" -c "model_reasoning_effort=$REASONING_EFFORT"
        [ -z "$MAX_ROLLOUT_TOKENS" ] || set -- "$@" -c "features.rollout_budget={enabled=true,limit_tokens=$MAX_ROLLOUT_TOKENS,reminder_at_remaining_tokens=[],sampling_token_weight=1.0,prefill_token_weight=1.0}"
        [ "$NETWORK" -eq 0 ] || set -- "$@" -c 'sandbox_workspace_write.network_access=true'
        set -- "$@" exec --json -s "$MODE"
        [ -z "$MODEL" ] || set -- "$@" -m "$MODEL"
        set -- "$@" -o "$OUT" "$PROMPT"
      fi
      RAW_ATTEMPT_LOG="$OUT.attempt-${attempt_count:-1}.log"
      EVENTS_ATTEMPT="$OUT.attempt-${attempt_count:-1}.jsonl"
      rm -f "$OUT" "$RAW_ATTEMPT_LOG" "$EVENTS_ATTEMPT"
      "$@" >"$EVENTS_ATTEMPT" 2>"$RAW_ATTEMPT_LOG" || _rc=$?
      accumulate_usage "$EVENTS_ATTEMPT"
      ;;
  esac
  return "$_rc"
}

if [ -n "$ENV_FILE" ]; then
  [ -f "$ENV_FILE" ] || die "dispatch.sh: env file not found: $ENV_FILE"
  [ -r "$ENV_FILE" ] || die "dispatch.sh: env file not readable: $ENV_FILE"
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

adapter_check

run_preflight() {
  if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    printf '%s\n' 'dispatch.sh: preflight failed: current directory is not a Git repository' >&2
    return 78
  fi
  git_dir=$(git rev-parse --git-dir 2>/dev/null) || return 78
  [ ! -e "$git_dir/index.lock" ] || {
    printf '%s\n' "dispatch.sh: preflight failed: Git index lock exists at $git_dir/index.lock" >&2
    return 78
  }
  if [ -n "$PREFLIGHT" ]; then
    [ -r "$PREFLIGHT" ] || die "dispatch.sh: preflight file not readable: $PREFLIGHT"
    sh "$PREFLIGHT"
  fi
}

failure_class='none'
retryable=0
model_policy='profile-default'
[ -n "$MODEL" ] && model_policy='pinned'
classify_output() {
  failure_class='unknown'
  retryable=0
  [ -f "$1" ] || return 0
  if grep -Eiq 'shared rollout token budget exhausted|rollout.?budget.*exhaust' "$1"; then
    failure_class='budget'; retryable=0
  elif grep -Eiq 'rate.?limit|too many requests|quota exceeded|temporarily unavailable|server overloaded|try again later' "$1"; then
    failure_class='environment.rate_limit'; retryable=1
  elif grep -Eiq 'timeout|timed out|deadline exceeded' "$1"; then
    failure_class='timeout'; retryable=1
  elif grep -Eiq 'permission denied|sandbox|approval|not writable|index\.lock|connection attempt failed|connection refused|could not connect' "$1"; then
    failure_class='environment'; retryable=0
  elif grep -Eiq 'unknown model|model.*not found|unrecognized.*argument|invalid.*model' "$1"; then
    failure_class='model-routing'; retryable=0
  elif grep -Eiq 'invalid configuration|configuration.*invalid|profile.*not found|missing.*configuration' "$1"; then
    failure_class='configuration'; retryable=0
  elif grep -Eiq 'unfilled placeholder|scope.*incomplete|blocking question|plan.*wrong' "$1"; then
    failure_class='plan'; retryable=0
  elif grep -Eiq 'test.*fail|failures?: [1-9]|errors?: [1-9]|compilation failure' "$1"; then
    failure_class='verification'; retryable=0
  elif grep -Eiq 'implementation failed|cannot implement|code change failed' "$1"; then
    failure_class='implementation'; retryable=0
  fi
}

classify_attempt() {
  _combined="$TMP_ROOT/classify-${attempt_count:-1}.log"
  : > "$_combined"
  if [ -n "${RAW_ATTEMPT_LOG:-}" ] && [ -f "$RAW_ATTEMPT_LOG" ]; then
    cat "$RAW_ATTEMPT_LOG" >> "$_combined"
  fi
  if [ -n "${EVENTS_ATTEMPT:-}" ] && [ -f "$EVENTS_ATTEMPT" ]; then
    cat "$EVENTS_ATTEMPT" >> "$_combined"
  fi
  if [ -f "$OUT" ]; then
    cat "$OUT" >> "$_combined"
  fi
  classify_output "$_combined"
}

write_ledger() {
  [ -n "$LEDGER" ] || return 0
  mkdir -p "$(dirname "$LEDGER")"
  _input=${CF_INPUT_TOKENS:-unavailable}
  _cached=${CF_CACHED_INPUT_TOKENS:-unavailable}
  _cache_write=${CF_CACHE_WRITE_INPUT_TOKENS:-unavailable}
  _output=${CF_OUTPUT_TOKENS:-unavailable}
  _reasoning=${CF_REASONING_OUTPUT_TOKENS:-unavailable}
  _total=${CF_TOTAL_TOKENS:-unavailable}
  if [ "$USAGE_AVAILABLE" -eq 1 ]; then
    _input=$USAGE_INPUT
    _cached=$USAGE_CACHED_INPUT
    _cache_write=$USAGE_CACHE_WRITE_INPUT
    _output=$USAGE_OUTPUT
    _reasoning=$USAGE_REASONING_OUTPUT
    _total=$((USAGE_INPUT + USAGE_OUTPUT))
  fi
  printf 'job_id\tstatus\tphase\tprofile\tcli\trequested_model\teffective_model\treasoning_effort\trollout_budget_tokens\tattempts\tretryable\tfailure_class\tmodel_policy\tinput_tokens\tcached_input_tokens\tcache_write_input_tokens\toutput_tokens\treasoning_output_tokens\ttotal_tokens\texit_status\n' > "$LEDGER"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$JOB_ID" "$1" "${PHASE:-dispatch}" "$LAST_LABEL" "$RESOLVED_CLI" \
    "${MODEL:-profile-default}" "$EFFECTIVE_MODEL" "${REASONING_EFFORT:-profile-default}" \
    "${MAX_ROLLOUT_TOKENS:-unbounded}" "${attempt_count:-0}" "$retryable" "$failure_class" "$model_policy" \
    "$_input" "$_cached" "$_cache_write" "$_output" "$_reasoning" "$_total" "$2" >> "$LEDGER"
}

if ! run_preflight >"$TMP_ROOT/preflight.out" 2>&1; then
  failure_class='environment.preflight'
  retryable=0
  cat "$TMP_ROOT/preflight.out" >&2
  EFFECTIVE_MODEL="$MODEL"
  [ -n "$EFFECTIVE_MODEL" ] || EFFECTIVE_MODEL="$PROFILE_MODEL"
  [ -n "$EFFECTIVE_MODEL" ] || EFFECTIVE_MODEL='profile-default'
  write_ledger blocked 78
  printf 'DISPATCH exit=78  profile=%s  cli=%s  model=%s  reasoning_effort=%s  rollout_budget=%s  mode=%s  failure_class=%s  out=%s  lines=0  budget=n/a\n' \
    "$LAST_LABEL" "$RESOLVED_CLI" "$EFFECTIVE_MODEL" "${REASONING_EFFORT:-profile-default}" "${MAX_ROLLOUT_TOKENS:-unbounded}" "$MODE" "$failure_class"
  exit 78
fi

# Note for the FALLBACK: line. Recomputed after the read-only retry loop with the full attempt log;
# set here too because the background path exits before that recompute.
note=''
if [ "$LAST_KIND" = bare ]; then
  note="FALLBACK: no aimux profile in [$PROFILE] resolved — ran cli '$BARE_CLI' directly; cost is NOT separated"
elif [ -n "$missing_log" ]; then
  note="FALLBACK: profile(s)$missing_log not in $AIMUX_CONFIG, used '$RESOLVED_PROFILE' instead"
fi

if [ "$BACKGROUND" -eq 1 ]; then
  # No retry here even on a pool: a killed or failed build cannot be safely re-launched on another
  # profile without knowing what it already wrote. The pool only decides the starting profile.
  exit_file="$(printf '%s' "$LOG" | sed 's/\.log$//').exit"
  rm -f "$exit_file"
  CFD_PROFILE=$RESOLVED_PROFILE
  CFD_CLI=$RESOLVED_CLI
  CFD_MODE=$MODE
  CFD_MODEL=$MODEL
  CFD_REASONING_EFFORT=$REASONING_EFFORT
  CFD_MAX_ROLLOUT_TOKENS=$MAX_ROLLOUT_TOKENS
  CFD_MODEL_EVIDENCE=$MODEL_EVIDENCE
  CFD_LOG=$LOG
  CFD_EVENTS="$LOG.events.jsonl"
  CFD_EFFECTIVE_MODEL=$MODEL
  [ -n "$CFD_EFFECTIVE_MODEL" ] || CFD_EFFECTIVE_MODEL=$PROFILE_MODEL
  [ -n "$CFD_EFFECTIVE_MODEL" ] || CFD_EFFECTIVE_MODEL='profile-default'
  CFD_NETWORK=$NETWORK
  CFD_PROMPT=$PROMPT
  CFD_EXIT_FILE=$exit_file
  CFD_LEDGER=$LEDGER
  CFD_PHASE=$PHASE
  CFD_JOB_ID=$JOB_ID
  export CFD_PROFILE CFD_CLI CFD_MODE CFD_MODEL CFD_REASONING_EFFORT CFD_MAX_ROLLOUT_TOKENS CFD_MODEL_EVIDENCE CFD_LOG CFD_EVENTS CFD_EFFECTIVE_MODEL CFD_NETWORK CFD_PROMPT CFD_EXIT_FILE CFD_LEDGER CFD_JOB_ID CFD_PHASE
  # The child rebuilds the argv rather than inheriting a command string: a background dispatch
  # survives this process, so the adapter has to run where the command actually runs.
  nohup sh -c '
    printf "%s\n" "DISPATCH child started"
    status=0
    case "$CFD_CLI" in
      codex)
        if [ -n "$CFD_PROFILE" ]; then
          set -- aimux run "$CFD_PROFILE"
          [ -z "$CFD_MODEL" ] || set -- "$@" -m "$CFD_MODEL"
          set -- "$@" -- codex -a never
          [ -z "$CFD_REASONING_EFFORT" ] || set -- "$@" -c "model_reasoning_effort=$CFD_REASONING_EFFORT"
          [ -z "$CFD_MAX_ROLLOUT_TOKENS" ] || set -- "$@" -c "features.rollout_budget={enabled=true,limit_tokens=$CFD_MAX_ROLLOUT_TOKENS,reminder_at_remaining_tokens=[],sampling_token_weight=1.0,prefill_token_weight=1.0}"
          [ "$CFD_NETWORK" -eq 0 ] || set -- "$@" -c "sandbox_workspace_write.network_access=true"
          set -- "$@" exec --json -s "$CFD_MODE"
          [ -z "$CFD_MODEL" ] || set -- "$@" -m "$CFD_MODEL"
          set -- "$@" "$CFD_PROMPT"
        else
          set -- codex -a never
          [ -z "$CFD_REASONING_EFFORT" ] || set -- "$@" -c "model_reasoning_effort=$CFD_REASONING_EFFORT"
          [ -z "$CFD_MAX_ROLLOUT_TOKENS" ] || set -- "$@" -c "features.rollout_budget={enabled=true,limit_tokens=$CFD_MAX_ROLLOUT_TOKENS,reminder_at_remaining_tokens=[],sampling_token_weight=1.0,prefill_token_weight=1.0}"
          [ "$CFD_NETWORK" -eq 0 ] || set -- "$@" -c "sandbox_workspace_write.network_access=true"
          set -- "$@" exec --json -s "$CFD_MODE"
          [ -z "$CFD_MODEL" ] || set -- "$@" -m "$CFD_MODEL"
          set -- "$@" "$CFD_PROMPT"
        fi
        rm -f "$CFD_EVENTS"
        "$@" >"$CFD_EVENTS" 2>>"$CFD_LOG" || status=$?
        ;;
      *) printf "%s\n" "dispatch child: cli $CFD_CLI has no adapter" >&2; status=2 ;;
    esac
    failure_class=none
    retryable=0
    model_policy=profile-default
    [ -n "$CFD_MODEL" ] && model_policy=pinned
    if [ "$status" -ne 0 ]; then
      if grep -Eiq "shared rollout token budget exhausted|rollout.?budget.*exhaust" "$CFD_LOG" "$CFD_EVENTS" 2>/dev/null; then
        failure_class=budget
      elif grep -Eiq "rate.?limit|too many requests|quota exceeded|temporarily unavailable|server overloaded|try again later" "$CFD_LOG" "$CFD_EVENTS" 2>/dev/null; then
        failure_class=environment.rate_limit
      elif grep -Eiq "timeout|timed out|deadline exceeded" "$CFD_LOG" "$CFD_EVENTS" 2>/dev/null; then
        failure_class=timeout
      elif grep -Eiq "unknown model|model.*not found|invalid.*model" "$CFD_LOG" "$CFD_EVENTS" 2>/dev/null; then
        failure_class=model-routing
      else
        failure_class=unknown
      fi
    fi
    if [ "$status" -eq 0 ] && [ -n "$CFD_MODEL_EVIDENCE" ]; then
      if [ ! -r "$CFD_MODEL_EVIDENCE" ]; then
        printf "%s\n" "dispatch child: model evidence file not readable: $CFD_MODEL_EVIDENCE" >&2
        status=78; failure_class=model-routing; model_policy=failed
      else
        observed_models=$(sed "/^[[:space:]]*$/d" "$CFD_MODEL_EVIDENCE" | tr "\\n" "," | sed "s/,$//")
        if [ -z "$observed_models" ] || sed "/^[[:space:]]*$/d" "$CFD_MODEL_EVIDENCE" | grep -Fvx "$CFD_EFFECTIVE_MODEL" >/dev/null; then
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
          *"\"type\":\"turn.completed\""*|*"\"type\": \"turn.completed\""*)
            n=$(printf "%s\n" "$line" | sed -n "s/.*\"input_tokens\":[[:space:]]*\([0-9][0-9]*\).*/\\1/p")
            [ -n "$n" ] || continue
            c=$(printf "%s\n" "$line" | sed -n "s/.*\"cached_input_tokens\":[[:space:]]*\([0-9][0-9]*\).*/\\1/p")
            w=$(printf "%s\n" "$line" | sed -n "s/.*\"cache_write_input_tokens\":[[:space:]]*\([0-9][0-9]*\).*/\\1/p")
            o=$(printf "%s\n" "$line" | sed -n "s/.*\"output_tokens\":[[:space:]]*\([0-9][0-9]*\).*/\\1/p")
            q=$(printf "%s\n" "$line" | sed -n "s/.*\"reasoning_output_tokens\":[[:space:]]*\([0-9][0-9]*\).*/\\1/p")
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
    printf "%s\n" "$status" > "$CFD_EXIT_FILE"
    if [ -n "$CFD_LEDGER" ]; then
      printf 'job_id\tstatus\tphase\tprofile\tcli\trequested_model\teffective_model\treasoning_effort\trollout_budget_tokens\tattempts\tretryable\tfailure_class\tmodel_policy\tinput_tokens\tcached_input_tokens\tcache_write_input_tokens\toutput_tokens\treasoning_output_tokens\ttotal_tokens\texit_status\n' > "$CFD_LEDGER"
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t1\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$CFD_JOB_ID" "$([ "$status" -eq 0 ] && printf passed || printf failed)" "$CFD_PHASE" \
        "${CFD_PROFILE:-cli:$CFD_CLI}" "$CFD_CLI" "${CFD_MODEL:-profile-default}" \
        "$CFD_EFFECTIVE_MODEL" "${CFD_REASONING_EFFORT:-profile-default}" \
        "${CFD_MAX_ROLLOUT_TOKENS:-unbounded}" "$retryable" "$failure_class" "$model_policy" \
        "$input_tokens" "$cached_input_tokens" "$cache_write_input_tokens" "$output_tokens" \
        "$reasoning_output_tokens" "$total_tokens" "$status" >> "$CFD_LEDGER"
    fi
    exit "$status"
  ' dispatch-bg > "$LOG" 2>&1 < /dev/null &
  printf 'DISPATCH started  profile=%s  cli=%s  model=%s  reasoning_effort=%s  rollout_budget=%s  mode=%s  pid=%s  log=%s  sentinel=%s\n' \
    "$LAST_LABEL" "$RESOLVED_CLI" "$CFD_EFFECTIVE_MODEL" "${REASONING_EFFORT:-profile-default}" "${MAX_ROLLOUT_TOKENS:-unbounded}" "$MODE" "$!" "$LOG" "$exit_file"
  [ -z "$note" ] || printf '%s\n' "$note"
  exit 0
fi

status=0
attempt_count=1
run_cli || status=$?
attempt_log=" $LAST_LABEL=exit$status"
classify_attempt

# Retry the pool only for read-only dispatch — no side effects, so a second attempt under another
# profile is safe. workspace-write never reaches this loop (background exits above).
if [ "$MODE" = read-only ]; then
  while [ "$status" -ne 0 ] && [ "$retryable" -eq 1 ]; do
    if [ -n "$MAX_RETRIES" ] && [ "$attempt_count" -gt "$MAX_RETRIES" ]; then break; fi
    advance_target || break
    LAST_LABEL=$(target_label)
    LAST_KIND=$TARGET_KIND
    status=0
    attempt_count=$((attempt_count + 1))
    run_cli || status=$?
    attempt_log="$attempt_log $LAST_LABEL=exit$status"
    classify_attempt
  done
fi

retry_count=$(printf '%s' "$attempt_log" | wc -w | tr -d ' ')
EFFECTIVE_MODEL="$MODEL"
[ -n "$EFFECTIVE_MODEL" ] || EFFECTIVE_MODEL="$PROFILE_MODEL"
[ -n "$EFFECTIVE_MODEL" ] || EFFECTIVE_MODEL='profile-default'
failure_class='none'
if [ "$status" -ne 0 ]; then
  classify_attempt
fi

if [ "$status" -eq 0 ] && [ -n "$MODEL_EVIDENCE" ]; then
  [ -r "$MODEL_EVIDENCE" ] || die "dispatch.sh: model evidence file not readable: $MODEL_EVIDENCE"
  observed_models=$(sed '/^[[:space:]]*$/d' "$MODEL_EVIDENCE" | tr '\n' ',' | sed 's/,$//')
  if [ -z "$observed_models" ] || sed '/^[[:space:]]*$/d' "$MODEL_EVIDENCE" | grep -Fvx "$EFFECTIVE_MODEL" >/dev/null; then
    status=78
    failure_class='model-routing'
    retryable=0
    model_policy='failed'
  else
    model_policy='passed'
  fi
fi
if [ "$LAST_KIND" = bare ]; then
  note="FALLBACK: no profile in [$PROFILE] completed — ran cli '$BARE_CLI' directly (tried$attempt_log); cost is NOT separated"
elif [ -n "$missing_log" ]; then
  note="FALLBACK: profile(s)$missing_log not in $AIMUX_CONFIG, used '$LAST_LABEL' instead (tried$attempt_log)"
elif [ "$retry_count" -gt 1 ]; then
  note="FALLBACK: retried across the pool (tried$attempt_log), used '$LAST_LABEL'"
fi

lines=0
[ -f "$OUT" ] && lines=$(wc -l < "$OUT" | tr -d ' ')

budget='n/a'
if [ -n "$MAX_LINES" ]; then
  if [ "$lines" -gt "$MAX_LINES" ]; then
    budget="OVER BUDGET ($lines/$MAX_LINES) — read the first $MAX_LINES lines only, note the truncation"
  else
    budget="within budget ($lines/$MAX_LINES)"
  fi
fi

printf 'DISPATCH exit=%s  profile=%s  cli=%s  model=%s  reasoning_effort=%s  rollout_budget=%s  mode=%s  failure_class=%s  out=%s  lines=%s  budget=%s\n' \
  "$status" "$LAST_LABEL" "$RESOLVED_CLI" "$EFFECTIVE_MODEL" "${REASONING_EFFORT:-profile-default}" "${MAX_ROLLOUT_TOKENS:-unbounded}" "$MODE" "$failure_class" "$OUT" "$lines" "$budget"
[ -z "$note" ] || printf '%s\n' "$note"
write_ledger "$([ "$status" -eq 0 ] && printf passed || printf failed)" "$status"
exit "$status"
