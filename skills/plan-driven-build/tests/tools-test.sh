#!/usr/bin/env sh

# Regression test for the small tools around dispatch: usage.awk, dispatch-tail.sh, evidence.sh,
# and project-health.sh.

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

fail() { printf 'tools-test: %s\n' "$1" >&2; exit 1; }

# --- usage.awk -----------------------------------------------------------------------------------

# 1. per-turn usage is summed across turns
cat > "$TEST_ROOT/turns.jsonl" <<'EOF'
{"type":"turn.completed","usage":{"input_tokens":100,"cached_input_tokens":40,"cache_write_input_tokens":10,"output_tokens":25,"reasoning_output_tokens":5}}
{"type":"item.completed","item":{"type":"agent_message","text":"input_tokens are not usage here"}}
{"type": "turn.completed", "usage": {"input_tokens": 50, "cached_input_tokens": 20, "output_tokens": 5}}
EOF
test "$(awk -f "$SCRIPT_DIR/usage.awk" "$TEST_ROOT/turns.jsonl")" = '150 60 10 30 5' || fail 'per-turn usage not summed'

# 2. a run that never completes a turn still reports its last cumulative total, not a sum of them
cat > "$TEST_ROOT/cumulative.jsonl" <<'EOF'
{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":800,"output_tokens":90,"reasoning_output_tokens":30},"last_token_usage":{"input_tokens":7}}}}
{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":2500,"cached_input_tokens":2000,"output_tokens":200,"reasoning_output_tokens":60},"last_token_usage":{"input_tokens":9}}}}
EOF
test "$(awk -f "$SCRIPT_DIR/usage.awk" "$TEST_ROOT/cumulative.jsonl")" = '2500 2000 0 200 60' || fail 'cumulative usage fallback wrong'

# 3. per-turn usage wins when both shapes are present, and no usage prints nothing
cat "$TEST_ROOT/cumulative.jsonl" "$TEST_ROOT/turns.jsonl" > "$TEST_ROOT/both.jsonl"
test "$(awk -f "$SCRIPT_DIR/usage.awk" "$TEST_ROOT/both.jsonl")" = '150 60 10 30 5' || fail 'per-turn usage must win'
printf '%s\n' '{"type":"progress","step":1}' > "$TEST_ROOT/none.jsonl"
test -z "$(awk -f "$SCRIPT_DIR/usage.awk" "$TEST_ROOT/none.jsonl")" || fail 'no usage must print nothing'

# --- dispatch-tail.sh ----------------------------------------------------------------------------

# 4. events become one bounded readable line each; only the last N are shown
cat > "$TEST_ROOT/events.jsonl" <<'EOF'
{"type":"item.completed","item":{"id":"item_1","type":"command_execution","command":"bash -lc \"old command\"","exit_code":0}}
{"type":"item.completed","item":{"id":"item_2","type":"command_execution","command":"npm run verify:node","aggregated_output":"EMFILE: too many open files","exit_code":1,"status":"failed"}}
{"type":"item.completed","item":{"id":"item_3","type":"agent_message","text":"Retrying the\nwatcher tests once more."}}
{"type":"error","message":"shared rollout token budget exhausted"}
EOF
tail_out=$(sh "$SCRIPT_DIR/dispatch-tail.sh" --events "$TEST_ROOT/events.jsonl" --lines 3)
test "$(printf '%s\n' "$tail_out" | wc -l | tr -d ' ')" = 3 || fail 'dispatch-tail must print exactly the last N events'
printf '%s\n' "$tail_out" | grep -F 'item.completed/command_execution  $ npm run verify:node  exit=1' >/dev/null || fail 'command line not rendered'
printf '%s\n' "$tail_out" | grep -F 'item.completed/agent_message  Retrying the watcher tests once more.' >/dev/null || fail 'message text not rendered'
printf '%s\n' "$tail_out" | grep -F 'error  shared rollout token budget exhausted' >/dev/null || fail 'error message not rendered'
if printf '%s\n' "$tail_out" | grep -F 'old command' >/dev/null; then fail 'dispatch-tail showed more than the last N events'; fi

# 5. long fields are clipped to the width
long=$(awk 'BEGIN { for (i = 0; i < 500; i++) printf "x" }')
printf '{"type":"item.completed","item":{"type":"agent_message","text":"%s"}}\n' "$long" > "$TEST_ROOT/long.jsonl"
clipped=$(sh "$SCRIPT_DIR/dispatch-tail.sh" --events "$TEST_ROOT/long.jsonl" --width 40)
test "${#clipped}" -lt 120 || fail 'dispatch-tail did not clip a long field'

# 6. a missing events file is a usage error, not empty output
if sh "$SCRIPT_DIR/dispatch-tail.sh" --events "$TEST_ROOT/absent.jsonl" 2>/dev/null; then
  fail 'dispatch-tail must fail on a missing events file'
fi

# --- evidence.sh ---------------------------------------------------------------------------------

REPO="$TEST_ROOT/repo"
mkdir -p "$REPO/docs/plans/.runs/x"
git -C "$REPO" init -q
git -C "$REPO" config user.name 'Clarity test'
git -C "$REPO" config user.email 'clarity-test@example.invalid'
printf 'a\n' > "$REPO/a.txt"
git -C "$REPO" add a.txt
git -C "$REPO" commit -qm initial
EV="docs/plans/.runs/x/evidence.md"

# 7. a passing command is recorded with its exit code, commit, and the tail of its output
summary=$(cd "$REPO" && sh "$SCRIPT_DIR/evidence.sh" --out "$EV" --label gate \
  --cmd 'printf "line one\nTests run: 12, Failures: 0\n"')
printf '%s\n' "$summary" | grep -F 'EVIDENCE label=gate exit=0' >/dev/null || fail 'evidence summary missing'
grep -F '## gate' "$REPO/$EV" >/dev/null || fail 'evidence heading missing'
grep -F -- '- exit: 0' "$REPO/$EV" >/dev/null || fail 'evidence exit missing'
grep -F 'Tests run: 12, Failures: 0' "$REPO/$EV" >/dev/null || fail 'evidence tail missing'
grep -F 'by the orchestrator outside the dispatch sandbox' "$REPO/$EV" >/dev/null || fail 'evidence source missing'
test -f "$REPO/docs/plans/.runs/x/evidence/1-gate.log" || fail 'full output log missing'

# 8. a failing command is still recorded, the script itself succeeds, and entries accumulate
rc=0
summary=$(cd "$REPO" && sh "$SCRIPT_DIR/evidence.sh" --out "$EV" --label baseline \
  --cmd 'echo "18 of 24 failed"; exit 3') || rc=$?
test "$rc" -eq 0 || fail 'recording a failing command must not fail the script'
printf '%s\n' "$summary" | grep -F 'exit=3' >/dev/null || fail 'failing exit code not reported'
grep -F -- '- exit: 3' "$REPO/$EV" >/dev/null || fail 'failing exit not recorded'
grep -F '## gate' "$REPO/$EV" >/dev/null || fail 'earlier entry was overwritten'

# 9. the command's stdin is closed and a timeout ends a command that will not finish
(cd "$REPO" && sh "$SCRIPT_DIR/evidence.sh" --out "$EV" --label stdin --cmd 'cat; echo stdin-closed' \
  < /dev/zero >/dev/null)
grep -F 'stdin-closed' "$REPO/$EV" >/dev/null || fail 'command stdin was not closed'
summary=$(cd "$REPO" && sh "$SCRIPT_DIR/evidence.sh" --out "$EV" --label slow --timeout-seconds 1 \
  --cmd 'sleep 30')
printf '%s\n' "$summary" | grep -F 'exit=124' >/dev/null || fail 'timeout not reported as 124'
grep -F 'timed out after 1s' "$REPO/$EV" >/dev/null || fail 'timeout not recorded'

# 10. a dirty tree is recorded as such, and an invalid label is rejected
printf 'b\n' >> "$REPO/a.txt"
(cd "$REPO" && sh "$SCRIPT_DIR/evidence.sh" --out "$EV" --label dirty --cmd true >/dev/null)
grep -F '(dirty tree)' "$REPO/$EV" >/dev/null || fail 'dirty tree not recorded'
if (cd "$REPO" && sh "$SCRIPT_DIR/evidence.sh" --out "$EV" --label 'bad label' --cmd true 2>/dev/null); then
  fail 'a label with a space must be rejected'
fi
git -C "$REPO" checkout -q -- a.txt

# --- project-health.sh ---------------------------------------------------------------------------

health() { (cd "$REPO" && sh "$SCRIPT_DIR/project-health.sh"); }

# 11. a tidy project produces no notes and exits 0
printf 'docs/plans/.runs/\n' > "$REPO/.gitignore"
git -C "$REPO" add .gitignore
git -C "$REPO" commit -qm ignore
out=$(health)
printf '%s\n' "$out" | grep -Fx 'PROJECT_HEALTH notes=0' >/dev/null || { printf '%s\n' "$out" >&2; fail 'tidy project must report no notes'; }

# 12. an oversized AI Context, a stale plan, a plan without a journal, and drifted skill copies are
# each reported, and the report still exits 0
mkdir -p "$REPO/.agents/skills/plan-driven-build" "$REPO/.claude/skills/plan-driven-build"
printf 'one\n' > "$REPO/.agents/skills/plan-driven-build/SKILL.md"
printf 'two\n' > "$REPO/.claude/skills/plan-driven-build/SKILL.md"
{
  printf '# AI Context\n\n| **Last updated** | 2020-01-01 |\n\n'
  awk 'BEGIN { for (i = 0; i < 130; i++) print "- delivered FR-" i }'
  printf '\n## AI workflow\n\ncontract\n'
} > "$REPO/docs/00-ai-context.md"
printf '# Plan\n\n| **Delivers** | None – tooling |\n' > "$REPO/docs/plans/2020-01-01-old.md"
touch -t 202001010000 "$REPO/docs/plans/2020-01-01-old.md"
rc=0
out=$(health) || rc=$?
test "$rc" -eq 0 || fail 'project-health must not fail on findings'
printf '%s\n' "$out" | grep -F 'NOTE  ai-context:' >/dev/null || fail 'long AI Context not reported'
printf '%s\n' "$out" | grep -F 'NOTE  plans: untouched for more than 14 days' >/dev/null || fail 'stale plan not reported'
printf '%s\n' "$out" | grep -F 'no run journal beside: 2020-01-01-old.md' >/dev/null || fail 'missing journal not reported'
printf '%s\n' "$out" | grep -F 'NOTE  skills:' >/dev/null || fail 'skill drift not reported'

# 13. three plans in a row that deliver no requirement are reported; a delivering plan resets it
git -C "$REPO" add -A
git -C "$REPO" commit -qm 'plan 1'
for n in 2 3; do
  printf '# Plan\n\n| **Delivers** | None – more tooling |\n' > "$REPO/docs/plans/2020-01-0$n-x.md"
  git -C "$REPO" add -A
  git -C "$REPO" commit -qm "plan $n"
done
out=$(health)
printf '%s\n' "$out" | grep -F 'NOTE  delivers: the last 3 plans deliver no requirement' >/dev/null || { printf '%s\n' "$out" >&2; fail 'Delivers: None streak not reported'; }
printf '# Plan\n\n| **Delivers** | FR-004 |\n' > "$REPO/docs/plans/2020-01-04-x.md"
git -C "$REPO" add -A
git -C "$REPO" commit -qm 'plan 4'
out=$(health)
if printf '%s\n' "$out" | grep -F 'NOTE  delivers:' >/dev/null; then fail 'a delivering plan must reset the streak'; fi

# 14. modified tracked work older than a day is reported; fresh changes are not
printf 'c\n' >> "$REPO/a.txt"
out=$(health)
if printf '%s\n' "$out" | grep -F 'NOTE  worktree:' >/dev/null; then fail 'fresh changes must not be reported as old'; fi
touch -t 202001010000 "$REPO/a.txt"
out=$(health)
printf '%s\n' "$out" | grep -F 'NOTE  worktree: 1 of 1 modified tracked files' >/dev/null || fail 'old uncommitted work not reported'

# 15. a build env file without a preflight, and documented CI that does not exist, are reported
mkdir -p "$REPO/.agents"
: > "$REPO/.agents/build-env.sh"
printf 'CI runs on GitHub Actions.\n' > "$REPO/docs/06-test-documentation.md"
out=$(health)
printf '%s\n' "$out" | grep -F 'without .agents/preflight.sh' >/dev/null || fail 'missing preflight not reported'
printf '%s\n' "$out" | grep -F 'describe GitHub Actions' >/dev/null || fail 'missing CI workflow not reported'

# 16. a repository in a synced directory with a conflict copy is reported
SYNC="$TEST_ROOT/Mobile Documents/proj"
mkdir -p "$SYNC"
git -C "$SYNC" init -q
git -C "$SYNC" config user.name 'Clarity test'
git -C "$SYNC" config user.email 'clarity-test@example.invalid'
printf 'x\n' > "$SYNC/SKILL.md"
printf 'x\n' > "$SYNC/SKILL 2.md"
git -C "$SYNC" add -A
git -C "$SYNC" commit -qm initial
out=$(cd "$SYNC" && sh "$SCRIPT_DIR/project-health.sh")
printf '%s\n' "$out" | grep -F 'cloud-synced directory; 1 conflict-copy file(s)' >/dev/null || { printf '%s\n' "$out" >&2; fail 'synced location not reported'; }
printf '%s\n' "$out" | grep -F 'path contains a space' >/dev/null || fail 'space in path not reported'

printf 'tools-test: ok\n'
