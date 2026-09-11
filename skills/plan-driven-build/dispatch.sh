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
#               --out FILE [--max-lines N] [--env-file FILE]
#   dispatch.sh --profile NAME[,NAME...]
#               --mode workspace-write|danger-full-access
#               (--prompt-file FILE [--var KEY=VALUE ...] | --prompt TEXT) [--model NAME]
#               --log FILE --background [--network] [--env-file FILE]
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
# profile ends up paying. For a resolved profile it is passed to `aimux run` as `-m NAME`; for a
# `cli:NAME` fallback entry the adapter passes it to the CLI's own model flag (codex: `-m`, after
# `exec`). The exact flag has not been verified against the installed CLI version; check
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

set -eu

die() { printf '%s\n' "$1" >&2; exit 2; }

PROFILE=''; MODE=''; OUT=''; LOG=''; PROMPT=''; PROMPT_FILE=''; ENV_FILE=''
MAX_LINES=''; BACKGROUND=0; NETWORK=0; KEYS=''; MODEL=''

while [ $# -gt 0 ]; do
  case "$1" in
    --profile)     PROFILE="${2:-}";     shift 2 ;;
    --mode)        MODE="${2:-}";        shift 2 ;;
    --model)       MODEL="${2:-}";       shift 2 ;;
    --out)         OUT="${2:-}";         shift 2 ;;
    --log)         LOG="${2:-}";         shift 2 ;;
    --max-lines)   MAX_LINES="${2:-}";   shift 2 ;;
    --prompt)      PROMPT="${2:-}";      shift 2 ;;
    --prompt-file) PROMPT_FILE="${2:-}"; shift 2 ;;
    --env-file)    ENV_FILE="${2:-}";    shift 2 ;;
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

POOL=$(printf '%s' "$PROFILE" | tr ',' ' ')
remaining_pool="$POOL"
RESOLVED_PROFILE=''; RESOLVED_CLI=''; BARE_CLI=''; TARGET_KIND=''
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
      return 0
    fi
    missing_log="$missing_log $entry"
  done
  if [ -n "$deferred_bare" ] && [ "$bare_used" -eq 0 ]; then
    bare_used=1
    BARE_CLI="$deferred_bare"; RESOLVED_CLI="$deferred_bare"; TARGET_KIND=bare
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
        [ "$NETWORK" -eq 0 ] || set -- "$@" -c 'sandbox_workspace_write.network_access=true'
        set -- "$@" exec -s "$MODE" -o "$OUT" "$PROMPT"
      else
        set -- codex -a never
        [ "$NETWORK" -eq 0 ] || set -- "$@" -c 'sandbox_workspace_write.network_access=true'
        set -- "$@" exec -s "$MODE"
        [ -z "$MODEL" ] || set -- "$@" -m "$MODEL"
        set -- "$@" -o "$OUT" "$PROMPT"
      fi
      "$@" >/dev/null 2>&1 || _rc=$?
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
  CFD_NETWORK=$NETWORK
  CFD_PROMPT=$PROMPT
  CFD_EXIT_FILE=$exit_file
  export CFD_PROFILE CFD_CLI CFD_MODE CFD_MODEL CFD_NETWORK CFD_PROMPT CFD_EXIT_FILE
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
          [ "$CFD_NETWORK" -eq 0 ] || set -- "$@" -c "sandbox_workspace_write.network_access=true"
          set -- "$@" exec -s "$CFD_MODE" "$CFD_PROMPT"
        else
          set -- codex -a never
          [ "$CFD_NETWORK" -eq 0 ] || set -- "$@" -c "sandbox_workspace_write.network_access=true"
          set -- "$@" exec -s "$CFD_MODE"
          [ -z "$CFD_MODEL" ] || set -- "$@" -m "$CFD_MODEL"
          set -- "$@" "$CFD_PROMPT"
        fi
        "$@" || status=$?
        ;;
      *) printf "%s\n" "dispatch child: cli $CFD_CLI has no adapter" >&2; status=2 ;;
    esac
    printf "%s\n" "$status" > "$CFD_EXIT_FILE"
    exit "$status"
  ' dispatch-bg > "$LOG" 2>&1 < /dev/null &
  printf 'DISPATCH started  profile=%s  mode=%s  pid=%s  log=%s  sentinel=%s\n' \
    "$LAST_LABEL" "$MODE" "$!" "$LOG" "$exit_file"
  [ -z "$note" ] || printf '%s\n' "$note"
  exit 0
fi

status=0
run_cli || status=$?
attempt_log=" $LAST_LABEL=exit$status"

# Retry the pool only for read-only dispatch — no side effects, so a second attempt under another
# profile is safe. workspace-write never reaches this loop (background exits above).
if [ "$MODE" = read-only ]; then
  while [ "$status" -ne 0 ]; do
    advance_target || break
    LAST_LABEL=$(target_label)
    LAST_KIND=$TARGET_KIND
    status=0
    run_cli || status=$?
    attempt_log="$attempt_log $LAST_LABEL=exit$status"
  done
fi

retry_count=$(printf '%s' "$attempt_log" | wc -w | tr -d ' ')
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

printf 'DISPATCH exit=%s  profile=%s  mode=%s  out=%s  lines=%s  budget=%s\n' \
  "$status" "$LAST_LABEL" "$MODE" "$OUT" "$lines" "$budget"
[ -z "$note" ] || printf '%s\n' "$note"
exit "$status"
