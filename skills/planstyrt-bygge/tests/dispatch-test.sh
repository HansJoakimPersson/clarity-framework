#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/out"

cat > "$TEST_ROOT/bin/codex" <<'FAKE_CODEX'
#!/usr/bin/env sh

[ "$1" = "-a" ] && [ "$2" = "never" ] && [ "$3" = "exec" ] || exit 64

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

[ -z "$out" ] || printf 'ok\n' > "$out"
FAKE_CODEX
chmod +x "$TEST_ROOT/bin/codex"

PATH="$TEST_ROOT/bin:$PATH"
export PATH

"$SCRIPT_DIR/dispatch.sh" --profile clarity-dispatch-regression --mode read-only --prompt test \
  --out "$TEST_ROOT/out/report.md" >/dev/null
test "$(cat "$TEST_ROOT/out/report.md")" = 'ok'

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

printf 'dispatch-test: ok\n'
