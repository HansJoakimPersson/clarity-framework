#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/out"

cat > "$TEST_ROOT/bin/codex" <<'FAKE_CODEX'
#!/usr/bin/env sh

[ "$1" = "-a" ] && [ "$2" = "never" ] || exit 64
shift 2
model=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -c) shift 2 ;;
    -m) model=$2; shift 2 ;;
    exec) shift; break ;;
    *) exit 64 ;;
  esac
done

out=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) out=$2; shift 2 ;;
    *) shift ;;
  esac
done

if [ "${CF_TEST_FAIL:-0}" -eq 1 ]; then
  exit 17
fi

# CF_FAIL_HOME_SUFFIX simulates one account in a pool being unavailable (e.g. rate-limited):
# any CODEX_HOME ending in that suffix fails, so a caller can test that dispatch.sh moves on to
# the next account in an --account pool instead of the fake binary needing real aimux profiles.
case "${CODEX_HOME:-}" in
  *"${CF_FAIL_HOME_SUFFIX:-__none__}") exit 42 ;;
esac

[ -z "$out" ] || printf 'ok%s%s\n' "${CF_ENV_SEEN:+:$CF_ENV_SEEN}" "${model:+:model=$model}" > "$out"
FAKE_CODEX
chmod +x "$TEST_ROOT/bin/codex"

PATH="$TEST_ROOT/bin:$PATH"
export PATH

"$SCRIPT_DIR/dispatch.sh" --profile clarity-dispatch-regression --mode read-only --prompt test \
  --out "$TEST_ROOT/out/report.md" >/dev/null
test "$(cat "$TEST_ROOT/out/report.md")" = 'ok'

printf '%s\n' 'export CF_ENV_SEEN=env-file' > "$TEST_ROOT/build-env.sh"
"$SCRIPT_DIR/dispatch.sh" --profile clarity-dispatch-regression --mode read-only --prompt test \
  --env-file "$TEST_ROOT/build-env.sh" --out "$TEST_ROOT/out/env-report.md" >/dev/null
test "$(cat "$TEST_ROOT/out/env-report.md")" = 'ok:env-file'

CF_TEST_FAIL=1
export CF_TEST_FAIL
"$SCRIPT_DIR/dispatch.sh" --profile clarity-dispatch-regression --mode workspace-write --prompt test \
  --log "$TEST_ROOT/out/build.log" --background >/dev/null

attempt=0
while [ ! -f "$TEST_ROOT/out/build.exit" ] && [ "$attempt" -lt 50 ]; do
  attempt=$((attempt + 1))
  sleep 0.02
done

test -f "$TEST_ROOT/out/build.exit"
test "$(cat "$TEST_ROOT/out/build.exit")" = '17'
grep -F 'DISPATCH child started' "$TEST_ROOT/out/build.log" >/dev/null

unset CF_TEST_FAIL

# --- Account pool: read-only retries the next account when the first fails ---
#
# Neither account needs a real aimux profile directory; the fake codex above fails only when
# CODEX_HOME ends in CF_FAIL_HOME_SUFFIX, so a nonexistent-but-named "bad" account stands in for a
# rate-limited one without needing $HOME/.aimux/profiles/* on disk.
CF_FAIL_HOME_SUFFIX=bad
export CF_FAIL_HOME_SUFFIX
mkdir -p "$TEST_ROOT/aimux-home/.aimux/profiles/pool-bad" "$TEST_ROOT/aimux-home/.aimux/profiles/pool-good"
out=$(HOME="$TEST_ROOT/aimux-home" "$SCRIPT_DIR/dispatch.sh" \
  --account pool-bad,pool-good --mode read-only --prompt test \
  --out "$TEST_ROOT/out/pool-report.md")
printf '%s\n' "$out" | grep -F 'account=pool-good' >/dev/null
printf '%s\n' "$out" | grep -F "used 'pool-good'" >/dev/null
test "$(cat "$TEST_ROOT/out/pool-report.md")" = 'ok'
unset CF_FAIL_HOME_SUFFIX

# --- Account pool: workspace-write does not retry after the dispatch has started ---
#
# The pool still picks the first account whose profile directory exists; once launched, a failure
# is reported, not silently retried on the next account in the pool.
CF_FAIL_HOME_SUFFIX=bad
export CF_FAIL_HOME_SUFFIX
CF_TEST_FAIL=0
export CF_TEST_FAIL
HOME="$TEST_ROOT/aimux-home" "$SCRIPT_DIR/dispatch.sh" \
  --account pool-bad,pool-good --mode workspace-write --prompt test \
  --log "$TEST_ROOT/out/pool-build.log" --background >/dev/null

attempt=0
while [ ! -f "$TEST_ROOT/out/pool-build.exit" ] && [ "$attempt" -lt 50 ]; do
  attempt=$((attempt + 1))
  sleep 0.02
done
test -f "$TEST_ROOT/out/pool-build.exit"
test "$(cat "$TEST_ROOT/out/pool-build.exit")" = '42'
unset CF_FAIL_HOME_SUFFIX CF_TEST_FAIL

# --- No account in the pool exists: falls back to the logged-in account and says so plainly ---
out=$(HOME="$TEST_ROOT/aimux-home" "$SCRIPT_DIR/dispatch.sh" \
  --account nope1,nope2 --mode read-only --prompt test --out "$TEST_ROOT/out/none-report.md")
printf '%s\n' "$out" | grep -F 'cost is NOT separated' >/dev/null

# --- --model is passed through to codex regardless of which account handles the dispatch ---
"$SCRIPT_DIR/dispatch.sh" --profile clarity-dispatch-regression --mode read-only --prompt test \
  --model test-model-x --out "$TEST_ROOT/out/model-report.md" >/dev/null
test "$(cat "$TEST_ROOT/out/model-report.md")" = 'ok:model=test-model-x'

printf 'dispatch-test: ok\n'
