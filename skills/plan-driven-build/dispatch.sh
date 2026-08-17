#!/usr/bin/env sh
# Clarity Framework – dispatch for plan-driven-build.
#
# One stable entry point for every dispatch in the workflow. It exists for four reasons:
#   1. The prompt lives in prompts/*.txt, not in SKILL.md. That keeps roughly a thousand words of
#      instruction text out of the orchestrator's context entirely — the orchestrator names a
#      prompt file and fills its placeholders, it never reads the prompt.
#   2. Account separation is verified, not assumed — a missing aimux account is reported as a
#      fallback instead of silently landing on whatever account is logged in on this machine.
#      An aimux account selects which subscription pays. It is not a persona and it does not change
#      how an agent behaves; aimux names its own subcommand `profile`, this script says `account` to
#      keep it distinct from a Codex profile and from the plan's gate profile.
#   3. Sandbox and approval policy are always set together. Setting only the sandbox leaves the
#      approval policy at its default, which is what makes an unattended dispatch stop and ask.
#   4. The orchestrator gets a one-line result with a line count measured against the budget, so it
#      learns whether a report fits before opening it.
#
# A single stable command prefix is also what a permission allowlist can match reliably; an
# env-prefixed, backgrounded compound command is not.
#
# Usage:
#   dispatch.sh --account NAME[,NAME...] [--fallback NAME] --mode read-only|workspace-write
#               --prompt-file FILE [--var KEY=VALUE ...] [--model NAME]
#               --out FILE [--max-lines N] [--env-file FILE]
#   dispatch.sh --account NAME[,NAME...] --mode workspace-write --prompt-file FILE [--var KEY=VALUE ...]
#               [--model NAME] --log FILE --background [--network] [--env-file FILE]
#
# --account takes an ordered, comma-separated pool of aimux account names, e.g.
# `--account codework1,codework2,codework3`. This is priority order, resolved once per dispatch —
# not round-robin, and not a rotation the caller has to manage between runs. It exists to spread
# cost across interchangeable subscriptions, not to bind a level to one persona; nothing about
# review needing a *different* account from reasoning is enforced here — separate that with the
# prompt file's content, not the account.
#
# --mode read-only dispatches are side-effect-free, so a failed attempt retries the next account in
# the pool automatically until one succeeds or the pool is exhausted. --mode workspace-write never
# retries after launch: a build can fail partway through, and retrying it blindly on a different
# account would compound a real failure instead of a rate limit. The pool still decides which
# account *starts* a workspace-write dispatch — first one whose aimux profile directory exists.
#
# The retry-on-failure path treats any non-zero codex exit as grounds to try the next account. This
# is unverified: it has not been checked against a real rate-limit error from codex, so it may also
# retry a genuine prompt or task failure on a different account instead of surfacing it. Read this
# skill's setup notes before trusting it unattended, and watch the DISPATCH summary line the first
# few times it fires.
#
# --profile is accepted as a deprecated alias for --account so existing invocations keep working.
# --fallback NAME is appended to the end of the --account pool; prefer a comma-separated --account
# list for anything with more than one fallback.
#
# --model NAME is passed straight through to codex as a per-dispatch override, independent of which
# account ends up paying for the call — this is what lets a pool of otherwise-identical accounts
# share one capability tier. The exact flag codex expects has not been verified against the
# installed CLI version; check `codex exec --help` before relying on it, per this skill's setup
# notes. If the flag name is wrong, codex will fail fast with an unrecognized-argument error rather
# than silently ignoring it.
#
# --prompt TEXT still works for an ad-hoc dispatch. Placeholders in a prompt file are written
# {{KEY}}; every placeholder must be supplied with --var or the dispatch aborts. Values are
# single-line. Keys are A-Z and underscore.
#
# Background mode writes the exit code to the log path with .log replaced by .exit. Poll that
# sentinel — never tail a running build.
# Background mode uses `nohup` so the build is not tied to the short-lived shell process that
# launched it. Some CLI harnesses clean up ordinary background children as soon as the command that
# spawned them returns; that leaves an empty log and no sentinel.
#
# --env-file sources one project-owned shell file before launching codex. Use it for language or
# toolchain bootstrap such as JAVA_HOME, Node version managers, or Go toolchain variables. The file
# is explicit per dispatch so environment corrections stay visible in the run journal.

set -eu

die() { printf '%s\n' "$1" >&2; exit 2; }

ACCOUNT=''; FALLBACK=''; MODE=''; OUT=''; LOG=''; PROMPT=''; PROMPT_FILE=''; ENV_FILE=''
MAX_LINES=''; BACKGROUND=0; NETWORK=0; KEYS=''; MODEL=''

while [ $# -gt 0 ]; do
  case "$1" in
    --account)     ACCOUNT="${2:-}";     shift 2 ;;
    --profile)     ACCOUNT="${2:-}";     shift 2 ;;  # deprecated alias for --account
    --fallback)    FALLBACK="${2:-}";    shift 2 ;;
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

[ -n "$ACCOUNT" ] || die 'dispatch.sh: --account is required'
case "$MODE" in
  read-only|workspace-write) ;;
  *) die "dispatch.sh: --mode must be read-only or workspace-write (got '$MODE')" ;;
esac
if [ "$BACKGROUND" -eq 1 ]; then
  [ -n "$LOG" ] || die 'dispatch.sh: --background requires --log'
else
  [ -n "$OUT" ] || die 'dispatch.sh: --out is required unless --background'
fi
if [ "$NETWORK" -eq 1 ] && [ "$MODE" != workspace-write ]; then
  die 'dispatch.sh: --network applies to --mode workspace-write only'
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

# Extra top-level codex flags, applied regardless of which account in the pool ends up running.
#
# Sandbox network access: codex denies it under workspace-write by default, which stops any build
# that has to resolve a dependency. Set it per dispatch rather than widening the account's stored
# config, so read-only levels keep the default and the wider sandbox lasts exactly one build.
#
# Model override: independent of the account, so a pool of otherwise-interchangeable accounts can
# share one capability tier. See the --model note above — unverified flag name.
set --
if [ "$NETWORK" -eq 1 ]; then
  set -- -c 'sandbox_workspace_write.network_access=true'
fi
if [ -n "$MODEL" ]; then
  set -- "$@" -m "$MODEL"
fi

# Resolve the account pool. aimux keeps one config directory per account (its own CLI calls the
# subcommand `profile`); pointing CODEX_HOME at it is what actually separates the subscription, not
# just the process. --account may list several accounts, tried in the order given; --fallback, if
# set, is appended as the last one. remaining_accounts is consumed by advance_account() below —
# each call pops candidates off the front until it finds one with an existing profile directory.
remaining_accounts=$(printf '%s' "$ACCOUNT" | tr ',' ' ')
[ -n "$FALLBACK" ] && remaining_accounts="$remaining_accounts $FALLBACK"
missing_log=''

# Sets account_dir and used on success (and shrinks remaining_accounts); leaves account_dir empty
# and returns 1 once the pool is exhausted. Every skipped candidate is recorded in missing_log.
advance_account() {
  account_dir=''
  while [ -n "$remaining_accounts" ]; do
    acct=${remaining_accounts%% *}
    case "$remaining_accounts" in
      *' '*) remaining_accounts=${remaining_accounts#* } ;;
      *) remaining_accounts='' ;;
    esac
    [ -n "$acct" ] || continue
    if [ -d "$HOME/.aimux/profiles/$acct" ]; then
      account_dir="$HOME/.aimux/profiles/$acct"; used="$acct"
      return 0
    fi
    missing_log="$missing_log $acct"
  done
  return 1
}

used=''; account_dir=''; note=''
if advance_account; then
  CODEX_HOME="$account_dir"; export CODEX_HOME
  [ -n "$missing_log" ] && note="FALLBACK: account(s)$missing_log not found, used '$used' instead"
else
  used='(logged-in account)'
  note="FALLBACK: no aimux account among [$ACCOUNT${FALLBACK:+,$FALLBACK}] exists — ran on the logged-in account; cost is NOT separated"
fi

if [ -n "$ENV_FILE" ]; then
  [ -f "$ENV_FILE" ] || die "dispatch.sh: env file not found: $ENV_FILE"
  [ -r "$ENV_FILE" ] || die "dispatch.sh: env file not readable: $ENV_FILE"
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

command -v codex >/dev/null 2>&1 || die 'dispatch.sh: codex not on PATH'

if [ "$BACKGROUND" -eq 1 ]; then
  # No retry here even on a pool: a killed or failed build cannot be safely re-launched on another
  # account without knowing what it already wrote. The pool only decides the starting account.
  exit_file="$(printf '%s' "$LOG" | sed 's/\.log$//').exit"
  rm -f "$exit_file"
  CFD_MODE=$MODE
  CFD_PROMPT=$PROMPT
  CFD_EXIT_FILE=$exit_file
  export CFD_MODE CFD_PROMPT CFD_EXIT_FILE
  nohup sh -c '
    printf "%s\n" "DISPATCH child started"
    status=0
    codex -a never "$@" exec -s "$CFD_MODE" "$CFD_PROMPT" || status=$?
    printf "%s\n" "$status" > "$CFD_EXIT_FILE"
    exit "$status"
  ' dispatch-bg "$@" > "$LOG" 2>&1 < /dev/null &
  printf 'DISPATCH started  account=%s  mode=%s  pid=%s  log=%s  sentinel=%s\n' \
    "$used" "$MODE" "$!" "$LOG" "$exit_file"
  [ -n "$note" ] && printf '%s\n' "$note"
  exit 0
fi

status=0
codex -a never "$@" exec -s "$MODE" -o "$OUT" "$PROMPT" >/dev/null 2>&1 || status=$?
attempt_log=" $used=exit$status"

# Retry the pool only for read-only dispatch — it has no side effects, so a second attempt under a
# different account is safe. workspace-write never reaches this loop (background exits above).
if [ "$MODE" = read-only ]; then
  while [ "$status" -ne 0 ] && advance_account; do
    CODEX_HOME="$account_dir"; export CODEX_HOME
    status=0
    codex -a never "$@" exec -s "$MODE" -o "$OUT" "$PROMPT" >/dev/null 2>&1 || status=$?
    attempt_log="$attempt_log $used=exit$status"
  done
fi

if [ "$used" = '(logged-in account)' ]; then
  note="FALLBACK: no aimux account among [$ACCOUNT${FALLBACK:+,$FALLBACK}] worked (tried$missing_log$attempt_log) — ran on the logged-in account; cost is NOT separated"
elif [ -n "$missing_log" ] || [ "$MODE" = read-only ] && [ "$(printf '%s' "$attempt_log" | wc -w)" -gt 1 ]; then
  note="FALLBACK: tried$missing_log$attempt_log — used '$used'"
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

printf 'DISPATCH exit=%s  account=%s  mode=%s  out=%s  lines=%s  budget=%s\n' \
  "$status" "$used" "$MODE" "$OUT" "$lines" "$budget"
[ -n "$note" ] && printf '%s\n' "$note"
exit "$status"
