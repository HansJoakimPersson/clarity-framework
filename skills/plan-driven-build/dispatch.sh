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
#               [--max-rollout-tokens N] [--artifacts-dir DIR]
#               [--stall-timeout-seconds N] [--wall-timeout-seconds N]
#   dispatch.sh --profile NAME[,NAME...]
#               --mode workspace-write|danger-full-access
#               (--prompt-file FILE [--var KEY=VALUE ...] | --prompt TEXT) [--model NAME]
#               --log FILE --background [--network] [--env-file FILE]
#               [--model-evidence FILE] [--max-rollout-tokens N]
#               [--stall-timeout-seconds N] [--wall-timeout-seconds N] [--heartbeat-seconds N]
#               [--protect FILE ...]
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
# Background mode is supervised. The supervisor writes:
#   LOG with .log replaced by .exit       completion exit code
#   LOG with .log replaced by .health     liveness/progress state, token usage so far
#   LOG with .log replaced by .final.md   the agent's final message
#   LOG with .log replaced by .report.md  the agent's own step-by-step build report
#   LOG.events.jsonl                      native CLI event stream
# and, when the worker ends, appends a readable summary to LOG itself: exit status, failure class,
# whether the build report marks every step complete, files that are new since launch, the last
# events in plain text, and the final message. `tail -30 LOG` is therefore enough to diagnose a
# failed build; `dispatch-tail.sh` prints more of the event stream on demand.
#
# A second background dispatch on the same --log does not overwrite the first: the earlier log,
# sentinel, health, events, report, and ledger move to `<log dir>/attempts/<name>-N/` before launch,
# and a launch is refused while a supervisor for that log is still alive.
#
# --protect FILE (repeatable, background only) snapshots a file the worker must not change — the
# run journal above all. If the worker changes or deletes it, the supervisor restores the snapshot
# and reports the violation in LOG. Role separation is otherwise only as strong as the prompt.
#
# Foreground dispatches run with stdin closed and under the same two ceilings as background ones:
# no observable output for --stall-timeout-seconds (foreground default 900) or a total runtime over
# --wall-timeout-seconds (foreground default 3600) ends the attempt with exit 124 and
# failure_class timeout.stalled / timeout.wall. For a read-only dispatch that is retryable, so the
# next profile in the pool takes over instead of the orchestrator waiting on a silent process.
#
# Raw per-attempt files (`*.attempt-N.jsonl`, `*.attempt-N.log`) and the default ledger never land
# beside a tracked --out. When --out is already inside a `.runs/` directory they stay beside it;
# otherwise they go to `<out dir>/.runs/<out name without extension>/`. --artifacts-dir overrides.
# It polls the worker at --heartbeat-seconds (default 30), terminates a worker whose observable
# log/event output has made no progress for --stall-timeout-seconds (default 1800), and enforces a
# hard --wall-timeout-seconds ceiling (default 7200). Timeout termination writes exit 124 and a
# classified ledger entry, so a hung CLI eventually becomes a normal recoverable workflow event
# instead of waiting forever. The supervisor itself runs under `nohup` so the worker is not tied to
# the short-lived launcher shell.
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

SKILLDIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

die() { printf '%s\n' "$1" >&2; exit 2; }

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/clarity-dispatch.XXXXXX")
cleanup() {
  [ -z "${FG_WORKER_PID:-}" ] || kill -TERM "$FG_WORKER_PID" 2>/dev/null || true
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT
trap 'cleanup; exit 130' HUP INT TERM

PROFILE=''; MODE=''; OUT=''; LOG=''; PROMPT=''; PROMPT_FILE=''; ENV_FILE=''
MAX_LINES=''; BACKGROUND=0; NETWORK=0; KEYS=''; MODEL=''; REASONING_EFFORT=''
PREFLIGHT=''; MODEL_EVIDENCE=''; LEDGER=''; JOB_ID=''; PHASE='dispatch'; MAX_RETRIES=''
MAX_ROLLOUT_TOKENS=''; ARTIFACTS_DIR=''; PROTECT=''
STALL_TIMEOUT_SECONDS=''; WALL_TIMEOUT_SECONDS=''; HEARTBEAT_SECONDS=30

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
    --stall-timeout-seconds) STALL_TIMEOUT_SECONDS="${2:-}"; shift 2 ;;
    --wall-timeout-seconds) WALL_TIMEOUT_SECONDS="${2:-}"; shift 2 ;;
    --heartbeat-seconds) HEARTBEAT_SECONDS="${2:-}"; shift 2 ;;
    --artifacts-dir) ARTIFACTS_DIR="${2:-}"; shift 2 ;;
    --protect)
      [ -n "${2:-}" ] || die 'dispatch.sh: --protect expects a file path'
      case "$2" in *"
"*) die 'dispatch.sh: --protect path must be a single line' ;; esac
      PROTECT="${PROTECT}${2}
"
      shift 2 ;;
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

# Raw attempt files and the default ledger are run scratch. Keep them out of a tracked directory:
# beside --out only when --out already lives under `.runs/`, otherwise in a `.runs/` sibling.
if [ -z "$ARTIFACTS_DIR" ] && [ -n "$OUT" ]; then
  out_dir=$(dirname "$OUT")
  case "$out_dir/" in
    */.runs/*|.runs/*) ARTIFACTS_DIR=$out_dir ;;
    *)
      out_stem=$(basename "$OUT")
      case "$out_stem" in ?*.*) out_stem=${out_stem%.*} ;; esac
      ARTIFACTS_DIR="$out_dir/.runs/$out_stem" ;;
  esac
fi
[ -n "$ARTIFACTS_DIR" ] || ARTIFACTS_DIR=$(dirname "${LOG:-.}")
[ -n "$LEDGER" ] || {
  if [ -n "$OUT" ]; then
    ledger_name=$(basename "$OUT")
    case "$ledger_name" in ?*.*) ledger_name=${ledger_name%.*} ;; esac
    LEDGER="$ARTIFACTS_DIR/$ledger_name.ledger"
  else
    case "$LOG" in
      *.*) LEDGER=$(printf '%s' "$LOG" | sed 's/\.[^.]*$/.ledger/') ;;
      *) LEDGER="$LOG.ledger" ;;
    esac
  fi
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
# A background build may legitimately think for a long time; a foreground read-only pass may not.
if [ "$BACKGROUND" -eq 1 ]; then
  [ -n "$STALL_TIMEOUT_SECONDS" ] || STALL_TIMEOUT_SECONDS=1800
  [ -n "$WALL_TIMEOUT_SECONDS" ] || WALL_TIMEOUT_SECONDS=7200
else
  [ -n "$STALL_TIMEOUT_SECONDS" ] || STALL_TIMEOUT_SECONDS=900
  [ -n "$WALL_TIMEOUT_SECONDS" ] || WALL_TIMEOUT_SECONDS=3600
fi
for timeout_spec in "stall:$STALL_TIMEOUT_SECONDS" "wall:$WALL_TIMEOUT_SECONDS" "heartbeat:$HEARTBEAT_SECONDS"; do
  timeout_name=${timeout_spec%%:*}
  timeout_value=${timeout_spec#*:}
  case "$timeout_value" in
    ''|*[!0-9]*) die "dispatch.sh: watchdog values must be positive integers (got $timeout_name=$timeout_value)" ;;
    *) [ "$timeout_value" -gt 0 ] || die "dispatch.sh: watchdog values must be positive integers (got $timeout_name=$timeout_value)" ;;
  esac
done
# The heartbeat cadence only exists for a supervised background worker.
if [ "$BACKGROUND" -eq 1 ]; then
  [ "$STALL_TIMEOUT_SECONDS" -ge "$HEARTBEAT_SECONDS" ] || die 'dispatch.sh: --stall-timeout-seconds must be >= --heartbeat-seconds'
  [ "$WALL_TIMEOUT_SECONDS" -ge "$HEARTBEAT_SECONDS" ] || die 'dispatch.sh: --wall-timeout-seconds must be >= --heartbeat-seconds'
fi
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
if [ -n "$PROTECT" ] && [ "$BACKGROUND" -eq 0 ]; then
  die 'dispatch.sh: --protect applies to --background dispatches only'
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

# A background worker keeps its own step-by-step report at a path the supervisor also knows, so a
# budget stop still leaves a handoff. The path is offered to every background prompt as
# {{BUILD_REPORT}}; a caller may override it with --var BUILD_REPORT=...
BUILD_REPORT=''
if [ "$BACKGROUND" -eq 1 ]; then
  case " $KEYS " in
    *' BUILD_REPORT '*) BUILD_REPORT=$CFV_BUILD_REPORT ;;
    *)
      BUILD_REPORT="$(printf '%s' "$LOG" | sed 's/\.log$//').report.md"
      export "CFV_BUILD_REPORT=$BUILD_REPORT"
      KEYS="$KEYS BUILD_REPORT" ;;
  esac
fi

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

available_profiles() {
  [ -f "$AIMUX_CONFIG" ] || { printf 'none (%s does not exist)' "$AIMUX_CONFIG"; return 0; }
  _found=$(awk '
    $0 == "profiles:" { inp = 1; next }
    inp && /^[^ ]/ { exit }
    inp && /^  [A-Za-z0-9._-]+:[ ]*$/ { n = $1; sub(/:$/, "", n); printf "%s%s", sep, n; sep = ", " }
  ' "$AIMUX_CONFIG")
  printf '%s' "${_found:-none}"
}

advance_target || die "dispatch.sh: configuration: no profile in pool [$PROFILE] found in $AIMUX_CONFIG. Profiles that exist: $(available_profiles). Correct the pool in docs/00-ai-context.md, add one with 'aimux profile add <name> --cli <cli>', or pass a cli:<name> fallback entry"

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

accumulate_usage() {
  _events=$1
  [ -r "$_events" ] || return 0
  _usage=$(awk -f "$SKILLDIR/usage.awk" "$_events" 2>/dev/null || true)
  [ -n "$_usage" ] || return 0
  # shellcheck disable=SC2086
  set -- $_usage
  USAGE_AVAILABLE=1
  USAGE_INPUT=$((USAGE_INPUT + $1))
  USAGE_CACHED_INPUT=$((USAGE_CACHED_INPUT + $2))
  USAGE_CACHE_WRITE_INPUT=$((USAGE_CACHE_WRITE_INPUT + $3))
  USAGE_OUTPUT=$((USAGE_OUTPUT + $4))
  USAGE_REASONING_OUTPUT=$((USAGE_REASONING_OUTPUT + $5))
}

# Codex's rollout budget can remind the agent as the ceiling approaches. With no thresholds a
# budget stop is an abrupt cut; with them the build prompt's instruction to stop starting new work
# and write a handoff has something to fire on. Thresholds: a quarter and a tenth of the ceiling.
# CF_ROLLOUT_REMINDERS overrides the list verbatim (for example `[]` to disable it).
rollout_reminders() {
  if [ -n "${CF_ROLLOUT_REMINDERS:-}" ]; then printf '%s' "$CF_ROLLOUT_REMINDERS"; return 0; fi
  _quarter=$(($1 / 4)); _tenth=$(($1 / 10))
  if [ "$_tenth" -gt 0 ] && [ "$_quarter" -gt "$_tenth" ]; then printf '[%s,%s]' "$_quarter" "$_tenth"
  elif [ "$_quarter" -gt 0 ]; then printf '[%s]' "$_quarter"
  else printf '[]'
  fi
}
ROLLOUT_CONFIG=''
[ -z "$MAX_ROLLOUT_TOKENS" ] || ROLLOUT_CONFIG="features.rollout_budget={enabled=true,limit_tokens=$MAX_ROLLOUT_TOKENS,reminder_at_remaining_tokens=$(rollout_reminders "$MAX_ROLLOUT_TOKENS"),sampling_token_weight=1.0,prefill_token_weight=1.0}"

kill_tree() {
  _sig=$1; _pid=$2
  _children=''
  if command -v pgrep >/dev/null 2>&1; then
    _children=$(pgrep -P "$_pid" 2>/dev/null || true)
  fi
  kill "-$_sig" "$_pid" 2>/dev/null || true
  for _child in $_children; do kill_tree "$_sig" "$_child"; done
}

file_bytes() {
  if [ -r "$1" ]; then wc -c < "$1" | tr -d ' '; else printf 0; fi
}

# Run "$@" as one watched foreground attempt: stdin closed, stdout to the event stream, stderr to
# the raw attempt log. Returns the worker's exit code, or 124 with FG_TIMEOUT_CLASS set when the
# attempt produced no observable output for the stall ceiling or outlived the wall ceiling.
FG_TIMEOUT_CLASS=''
FG_WORKER_PID=''
run_watched() {
  FG_TIMEOUT_CLASS=''
  "$@" >"$EVENTS_ATTEMPT" 2>"$RAW_ATTEMPT_LOG" </dev/null &
  FG_WORKER_PID=$!
  _started=$(date +%s); _last_progress=$_started; _last_bytes=0; _polls=0
  while kill -0 "$FG_WORKER_PID" 2>/dev/null; do
    # Poll quickly at first so a fast dispatch is not held up, then once per second.
    _polls=$((_polls + 1))
    if [ "$_polls" -le 30 ]; then sleep 0.1; else sleep 1; fi
    _now=$(date +%s)
    _bytes=$(($(file_bytes "$EVENTS_ATTEMPT") + $(file_bytes "$RAW_ATTEMPT_LOG")))
    if [ "$_bytes" -gt "$_last_bytes" ]; then _last_progress=$_now; _last_bytes=$_bytes; fi
    if [ $((_now - _started)) -ge "$WALL_TIMEOUT_SECONDS" ]; then
      FG_TIMEOUT_CLASS='timeout.wall'
    elif [ $((_now - _last_progress)) -ge "$STALL_TIMEOUT_SECONDS" ]; then
      FG_TIMEOUT_CLASS='timeout.stalled'
    fi
    if [ -n "$FG_TIMEOUT_CLASS" ]; then
      printf 'DISPATCH watchdog terminating worker pid=%s reason=%s\n' "$FG_WORKER_PID" "$FG_TIMEOUT_CLASS" >> "$RAW_ATTEMPT_LOG"
      kill_tree TERM "$FG_WORKER_PID"
      sleep 1
      kill_tree KILL "$FG_WORKER_PID"
      break
    fi
  done
  _wrc=0
  { wait "$FG_WORKER_PID"; } 2>/dev/null || _wrc=$?
  FG_WORKER_PID=''
  [ -z "$FG_TIMEOUT_CLASS" ] || _wrc=124
  return "$_wrc"
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
        [ -z "$ROLLOUT_CONFIG" ] || set -- "$@" -c "$ROLLOUT_CONFIG"
        [ "$NETWORK" -eq 0 ] || set -- "$@" -c 'sandbox_workspace_write.network_access=true'
        set -- "$@" exec --json -s "$MODE"
        [ -z "$MODEL" ] || set -- "$@" -m "$MODEL"
        set -- "$@" -o "$OUT" "$PROMPT"
      else
        set -- codex -a never
        [ -z "$REASONING_EFFORT" ] || set -- "$@" -c "model_reasoning_effort=$REASONING_EFFORT"
        [ -z "$ROLLOUT_CONFIG" ] || set -- "$@" -c "$ROLLOUT_CONFIG"
        [ "$NETWORK" -eq 0 ] || set -- "$@" -c 'sandbox_workspace_write.network_access=true'
        set -- "$@" exec --json -s "$MODE"
        [ -z "$MODEL" ] || set -- "$@" -m "$MODEL"
        set -- "$@" -o "$OUT" "$PROMPT"
      fi
      mkdir -p "$ARTIFACTS_DIR" "$(dirname "$OUT")"
      RAW_ATTEMPT_LOG="$ARTIFACTS_DIR/$(basename "$OUT").attempt-${attempt_count:-1}.log"
      EVENTS_ATTEMPT="$ARTIFACTS_DIR/$(basename "$OUT").attempt-${attempt_count:-1}.jsonl"
      rm -f "$OUT" "$RAW_ATTEMPT_LOG" "$EVENTS_ATTEMPT"
      run_watched "$@" || _rc=$?
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
  if [ -n "${FG_TIMEOUT_CLASS:-}" ]; then
    # A hung read-only attempt has no side effects, so another profile may take it over.
    failure_class=$FG_TIMEOUT_CLASS
    retryable=0
    [ "$MODE" != read-only ] || retryable=1
    return 0
  fi
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
  # A CLI that dies before emitting a single event, with `Operation not permitted` on stderr, was
  # launched from inside another sandbox. That is a property of where the orchestrator runs, not of
  # the profile, so no other pool member can succeed either.
  if [ -n "${EVENTS_ATTEMPT:-}" ] && [ ! -s "$EVENTS_ATTEMPT" ] &&
     [ -n "${RAW_ATTEMPT_LOG:-}" ] && grep -Eiq 'operation not permitted' "$RAW_ATTEMPT_LOG" 2>/dev/null; then
    failure_class='environment.sandbox-nested'; retryable=0
  fi
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
    "$LAST_LABEL" "$RESOLVED_CLI" "$EFFECTIVE_MODEL" "${REASONING_EFFORT:-profile-default}" "${MAX_ROLLOUT_TOKENS:-unbounded}" "$MODE" "$failure_class" "${OUT:-${LOG:-n/a}}"
  exit 78
fi

# Environment conditions that have each cost real runs. They are reported, never blocking, and only
# where a run starts (planning) or writes (background) so they do not repeat on every dispatch.
warnings=''
add_warning() { warnings="${warnings}WARNING: $1
"; }
if [ "$BACKGROUND" -eq 1 ] || [ "$PHASE" = planning ]; then
  repo_top=$(git rev-parse --show-toplevel 2>/dev/null || true)
  case "$repo_top" in
    *'/Mobile Documents/'*|*/OneDrive*|*/Dropbox*|*'/Google Drive'*|*/CloudStorage/*|*/pCloud*)
      copies=$(git ls-files --others --cached --exclude-standard 2>/dev/null | grep -cE ' [0-9]+(\.[^/ ]+)*$' || true)
      add_warning "the repository is in a cloud-synced directory ($repo_top). Sync clients create conflict copies such as 'SKILL 2.md' when files are replaced quickly; ${copies:-0} such file(s) are present now. Prefer a git worktree outside the synced root for builds." ;;
  esac
  case "$repo_top" in
    *' '*) add_warning "the repository path contains a space. Variables that tools split on whitespace (MAVEN_OPTS, MAVEN_ARGS, JAVA_TOOL_OPTIONS) must use relative paths in the build env file." ;;
  esac
  if [ "$PHASE" = implementation ] && [ -n "$ENV_FILE" ] && [ -z "$PREFLIGHT" ]; then
    add_warning "an env file is used without --preflight. A preflight that runs the build tool through that env file (for example 'mvn -v' or 'node --version') catches a broken environment before the build spends its budget on it."
  fi
fi

# A pool made only of cli:NAME entries did not fall back from anything: running the CLI directly is
# the project's configured choice and the DISPATCH line already shows it.
only_bare=1
for pool_entry in $POOL; do
  case "$pool_entry" in cli:*) ;; *) only_bare=0 ;; esac
done

# Note for the FALLBACK: line. Recomputed after the read-only retry loop with the full attempt log;
# set here too because the background path exits before that recompute.
note=''
if [ "$LAST_KIND" = bare ] && [ "$only_bare" -eq 1 ]; then
  note=''
elif [ "$LAST_KIND" = bare ]; then
  note="FALLBACK: no aimux profile in [$PROFILE] resolved — ran cli '$BARE_CLI' directly; cost is NOT separated"
elif [ -n "$missing_log" ]; then
  note="FALLBACK: profile(s)$missing_log not in $AIMUX_CONFIG, used '$RESOLVED_PROFILE' instead"
fi

if [ "$BACKGROUND" -eq 1 ]; then
  # No blind retry here even on a pool: a failed workspace-write may have changed the tree.
  # background-supervisor.sh guarantees that a live-but-stalled worker eventually terminates and
  # writes a classified sentinel instead of blocking the orchestrator indefinitely.
  log_base=$(printf '%s' "$LOG" | sed 's/\.log$//')
  log_dir=$(dirname "$LOG")
  exit_file="$log_base.exit"
  health_file="$log_base.health"
  final_file="$log_base.final.md"
  untracked_file="$log_base.untracked-before"
  protect_manifest="$log_base.protect"
  mkdir -p "$log_dir"

  # Never start a second writer on a log whose supervisor is still alive, and never overwrite the
  # record of an earlier attempt: move it aside first.
  if [ -r "$health_file" ] && [ ! -e "$exit_file" ]; then
    prior_pid=$(awk -F '\t' '$1 == "supervisor_pid" { print $2; exit }' "$health_file")
    case "$prior_pid" in
      ''|*[!0-9]*) ;;
      *) if kill -0 "$prior_pid" 2>/dev/null; then
           die "dispatch.sh: a dispatch for $LOG is still running (supervisor pid $prior_pid); wait for its sentinel or stop it before starting another"
         fi ;;
    esac
  fi
  prior_found=0
  for prior in "$LOG" "$exit_file" "$health_file" "$LOG.events.jsonl" "$final_file" "$BUILD_REPORT" "$untracked_file" "$protect_manifest" "$LEDGER"; do
    [ -e "$prior" ] && prior_found=1
  done
  if [ "$prior_found" -eq 1 ]; then
    attempt_n=1
    while [ -e "$log_dir/attempts/$(basename "$log_base")-$attempt_n" ]; do attempt_n=$((attempt_n + 1)); done
    archive_dir="$log_dir/attempts/$(basename "$log_base")-$attempt_n"
    mkdir -p "$archive_dir"
    for prior in "$LOG" "$exit_file" "$health_file" "$LOG.events.jsonl" "$final_file" "$BUILD_REPORT" "$untracked_file" "$protect_manifest" "$LEDGER"; do
      [ ! -e "$prior" ] || mv -- "$prior" "$archive_dir/"
    done
    printf 'DISPATCH archived previous attempt to %s\n' "$archive_dir"
  fi

  # Snapshot what the worker must leave alone and what is already untracked, so the supervisor can
  # restore the former and report only the latter's additions.
  : > "$protect_manifest"
  if [ -n "$PROTECT" ]; then
    protect_dir="$log_dir/protected/$(basename "$log_base")"
    rm -rf "$protect_dir"
    mkdir -p "$protect_dir"
    protect_n=0
    while IFS= read -r protected; do
      [ -n "$protected" ] || continue
      [ -f "$protected" ] || die "dispatch.sh: --protect file not found: $protected"
      protect_n=$((protect_n + 1))
      cp -p -- "$protected" "$protect_dir/$protect_n"
      printf '%s\t%s\n' "$protect_dir/$protect_n" "$protected" >> "$protect_manifest"
    done <<PROTECT_LIST
$PROTECT
PROTECT_LIST
  fi
  git ls-files --others --exclude-standard 2>/dev/null | sort > "$untracked_file" || : > "$untracked_file"
  CFD_PROFILE=$RESOLVED_PROFILE
  CFD_CLI=$RESOLVED_CLI
  CFD_MODE=$MODE
  CFD_MODEL=$MODEL
  CFD_REASONING_EFFORT=$REASONING_EFFORT
  CFD_MAX_ROLLOUT_TOKENS=$MAX_ROLLOUT_TOKENS
  CFD_ROLLOUT_CONFIG=$ROLLOUT_CONFIG
  CFD_FINAL_FILE=$final_file
  CFD_REPORT_FILE=$BUILD_REPORT
  CFD_UNTRACKED_BEFORE=$untracked_file
  CFD_PROTECT_MANIFEST=$protect_manifest
  CFD_SKILLDIR=$SKILLDIR
  CFD_MODEL_EVIDENCE=$MODEL_EVIDENCE
  CFD_LOG=$LOG
  CFD_EVENTS="$LOG.events.jsonl"
  CFD_EFFECTIVE_MODEL=$MODEL
  [ -n "$CFD_EFFECTIVE_MODEL" ] || CFD_EFFECTIVE_MODEL=$PROFILE_MODEL
  [ -n "$CFD_EFFECTIVE_MODEL" ] || CFD_EFFECTIVE_MODEL='profile-default'
  CFD_NETWORK=$NETWORK
  CFD_PROMPT=$PROMPT
  CFD_EXIT_FILE=$exit_file
  CFD_HEALTH_FILE=$health_file
  CFD_LEDGER=$LEDGER
  CFD_PHASE=$PHASE
  CFD_JOB_ID=$JOB_ID
  CFD_STALL_TIMEOUT_SECONDS=$STALL_TIMEOUT_SECONDS
  CFD_WALL_TIMEOUT_SECONDS=$WALL_TIMEOUT_SECONDS
  CFD_HEARTBEAT_SECONDS=$HEARTBEAT_SECONDS
  export CFD_PROFILE CFD_CLI CFD_MODE CFD_MODEL CFD_REASONING_EFFORT CFD_MAX_ROLLOUT_TOKENS
  export CFD_MODEL_EVIDENCE CFD_LOG CFD_EVENTS CFD_EFFECTIVE_MODEL CFD_NETWORK CFD_PROMPT
  export CFD_EXIT_FILE CFD_HEALTH_FILE CFD_LEDGER CFD_JOB_ID CFD_PHASE
  export CFD_STALL_TIMEOUT_SECONDS CFD_WALL_TIMEOUT_SECONDS CFD_HEARTBEAT_SECONDS
  export CFD_ROLLOUT_CONFIG CFD_FINAL_FILE CFD_REPORT_FILE CFD_UNTRACKED_BEFORE CFD_PROTECT_MANIFEST
  export CFD_SKILLDIR

  nohup sh "$SKILLDIR/background-supervisor.sh" > "$LOG" 2>&1 < /dev/null &
  supervisor_pid=$!
  printf 'DISPATCH started  profile=%s  cli=%s  model=%s  reasoning_effort=%s  rollout_budget=%s  mode=%s  supervisor_pid=%s  log=%s  sentinel=%s  health=%s  report=%s  stall_timeout=%ss  wall_timeout=%ss  heartbeat=%ss\n' \
    "$LAST_LABEL" "$RESOLVED_CLI" "$CFD_EFFECTIVE_MODEL" "${REASONING_EFFORT:-profile-default}" \
    "${MAX_ROLLOUT_TOKENS:-unbounded}" "$MODE" "$supervisor_pid" "$LOG" "$exit_file" "$health_file" \
    "$BUILD_REPORT" "$STALL_TIMEOUT_SECONDS" "$WALL_TIMEOUT_SECONDS" "$HEARTBEAT_SECONDS"
  [ -z "$note" ] || printf '%s\n' "$note"
  [ -z "$warnings" ] || printf '%s' "$warnings"
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
if [ "$LAST_KIND" = bare ] && [ "$only_bare" -eq 1 ]; then
  note=''
elif [ "$LAST_KIND" = bare ]; then
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
[ -z "$warnings" ] || printf '%s' "$warnings"
case "$failure_class" in
  environment.sandbox-nested)
    printf '%s\n' "HINT: the CLI could not initialise because this dispatch was started from inside another sandbox. Run the orchestrator outside a sandboxed session, or allow dispatch.sh to run unsandboxed; no other profile can succeed from here." ;;
  timeout.stalled|timeout.wall)
    printf '%s\n' "HINT: the attempt produced no usable result within its ceiling (stall ${STALL_TIMEOUT_SECONDS}s, wall ${WALL_TIMEOUT_SECONDS}s). Raw output: ${RAW_ATTEMPT_LOG:-n/a}" ;;
esac
if [ "$status" -ne 0 ] && [ -n "${EVENTS_ATTEMPT:-}" ]; then
  printf 'DISPATCH artifacts  events=%s  stderr=%s  (read with dispatch-tail.sh --events)\n' "$EVENTS_ATTEMPT" "${RAW_ATTEMPT_LOG:-n/a}"
fi
write_ledger "$([ "$status" -eq 0 ] && printf passed || printf failed)" "$status"
exit "$status"
