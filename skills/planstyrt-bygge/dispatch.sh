#!/usr/bin/env sh
# Clarity Framework – dispatch for planstyrt-bygge.
#
# One stable entry point for every dispatch in the workflow. It exists for four reasons:
#   1. The prompt lives in prompts/*.txt, not in SKILL.md. That keeps roughly a thousand words of
#      instruction text out of the orchestrator's context entirely — the orchestrator names a
#      prompt file and fills its placeholders, it never reads the prompt.
#   2. Account separation is verified, not assumed — a missing aimux profile is reported as a
#      fallback instead of silently landing on whatever account is logged in on this machine.
#   3. Sandbox and approval policy are always set together. Setting only the sandbox leaves the
#      approval policy at its default, which is what makes an unattended dispatch stop and ask.
#   4. The orchestrator gets a one-line result with a line count measured against the budget, so it
#      learns whether a report fits before opening it.
#
# A single stable command prefix is also what a permission allowlist can match reliably; an
# env-prefixed, backgrounded compound command is not.
#
# Usage:
#   dispatch.sh --profile NAME [--fallback NAME] --mode read-only|workspace-write
#               --prompt-file FILE [--var KEY=VALUE ...]
#               --out FILE [--max-lines N]
#   dispatch.sh --profile NAME --mode workspace-write --prompt-file FILE [--var KEY=VALUE ...]
#               --log FILE --background
#
# --prompt TEXT still works for an ad-hoc dispatch. Placeholders in a prompt file are written
# {{KEY}}; every placeholder must be supplied with --var or the dispatch aborts. Values are
# single-line. Keys are A-Z and underscore.
#
# Background mode writes the exit code to the log path with .log replaced by .exit. Poll that
# sentinel — never tail a running build.

set -eu

die() { printf '%s\n' "$1" >&2; exit 2; }

PROFILE=''; FALLBACK=''; MODE=''; OUT=''; LOG=''; PROMPT=''; PROMPT_FILE=''
MAX_LINES=''; BACKGROUND=0; KEYS=''

while [ $# -gt 0 ]; do
  case "$1" in
    --profile)     PROFILE="${2:-}";     shift 2 ;;
    --fallback)    FALLBACK="${2:-}";    shift 2 ;;
    --mode)        MODE="${2:-}";        shift 2 ;;
    --out)         OUT="${2:-}";         shift 2 ;;
    --log)         LOG="${2:-}";         shift 2 ;;
    --max-lines)   MAX_LINES="${2:-}";   shift 2 ;;
    --prompt)      PROMPT="${2:-}";      shift 2 ;;
    --prompt-file) PROMPT_FILE="${2:-}"; shift 2 ;;
    --background)  BACKGROUND=1;         shift ;;
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
  read-only|workspace-write) ;;
  *) die "dispatch.sh: --mode must be read-only or workspace-write (got '$MODE')" ;;
esac
if [ "$BACKGROUND" -eq 1 ]; then
  [ -n "$LOG" ] || die 'dispatch.sh: --background requires --log'
else
  [ -n "$OUT" ] || die 'dispatch.sh: --out is required unless --background'
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

command -v codex >/dev/null 2>&1 || die 'dispatch.sh: codex not on PATH'

# Resolve the account. aimux keeps one config directory per profile; pointing CODEX_HOME at it is
# what actually separates the subscription, not just the process.
profile_dir=''; used=''; note=''
if [ -d "$HOME/.aimux/profiles/$PROFILE" ]; then
  profile_dir="$HOME/.aimux/profiles/$PROFILE"; used="$PROFILE"
elif [ -n "$FALLBACK" ] && [ -d "$HOME/.aimux/profiles/$FALLBACK" ]; then
  profile_dir="$HOME/.aimux/profiles/$FALLBACK"; used="$FALLBACK"
  note="FALLBACK: profile '$PROFILE' missing, ran as '$FALLBACK'"
else
  used='(logged-in account)'
  note="FALLBACK: no aimux profile for '$PROFILE' — context is isolated, cost is NOT separated"
fi
[ -n "$profile_dir" ] && CODEX_HOME="$profile_dir" && export CODEX_HOME

if [ "$BACKGROUND" -eq 1 ]; then
  exit_file="$(printf '%s' "$LOG" | sed 's/\.log$//').exit"
  rm -f "$exit_file"
  (
    status=0
    codex -a never exec -s "$MODE" "$PROMPT" || status=$?
    printf '%s\n' "$status" > "$exit_file"
    exit "$status"
  ) > "$LOG" 2>&1 &
  printf 'DISPATCH started  profile=%s  mode=%s  pid=%s  log=%s  sentinel=%s\n' \
    "$used" "$MODE" "$!" "$LOG" "$exit_file"
  [ -n "$note" ] && printf '%s\n' "$note"
  exit 0
fi

status=0
codex -a never exec -s "$MODE" -o "$OUT" "$PROMPT" >/dev/null 2>&1 || status=$?

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
  "$status" "$used" "$MODE" "$OUT" "$lines" "$budget"
[ -n "$note" ] && printf '%s\n' "$note"
exit "$status"
