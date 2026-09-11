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
while [ "$#" -gt 0 ]; do
  case "$1" in
    -c) netarg=$2; shift 2 ;;
    -m) model=$2; shift 2 ;;
    exec) shift; break ;;
    *) exit 64 ;;
  esac
done
out=''
prompt=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) out=$2; shift 2 ;;
    -m) model=$2; shift 2 ;;
    -s) shift 2 ;;
    -*) exit 64 ;;
    *) prompt=$1; shift ;;
  esac
done

# Visible on stdout even when --out is unset (the --background path never passes -o; its
# stdout+stderr land in --log instead), so a network-forwarding regression is catchable there too.
[ -z "$netarg" ] || printf 'CF_NETWORK_ARG=%s\n' "$netarg"

if [ "${CF_TEST_FAIL:-0}" -eq 1 ]; then
  exit 17
fi

# CF_FAIL_PROFILE makes one pool member fail (e.g. rate-limited) without on-disk profile dirs:
# the fake aimux exports AIMUX_FAKE_PROFILE, and this exits 42 when it matches.
case "${AIMUX_FAKE_PROFILE:-}" in
  "${CF_FAIL_PROFILE:-__cf_no_match__}") exit 42 ;;
esac

# CF_PROMPT_OUT, when set, captures the exact prompt text codex received — used to verify
# --var substitution reached the CLI, not just that dispatch exited 0.
[ -z "${CF_PROMPT_OUT:-}" ] || printf '%s' "$prompt" > "$CF_PROMPT_OUT"

[ -z "$out" ] || printf 'ok%s%s%s%s\n' \
  "${CF_ENV_SEEN:+:$CF_ENV_SEEN}" \
  "${model:+:model=$model}" \
  "${AIMUX_FAKE_MODEL:+:aimux-model=$AIMUX_FAKE_MODEL}" \
  "${netarg:+:net=$netarg}" > "$out"
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
    model: gpt-5.6-luna medium
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
export CF_FAIL_PROFILE
out=$("$D" --profile pool-bad,pool-good --mode read-only --prompt test \
  --out "$TEST_ROOT/out/pool-report.md")
printf '%s\n' "$out" | grep -F 'profile=pool-good' >/dev/null
printf '%s\n' "$out" | grep -F "used 'pool-good'" >/dev/null
test "$(cat "$TEST_ROOT/out/pool-report.md")" = 'ok'
unset CF_FAIL_PROFILE

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
test "$(cat "$TEST_ROOT/out/model-profile.md")" = 'ok:aimux-model=test-model-x'

# 9. --model on a cli: fallback entry reaches codex's own -m (after exec)
"$D" --profile cli:codex --mode read-only --prompt test --model test-model-x \
  --out "$TEST_ROOT/out/model-bare.md" >/dev/null
test "$(cat "$TEST_ROOT/out/model-bare.md")" = 'ok:model=test-model-x'

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

printf 'dispatch-test: ok\n'
