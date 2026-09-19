#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/out" "$TEST_ROOT/home/.aimux"

# --- fake aimux: only `run <profile> [-m MODEL] -- <cmd...>` is implemented ---
cat > "$TEST_ROOT/bin/aimux" <<'FAKE_AIMUX'
#!/usr/bin/env sh
[ "$1" = "run" ] || exit 64
shift
AIMUX_FAKE_PROFILE=$1
shift
AIMUX_FAKE_MODEL=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -m|--model) AIMUX_FAKE_MODEL=$2; shift 2 ;;
    --) shift; break ;;
    *) exit 64 ;;
  esac
done
[ "$#" -gt 0 ] || exit 64
export AIMUX_FAKE_PROFILE AIMUX_FAKE_MODEL
exec "$@"
FAKE_AIMUX
chmod +x "$TEST_ROOT/bin/aimux"

# --- fake codex ---
cat > "$TEST_ROOT/bin/codex" <<'FAKE_CODEX'
#!/usr/bin/env sh
[ "$1" = "-a" ] && [ "$2" = "never" ] || exit 64
shift 2
model=''
netarg=''
reasoning=''
rollout=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -c)
      case "$2" in
        model_reasoning_effort=*) reasoning=${2#*=} ;;
        sandbox_workspace_write.network_access=*) netarg=$2 ;;
        features.rollout_budget=*) rollout=$2 ;;
        *) exit 64 ;;
      esac
      shift 2 ;;
    -m) model=$2; shift 2 ;;
    exec) shift; break ;;
    *) exit 64 ;;
  esac
done
out=''
prompt=''
json=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) out=$2; shift 2 ;;
    -m) model=$2; shift 2 ;;
    -s) shift 2 ;;
    --json) json=1; shift ;;
    -*) exit 64 ;;
    *) prompt=$1; shift ;;
  esac
done

# Adapter diagnostics go to stderr so --json stdout remains a valid event stream.
[ -z "$netarg" ] || printf 'CF_NETWORK_ARG=%s\n' "$netarg" >&2
[ -z "$rollout" ] || printf 'CF_ROLLOUT_ARG=%s\n' "$rollout" >&2

if [ "${CF_TEST_ROLLOUT_EXHAUST:-0}" -eq 1 ]; then
  printf '%s\n' 'shared rollout token budget exhausted' >&2
  exit 1
fi

if [ "${CF_TEST_FAIL:-0}" -eq 1 ]; then
  exit 17
fi

# CF_FAIL_PROFILE makes one pool member fail (e.g. rate-limited) without on-disk profile dirs:
# the fake aimux exports AIMUX_FAKE_PROFILE, and this exits 42 when it matches.
if [ "${AIMUX_FAKE_PROFILE:-}" = "${CF_FAIL_PROFILE:-__cf_no_match__}" ] && [ "${CF_TEST_RATE_LIMIT:-0}" -eq 0 ]; then
  exit 42
fi

if [ "${CF_TEST_RATE_LIMIT:-0}" -eq 1 ] && [ "${AIMUX_FAKE_PROFILE:-}" = "${CF_FAIL_PROFILE:-__cf_no_match__}" ]; then
  printf 'error: rate limit, try again later\n' >&2
  exit 17
fi

if [ "${CF_TEST_HANG:-0}" -eq 1 ]; then
  sleep 30
  exit 0
fi

if [ "${CF_TEST_PROGRESS:-0}" -eq 1 ]; then
  i=0
  while [ "$i" -lt 30 ]; do
    i=$((i + 1))
    printf '{"type":"progress","step":%s}\n' "$i"
    sleep 1
  done
  exit 0
fi

# CF_PROMPT_OUT, when set, captures the exact prompt text codex received — used to verify
# --var substitution reached the CLI, not just that dispatch exited 0.
[ -z "${CF_PROMPT_OUT:-}" ] || printf '%s' "$prompt" > "$CF_PROMPT_OUT"

if [ -n "$out" ]; then
  result="ok${CF_ENV_SEEN:+:$CF_ENV_SEEN}${model:+:model=$model}${AIMUX_FAKE_MODEL:+:aimux-model=$AIMUX_FAKE_MODEL}${netarg:+:net=$netarg}${reasoning:+:reasoning=$reasoning}${rollout:+:rollout=$rollout}"
  printf '%s\n' "$result" > "$out"
fi
if [ "$json" -eq 1 ]; then
  printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":100,"cached_input_tokens":40,"cache_write_input_tokens":10,"output_tokens":25,"reasoning_output_tokens":5}}'
fi
FAKE_CODEX
chmod +x "$TEST_ROOT/bin/codex"

# --- fake ~/.aimux/config.yaml (block style, as aimux 0.25.0 writes it) ---
cat > "$TEST_ROOT/home/.aimux/config.yaml" <<'FAKE_CONFIG'
profiles:
  reg:
    cli: codex
    path: ~/.aimux/profiles/reg
  pool-bad:
    cli: codex
    path: ~/.aimux/profiles/pool-bad
    model: gpt-5.6-luna
  pool-good:
    cli: codex
    path: ~/.aimux/profiles/pool-good
  claudeonly:
    cli: claude
    path: ~/.aimux/profiles/claudeonly
private:
  telemetry: false
FAKE_CONFIG

PATH="$TEST_ROOT/bin:$PATH"
export PATH
export HOME="$TEST_ROOT/home"

D="$SCRIPT_DIR/dispatch.sh"
H="$SCRIPT_DIR/dispatch-health.sh"

# 1. read-only dispatch writes the report
"$D" --profile reg --mode read-only --prompt test --out "$TEST_ROOT/out/report.md" >/dev/null
test "$(cat "$TEST_ROOT/out/report.md")" = 'ok'

# 2. --env-file is sourced before the CLI runs
printf '%s\n' 'export CF_ENV_SEEN=env-file' > "$TEST_ROOT/build-env.sh"
"$D" --profile reg --mode read-only --prompt test \
  --env-file "$TEST_ROOT/build-env.sh" --out "$TEST_ROOT/out/env-report.md" >/dev/null
test "$(cat "$TEST_ROOT/out/env-report.md")" = 'ok:env-file'

# 3. background writes the .exit sentinel and the child-started log line
CF_TEST_FAIL=1
export CF_TEST_FAIL
"$D" --profile reg --mode workspace-write --prompt test \
  --log "$TEST_ROOT/out/build.log" --background >/dev/null
attempt=0
while [ ! -f "$TEST_ROOT/out/build.exit" ] && [ "$attempt" -lt 50 ]; do
  attempt=$((attempt + 1)); sleep 0.02
done
test -f "$TEST_ROOT/out/build.exit"
test "$(cat "$TEST_ROOT/out/build.exit")" = '17'
grep -F 'DISPATCH child started' "$TEST_ROOT/out/build.log" >/dev/null
unset CF_TEST_FAIL

# 4. read-only pool retry: first profile's CLI fails, second succeeds, summary names the second
CF_FAIL_PROFILE=pool-bad
CF_TEST_RATE_LIMIT=1
export CF_FAIL_PROFILE CF_TEST_RATE_LIMIT
out=$("$D" --profile pool-bad,pool-good --mode read-only --prompt test \
  --out "$TEST_ROOT/out/pool-report.md")
printf '%s\n' "$out" | grep -F 'profile=pool-good' >/dev/null
printf '%s\n' "$out" | grep -F "used 'pool-good'" >/dev/null
test "$(cat "$TEST_ROOT/out/pool-report.md")" = 'ok'
unset CF_FAIL_PROFILE CF_TEST_RATE_LIMIT

# 5. workspace-write does not retry after launch
CF_FAIL_PROFILE=pool-bad
export CF_FAIL_PROFILE
"$D" --profile pool-bad,pool-good --mode workspace-write --prompt test \
  --log "$TEST_ROOT/out/pool-build.log" --background >/dev/null
attempt=0
while [ ! -f "$TEST_ROOT/out/pool-build.exit" ] && [ "$attempt" -lt 50 ]; do
  attempt=$((attempt + 1)); sleep 0.02
done
test -f "$TEST_ROOT/out/pool-build.exit"
test "$(cat "$TEST_ROOT/out/pool-build.exit")" = '42'
unset CF_FAIL_PROFILE

# 6. no profile resolvable and no cli: entry → non-zero exit, error names `aimux profile add`, no output
if "$D" --profile nope1,nope2 --mode read-only --prompt test \
  --out "$TEST_ROOT/out/none.md" 2>"$TEST_ROOT/out/none.err"; then
  printf 'dispatch-test: unresolvable pool should have failed\n' >&2; exit 1
fi
grep -F 'aimux profile add' "$TEST_ROOT/out/none.err" >/dev/null
test ! -f "$TEST_ROOT/out/none.md"

# 7. cli:codex fallback entry runs directly; summary carries `cost is NOT separated`
out=$("$D" --profile nope1,cli:codex --mode read-only --prompt test \
  --out "$TEST_ROOT/out/bare.md")
printf '%s\n' "$out" | grep -F 'cost is NOT separated' >/dev/null
printf '%s\n' "$out" | grep -F 'profile=cli:codex' >/dev/null
test "$(cat "$TEST_ROOT/out/bare.md")" = 'ok'

# 8. --model on a resolved profile reaches `aimux run -m`
"$D" --profile reg --mode read-only --prompt test --model test-model-x \
  --out "$TEST_ROOT/out/model-profile.md" >/dev/null
test "$(cat "$TEST_ROOT/out/model-profile.md")" = 'ok:model=test-model-x:aimux-model=test-model-x'

# 9. --model on a cli: fallback entry reaches codex's own -m (after exec)
"$D" --profile cli:codex --mode read-only --prompt test --model test-model-x \
  --out "$TEST_ROOT/out/model-bare.md" >/dev/null
test "$(cat "$TEST_ROOT/out/model-bare.md")" = 'ok:model=test-model-x'

# 21. --reasoning-effort is distinct from --model and reaches Codex configuration
out=$("$D" --profile reg --mode read-only --prompt test --model test-model-x \
  --reasoning-effort medium --out "$TEST_ROOT/out/reasoning.md")
printf '%s\n' "$out" | grep -F 'reasoning_effort=medium' >/dev/null
test "$(cat "$TEST_ROOT/out/reasoning.md")" = 'ok:model=test-model-x:aimux-model=test-model-x:reasoning=medium'

# 22. an invalid reasoning level is rejected before dispatch
if "$D" --profile reg --mode read-only --prompt test --reasoning-effort invalid \
  --out "$TEST_ROOT/out/invalid-reasoning.md" 2>"$TEST_ROOT/out/invalid-reasoning.err"; then
  printf 'dispatch-test: invalid reasoning effort should have failed\n' >&2; exit 1
fi
grep -F -- '--reasoning-effort must be none, low, medium, high, or xhigh' \
  "$TEST_ROOT/out/invalid-reasoning.err" >/dev/null
test ! -f "$TEST_ROOT/out/invalid-reasoning.md"

# 10. a profile whose cli has no adapter → die before dispatching, no output file
if "$D" --profile claudeonly --mode read-only --prompt test \
  --out "$TEST_ROOT/out/noadapter.md" 2>"$TEST_ROOT/out/noadapter.err"; then
  printf 'dispatch-test: unsupported cli should have failed\n' >&2; exit 1
fi
grep -F 'no dispatch adapter' "$TEST_ROOT/out/noadapter.err" >/dev/null
test ! -f "$TEST_ROOT/out/noadapter.md"

# 11. --network rejected under read-only
if "$D" --profile reg --mode read-only --network --prompt test \
  --out "$TEST_ROOT/out/net-ro.md" 2>"$TEST_ROOT/out/net-ro.err"; then
  printf 'dispatch-test: --network under read-only should have failed\n' >&2; exit 1
fi
grep -F -- '--network applies to --mode workspace-write or danger-full-access only' \
  "$TEST_ROOT/out/net-ro.err" >/dev/null

# 12. --network accepted under danger-full-access, and the sandbox override reaches codex
"$D" --profile reg --mode danger-full-access --network --prompt test \
  --out "$TEST_ROOT/out/net-danger.md" >/dev/null
test "$(cat "$TEST_ROOT/out/net-danger.md")" = 'ok:net=sandbox_workspace_write.network_access=true'

# 13. danger-full-access dispatches like any other mode
"$D" --profile reg --mode danger-full-access --prompt test \
  --out "$TEST_ROOT/out/danger.md" >/dev/null
test "$(cat "$TEST_ROOT/out/danger.md")" = 'ok'

# 14. --background under read-only is rejected
if "$D" --profile reg --mode read-only --background --log "$TEST_ROOT/out/bg-ro.log" \
  2>"$TEST_ROOT/out/bg-ro.err"; then
  printf 'dispatch-test: --background under read-only should have failed\n' >&2; exit 1
fi
grep -F 'background requires --mode workspace-write or danger-full-access' \
  "$TEST_ROOT/out/bg-ro.err" >/dev/null

# 15. one missing profile, a later one resolves → FALLBACK names the missing one and the used one
out=$("$D" --profile nope1,pool-good --mode read-only --prompt test \
  --out "$TEST_ROOT/out/partial.md")
printf '%s\n' "$out" | grep -F 'not in' >/dev/null
printf '%s\n' "$out" | grep -F "used 'pool-good'" >/dev/null
test "$(cat "$TEST_ROOT/out/partial.md")" = 'ok'

# 16. the removed flags are gone — each is now an unknown argument
for flag in --cli --account --fallback; do
  if "$D" "$flag" x --profile reg --mode read-only --prompt test \
    --out "$TEST_ROOT/out/removed.md" 2>"$TEST_ROOT/out/removed.err"; then
    printf 'dispatch-test: %s should be unknown now\n' "$flag" >&2; exit 1
  fi
  grep -F "unknown argument '$flag'" "$TEST_ROOT/out/removed.err" >/dev/null
done

# 17. --background without --log is rejected
if "$D" --profile reg --mode workspace-write --background \
  2>"$TEST_ROOT/out/bg-nolog.err"; then
  printf 'dispatch-test: --background without --log should have failed\n' >&2; exit 1
fi
grep -F 'background requires --log' "$TEST_ROOT/out/bg-nolog.err" >/dev/null

# 18. --var fills a prompt-file placeholder; the CLI receives the substituted text
printf 'Hello {{NAME}}' > "$TEST_ROOT/prompt-var.txt"
CF_PROMPT_OUT="$TEST_ROOT/out/prompt-seen.txt"
export CF_PROMPT_OUT
"$D" --profile reg --mode read-only --prompt-file "$TEST_ROOT/prompt-var.txt" --var NAME=world \
  --out "$TEST_ROOT/out/var.md" >/dev/null
test "$(cat "$TEST_ROOT/out/prompt-seen.txt")" = 'Hello world'
unset CF_PROMPT_OUT

# 19. an unfilled placeholder aborts before dispatch, with no output file
printf 'Hello {{MISSING}}' > "$TEST_ROOT/prompt-missing.txt"
if "$D" --profile reg --mode read-only --prompt-file "$TEST_ROOT/prompt-missing.txt" \
  --out "$TEST_ROOT/out/missing-var.md" 2>"$TEST_ROOT/out/missing-var.err"; then
  printf 'dispatch-test: unfilled placeholder should have failed\n' >&2; exit 1
fi
grep -F 'unfilled placeholders' "$TEST_ROOT/out/missing-var.err" >/dev/null
test ! -f "$TEST_ROOT/out/missing-var.md"

# 20. --network with --background also forwards -c to the child (the --out path in case 12
# cannot cover this: the background path never passes -o, so CF_NETWORK_ARG on stdout,
# captured into --log, is the only way to see it)
"$D" --profile reg --mode workspace-write --network --prompt test \
  --log "$TEST_ROOT/out/net-bg.log" --background >/dev/null
attempt=0
while [ ! -f "$TEST_ROOT/out/net-bg.exit" ] && [ "$attempt" -lt 50 ]; do
  attempt=$((attempt + 1)); sleep 0.02
done
test -f "$TEST_ROOT/out/net-bg.exit"
grep -F 'CF_NETWORK_ARG=sandbox_workspace_write.network_access=true' "$TEST_ROOT/out/net-bg.log" >/dev/null

# 23. a successful preflight and compact ledger are recorded
printf '%s\n' 'test -n "$PATH"' > "$TEST_ROOT/preflight-ok.sh"
"$D" --profile reg --mode read-only --phase planning --prompt test --preflight "$TEST_ROOT/preflight-ok.sh" \
  --job-id preflight-job --ledger "$TEST_ROOT/out/preflight.ledger" \
  --out "$TEST_ROOT/out/preflight.md" >/dev/null
grep -F 'preflight-job' "$TEST_ROOT/out/preflight.ledger" >/dev/null
grep -F 'planning' "$TEST_ROOT/out/preflight.ledger" >/dev/null
grep -F 'passed' "$TEST_ROOT/out/preflight.ledger" >/dev/null

# 24. a failed preflight blocks before Codex and is not retryable
printf '%s\n' 'printf preflight-broken >&2; exit 9' > "$TEST_ROOT/preflight-fail.sh"
if "$D" --profile reg,pool-good --mode read-only --prompt test --preflight "$TEST_ROOT/preflight-fail.sh" \
  --ledger "$TEST_ROOT/out/preflight-fail.ledger" --out "$TEST_ROOT/out/preflight-fail.md" \
  2>"$TEST_ROOT/out/preflight-fail.err"; then
  printf 'dispatch-test: failed preflight should have failed\n' >&2; exit 1
fi
grep -F 'preflight-broken' "$TEST_ROOT/out/preflight-fail.err" >/dev/null
grep -F 'environment.preflight' "$TEST_ROOT/out/preflight-fail.ledger" >/dev/null
test ! -f "$TEST_ROOT/out/preflight-fail.md"

# 25. model evidence fails closed when a child model differs from the effective model
printf '%s\n' 'test-model-x' > "$TEST_ROOT/models-ok.txt"
"$D" --profile reg --mode read-only --prompt test --model test-model-x \
  --model-evidence "$TEST_ROOT/models-ok.txt" --out "$TEST_ROOT/out/models-ok.md" >/dev/null
printf '%s\n' 'test-model-x' 'gpt-6-astra' > "$TEST_ROOT/models-bad.txt"
if "$D" --profile reg --mode read-only --prompt test --model test-model-x \
  --model-evidence "$TEST_ROOT/models-bad.txt" --out "$TEST_ROOT/out/models-bad.md" \
  >"$TEST_ROOT/out/models-bad-summary"; then
  printf 'dispatch-test: unexpected model should have failed\n' >&2; exit 1
fi
grep -F 'failure_class=model-routing' "$TEST_ROOT/out/models-bad-summary" >/dev/null

# 26. implementation fails closed without an explicit model
if "$D" --profile reg --phase implementation --mode workspace-write --background --prompt test \
  --max-rollout-tokens 12345 --log "$TEST_ROOT/out/impl-no-model.log" \
  2>"$TEST_ROOT/out/impl-no-model.err"; then
  printf 'dispatch-test: implementation without --model should have failed\n' >&2; exit 1
fi
grep -F -- '--phase implementation requires explicit --model' "$TEST_ROOT/out/impl-no-model.err" >/dev/null

# 27. implementation fails closed without an execution budget
if "$D" --profile reg --phase implementation --mode workspace-write --background --prompt test \
  --model test-model-x --log "$TEST_ROOT/out/impl-no-budget.log" \
  2>"$TEST_ROOT/out/impl-no-budget.err"; then
  printf 'dispatch-test: implementation without --max-rollout-tokens should have failed\n' >&2; exit 1
fi
grep -F -- '--phase implementation requires --max-rollout-tokens' "$TEST_ROOT/out/impl-no-budget.err" >/dev/null

# 28. implementation pins model and rollout budget independently of the paying profile
summary=$("$D" --profile pool-bad,pool-good --phase implementation --mode workspace-write --background \
  --prompt test --model test-model-x --max-rollout-tokens 12345 \
  --ledger "$TEST_ROOT/out/impl-ok.ledger" --log "$TEST_ROOT/out/impl-ok.log")
printf '%s\n' "$summary" | grep -F 'model=test-model-x' >/dev/null
printf '%s\n' "$summary" | grep -F 'rollout_budget=12345' >/dev/null
attempt=0
while [ ! -f "$TEST_ROOT/out/impl-ok.exit" ] && [ "$attempt" -lt 50 ]; do
  attempt=$((attempt + 1)); sleep 0.02
done
test -f "$TEST_ROOT/out/impl-ok.exit"
test "$(cat "$TEST_ROOT/out/impl-ok.exit")" = '0'
grep -F 'CF_ROLLOUT_ARG=features.rollout_budget={enabled=true,limit_tokens=12345' "$TEST_ROOT/out/impl-ok.log" >/dev/null
grep -F 'test-model-x' "$TEST_ROOT/out/impl-ok.ledger" >/dev/null
grep -F '12345' "$TEST_ROOT/out/impl-ok.ledger" >/dev/null
grep -F 'pinned' "$TEST_ROOT/out/impl-ok.ledger" >/dev/null
if ! grep -F "$(printf '100\t40\t10\t25\t5\t125')" "$TEST_ROOT/out/impl-ok.ledger" >/dev/null; then
  printf 'dispatch-test: background native usage missing; ledger follows\n' >&2
  cat "$TEST_ROOT/out/impl-ok.ledger" >&2
  printf 'dispatch-test: background event stream follows\n' >&2
  cat "$TEST_ROOT/out/impl-ok.log.events.jsonl" >&2
  exit 1
fi
grep -F '"type":"turn.completed"' "$TEST_ROOT/out/impl-ok.log.events.jsonl" >/dev/null

# 29. background model evidence is checked before the sentinel reports success
printf '%s\n' 'test-model-x' 'gpt-6-astra' > "$TEST_ROOT/models-bg-bad.txt"
"$D" --profile reg --phase implementation --mode workspace-write --background --prompt test \
  --model test-model-x --max-rollout-tokens 12345 --model-evidence "$TEST_ROOT/models-bg-bad.txt" \
  --ledger "$TEST_ROOT/out/impl-model-bad.ledger" --log "$TEST_ROOT/out/impl-model-bad.log" >/dev/null
attempt=0
while [ ! -f "$TEST_ROOT/out/impl-model-bad.exit" ] && [ "$attempt" -lt 50 ]; do
  attempt=$((attempt + 1)); sleep 0.02
done
test -f "$TEST_ROOT/out/impl-model-bad.exit"
test "$(cat "$TEST_ROOT/out/impl-model-bad.exit")" = '78'
grep -F 'model-routing' "$TEST_ROOT/out/impl-model-bad.ledger" >/dev/null
grep -F 'failed' "$TEST_ROOT/out/impl-model-bad.ledger" >/dev/null

# 30. rollout-budget exhaustion is classified from raw stderr and is never retried
CF_TEST_ROLLOUT_EXHAUST=1
export CF_TEST_ROLLOUT_EXHAUST
if "$D" --profile pool-bad,pool-good --mode read-only --prompt test --max-rollout-tokens 1 \
  --out "$TEST_ROOT/out/budget-fail.md" >"$TEST_ROOT/out/budget-fail.summary"; then
  printf 'dispatch-test: exhausted rollout budget should have failed\n' >&2; exit 1
fi
unset CF_TEST_ROLLOUT_EXHAUST
grep -F 'failure_class=budget' "$TEST_ROOT/out/budget-fail.summary" >/dev/null
grep -F 'profile=pool-bad' "$TEST_ROOT/out/budget-fail.summary" >/dev/null
grep -F 'shared rollout token budget exhausted' "$TEST_ROOT/out/budget-fail.md.attempt-1.log" >/dev/null

# 31. rollout budget must be a positive integer
if "$D" --profile reg --mode read-only --prompt test --max-rollout-tokens 0 \
  --out "$TEST_ROOT/out/budget-zero.md" 2>"$TEST_ROOT/out/budget-zero.err"; then
  printf 'dispatch-test: zero rollout budget should have failed\n' >&2; exit 1
fi
grep -F -- '--max-rollout-tokens must be a positive integer' "$TEST_ROOT/out/budget-zero.err" >/dev/null

# 32. read-only phases cannot silently widen permissions
if "$D" --profile reg --phase planning --mode workspace-write --prompt test \
  --out "$TEST_ROOT/out/phase-mode.md" 2>"$TEST_ROOT/out/phase-mode.err"; then
  printf 'dispatch-test: planning under workspace-write should have failed\n' >&2; exit 1
fi
grep -F -- '--phase planning requires --mode read-only' "$TEST_ROOT/out/phase-mode.err" >/dev/null

# 33. foreground Codex JSON usage populates the ledger without CF_* environment variables
"$D" --profile reg --phase planning --mode read-only --prompt test \
  --ledger "$TEST_ROOT/out/native-usage.ledger" --out "$TEST_ROOT/out/native-usage.md" >/dev/null
grep -F "$(printf '100\t40\t10\t25\t5\t125')" "$TEST_ROOT/out/native-usage.ledger" >/dev/null
grep -F 'cached_input_tokens' "$TEST_ROOT/out/native-usage.ledger" >/dev/null
grep -F '"type":"turn.completed"' "$TEST_ROOT/out/native-usage.md.attempt-1.jsonl" >/dev/null

# 34. a silent hung background worker is terminated by the supervisor and classified as stalled
CF_TEST_HANG=1
export CF_TEST_HANG
summary=$("$D" --profile reg --phase implementation --mode workspace-write --background   --prompt test --model test-model-x --max-rollout-tokens 12345   --heartbeat-seconds 1 --stall-timeout-seconds 2 --wall-timeout-seconds 10   --ledger "$TEST_ROOT/out/stall.ledger" --log "$TEST_ROOT/out/stall.log")
printf '%s
' "$summary" | grep -F 'health=' >/dev/null
attempt=0
while [ ! -f "$TEST_ROOT/out/stall.exit" ] && [ "$attempt" -lt 100 ]; do
  attempt=$((attempt + 1)); sleep 0.05
done
unset CF_TEST_HANG
test -f "$TEST_ROOT/out/stall.exit"
test "$(cat "$TEST_ROOT/out/stall.exit")" = '124'
grep -F 'timeout.stalled' "$TEST_ROOT/out/stall.ledger" >/dev/null
grep -F "$(printf 'retryable	failure_class')" "$TEST_ROOT/out/stall.ledger" >/dev/null
grep -F "$(printf '	1	timeout.stalled	')" "$TEST_ROOT/out/stall.ledger" >/dev/null
set +e
health=$(sh "$H" --log "$TEST_ROOT/out/stall.log")
health_rc=$?
set -e
test "$health_rc" -eq 0
printf '%s
' "$health" | grep -F 'state=finished' >/dev/null
printf '%s
' "$health" | grep -F 'reason=timeout.stalled' >/dev/null

# 35. observable progress prevents stall detection but the hard wall ceiling still terminates the job
CF_TEST_PROGRESS=1
export CF_TEST_PROGRESS
"$D" --profile reg --phase implementation --mode workspace-write --background   --prompt test --model test-model-x --max-rollout-tokens 12345   --heartbeat-seconds 1 --stall-timeout-seconds 10 --wall-timeout-seconds 2   --ledger "$TEST_ROOT/out/wall.ledger" --log "$TEST_ROOT/out/wall.log" >/dev/null
attempt=0
while [ ! -f "$TEST_ROOT/out/wall.exit" ] && [ "$attempt" -lt 100 ]; do
  attempt=$((attempt + 1)); sleep 0.05
done
unset CF_TEST_PROGRESS
test -f "$TEST_ROOT/out/wall.exit"
test "$(cat "$TEST_ROOT/out/wall.exit")" = '124'
grep -F 'timeout.wall' "$TEST_ROOT/out/wall.ledger" >/dev/null

printf 'dispatch-test: ok
'
