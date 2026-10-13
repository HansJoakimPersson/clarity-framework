#!/usr/bin/env sh

# Clarity Framework – project health report for plan-driven work.
#
# The framework states rules that nothing enforces: plans are deleted at closeout, the AI Context
# stays compact, work is committed, both runtime copies of a skill match. Each of them has been
# found broken for weeks in a real project because nothing looked. This script looks. It reports
# and never blocks: every finding is a `NOTE` line for the orchestrator to weigh and journal, and
# the exit code is 0 unless the script itself was misused.
#
# Run it from the project root at step 0 of a run and again at closeout.
#
# Usage: project-health.sh [--docs DIR] [--plans DIR] [--max-plan-days N] [--max-runs-mb N]

set -eu

die() { printf '%s\n' "$1" >&2; exit 2; }

DOCS=docs
PLANS=''
MAX_PLAN_DAYS=14
MAX_RUNS_MB=20
while [ "$#" -gt 0 ]; do
  case "$1" in
    --docs) DOCS="${2:-}"; shift 2 ;;
    --plans) PLANS="${2:-}"; shift 2 ;;
    --max-plan-days) MAX_PLAN_DAYS="${2:-}"; shift 2 ;;
    --max-runs-mb) MAX_RUNS_MB="${2:-}"; shift 2 ;;
    *) die "project-health.sh: unknown argument '$1'" ;;
  esac
done
[ -n "$PLANS" ] || PLANS="$DOCS/plans"
case "$MAX_PLAN_DAYS:$MAX_RUNS_MB" in
  *[!0-9:]*|:*|*:) die 'project-health.sh: --max-plan-days and --max-runs-mb must be non-negative integers' ;;
esac
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die 'project-health.sh: run from a Git repository'
cd "$ROOT"

notes=0
note() { notes=$((notes + 1)); printf 'NOTE  %s: %s\n' "$1" "$2"; }
ok() { printf 'ok    %s: %s\n' "$1" "$2"; }

# --- AI Context size -------------------------------------------------------------------------
ctx="$DOCS/00-ai-context.md"
if [ -r "$ctx" ]; then
  ctx_bytes=$(wc -c < "$ctx" | tr -d ' ')
  hot_lines=$(awk '/^## AI workflow[[:space:]]*$/ { exit } { n++ } END { print n + 0 }' "$ctx")
  if [ "$ctx_bytes" -gt 16384 ]; then
    note ai-context "$ctx is $ctx_bytes bytes (limit 16384); move delivered work to change management and history to docs/archive/"
  elif [ "$hot_lines" -gt 110 ]; then
    note ai-context "the part of $ctx above '## AI workflow' is $hot_lines lines (about one page is 100); it is a snapshot, not a log"
  else
    ok ai-context "$ctx_bytes bytes, $hot_lines lines above the workflow contract"
  fi
  updated=$(sed -n 's/^| \*\*Last updated\*\* | \([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\).*/\1/p' "$ctx" | head -1)
  if [ -n "$updated" ]; then
    since=$(git rev-list --count --since="$updated 23:59:59" HEAD 2>/dev/null || printf 0)
    if [ "$since" -gt 25 ]; then
      note ai-context "last updated $updated, $since commits ago; confirm 'Current status' still describes the project"
    fi
  fi
else
  ok ai-context "no $ctx"
fi

# --- Plans that outlived their change ----------------------------------------------------------
if [ -d "$PLANS" ]; then
  plan_count=0; stale=''; unjournaled=''
  for plan in "$PLANS"/*.md; do
    [ -f "$plan" ] || continue
    case "$plan" in *.run.md) continue ;; esac
    plan_count=$((plan_count + 1))
    [ -f "${plan%.md}.run.md" ] || unjournaled="$unjournaled $(basename "$plan")"
    if [ -n "$(find "$plan" -mtime +"$MAX_PLAN_DAYS" 2>/dev/null)" ]; then
      stale="$stale $(basename "$plan")"
    fi
  done
  if [ -n "$stale" ]; then
    note plans "untouched for more than $MAX_PLAN_DAYS days — close out and delete, or resume:$stale"
  fi
  if [ "$plan_count" -gt 3 ]; then
    note plans "$plan_count plans are open at once; a plan is transient and is deleted when its change merges"
  fi
  [ -n "$stale" ] || [ "$plan_count" -gt 3 ] || ok plans "$plan_count open"
  [ -z "$unjournaled" ] || note plans "no run journal beside:$unjournaled"

  if [ -d "$PLANS/.runs" ]; then
    runs_kb=$(du -sk "$PLANS/.runs" 2>/dev/null | awk '{ print $1 }')
    if [ "${runs_kb:-0}" -gt $((MAX_RUNS_MB * 1024)) ]; then
      note runs "$PLANS/.runs holds $((runs_kb / 1024)) MB of raw output; remove the directories of closed plans"
    else
      ok runs "$((${runs_kb:-0} / 1024)) MB of raw output"
    fi
  fi

  # Consecutive recent plans that deliver no requirement. One is maintenance; a run of them is
  # product work happening outside the requirements.
  streak=0
  for added in $(git log -n 40 --diff-filter=A --format='%H' -- "$PLANS/*.md" 2>/dev/null); do
    for file in $(git show --name-only --diff-filter=A --format= "$added" -- "$PLANS/*.md" 2>/dev/null); do
      case "$file" in *.run.md) continue ;; esac
      delivers=$(git show "$added:$file" 2>/dev/null | sed -n 's/^| \*\*Delivers\*\* | *//p' | head -1)
      case "$delivers" in
        None*|none*) streak=$((streak + 1)) ;;
        '') ;;
        *) break 2 ;;
      esac
    done
  done
  if [ "$streak" -ge 3 ]; then
    note delivers "the last $streak plans deliver no requirement (Delivers: None). Confirm the work is maintenance, not product behavior without a story"
  fi
fi

# --- Work that exists only in the working tree -------------------------------------------------
old_dirty=0; dirty=0
for path in $(git diff --name-only HEAD 2>/dev/null | tr ' ' '?'); do
  dirty=$((dirty + 1))
  [ -e "$path" ] || continue
  [ -z "$(find "$path" -mtime +0 2>/dev/null)" ] || old_dirty=$((old_dirty + 1))
done
untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
if [ "$old_dirty" -gt 0 ]; then
  note worktree "$old_dirty of $dirty modified tracked files were last changed more than a day ago and are still uncommitted; commit or discard before building on them"
elif [ "$dirty" -gt 0 ] || [ "$untracked" -gt 0 ]; then
  ok worktree "$dirty modified, $untracked untracked, none older than a day"
else
  ok worktree clean
fi

# --- Where the repository lives ------------------------------------------------------------------
case "$ROOT" in
  *'/Mobile Documents/'*|*/OneDrive*|*/Dropbox*|*'/Google Drive'*|*/CloudStorage/*|*/pCloud*)
    copies=$(git ls-files --others --cached --exclude-standard 2>/dev/null | grep -cE ' [0-9]+(\.[^/ ]+)*$' || true)
    note location "repository is in a cloud-synced directory; ${copies:-0} conflict-copy file(s) such as 'SKILL 2.md' are present. Build in a git worktree outside the synced root" ;;
esac
case "$ROOT" in
  *' '*) note location "repository path contains a space; whitespace-split variables such as MAVEN_OPTS need relative paths" ;;
esac

# --- Runtime copies of managed skills ------------------------------------------------------------
if [ -d .agents/skills ] && [ -d .claude/skills ]; then
  drift=''
  for dir in .agents/skills/*/; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    [ -d ".claude/skills/$name" ] || continue
    diff -qr ".agents/skills/$name" ".claude/skills/$name" >/dev/null 2>&1 || drift="$drift $name"
  done
  if [ -n "$drift" ]; then
    note skills "the .agents and .claude copies differ for:$drift. Managed skills are framework-owned; project changes inside them are lost at the next update"
  else
    ok skills 'runtime copies match'
  fi
fi

# --- Tooling the documents claim -------------------------------------------------------------------
if [ -d "$DOCS" ] && grep -rlqi 'github actions' "$DOCS"/[0-9][0-9]-*.md 2>/dev/null; then
  if ! ls .github/workflows/*.yml .github/workflows/*.yaml >/dev/null 2>&1; then
    note tooling 'the documents describe GitHub Actions but .github/workflows/ has no workflow'
  fi
fi
if [ -f .agents/build-env.sh ] || [ -f .agents/build-env.local.sh ]; then
  [ -f .agents/preflight.sh ] || note tooling 'a build env file exists without .agents/preflight.sh; a preflight that runs the build tool catches a broken environment before a build spends its budget on it'
fi

printf 'PROJECT_HEALTH notes=%s\n' "$notes"
