#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
INSPECT="$SCRIPT_DIR/scripts/inspect-project.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM

fail() { printf 'inspect-project-test: %s\n' "$1" >&2; exit 1; }
git_quiet() { git -c user.name='Clarity test' -c user.email='clarity-test@example.invalid' "$@"; }

# A framework history with two releases: 1.0.0 ships old-build, 1.1.0 renames it to new-build,
# changes the starter, and adds an optional skill.
FW="$TEST_ROOT/fw"
mkdir -p "$FW/skills/old-build" "$FW/agents" "$FW/templates"
git -C "$FW" init -q
printf 'build v1\n' > "$FW/skills/old-build/SKILL.md"
printf 'run v1\n' > "$FW/skills/old-build/run.sh"
printf '# AGENTS.md - Generic Application v1.0\n\nrules v1\n' > "$FW/agents/generic.md"
printf '# Requirements\n' > "$FW/templates/02-requirements.md"
printf '# Plan\n' > "$FW/templates/plan.md"
git_quiet -C "$FW" add . && git_quiet -C "$FW" commit -qm one && git -C "$FW" tag v1.0.0
git -C "$FW" mv skills/old-build skills/new-build
printf 'build v2\n' > "$FW/skills/new-build/SKILL.md"
mkdir -p "$FW/skills/extra"
printf 'extra\n' > "$FW/skills/extra/SKILL.md"
printf '# comment\n\nold-build  new-build  1.1.0\n' > "$FW/skills/RENAMES"
printf '# AGENTS.md - Generic Application v1.1\n\nrules v2\n' > "$FW/agents/generic.md"
git_quiet -C "$FW" add . && git_quiet -C "$FW" commit -qm two && git -C "$FW" tag v1.1.0

make_project() {
  local project="$TEST_ROOT/$1"
  mkdir -p "$project/docs" "$project/.agents/skills" "$project/.claude/skills"
  git -C "$project" init -q
  git -C "$FW" archive v1.0.0 -- skills/old-build | tar -x -C "$TEST_ROOT"
  cp -R "$TEST_ROOT/skills/old-build" "$project/.agents/skills/old-build"
  cp -R "$TEST_ROOT/skills/old-build" "$project/.claude/skills/old-build"
  rm -rf "$TEST_ROOT/skills"
  git -C "$FW" show v1.0.0:agents/generic.md > "$project/AGENTS.md"
  cat > "$project/docs/00-ai-context.md" <<'CTX'
| **Framework version** | Clarity Framework v1.0.0 |

agents-starter: generic
skills: old-build
skill-paths: .agents/skills, .claude/skills
CTX
  printf '# Requirements\n' > "$project/docs/02-requirements.md"
  git_quiet -C "$project" add . && git_quiet -C "$project" commit -qm initial
  printf '%s\n' "$project"
}

inspect() {
  local project=$1; shift
  (cd "$project" && bash "$INSPECT" --target-root "$FW" --target-version 1.1.0 "$@")
}

# 1. An untouched project on the older release: the rename is resolved, nothing needs a decision,
#    and the optional skill is reported as available.
clean=$(make_project clean)
inspect "$clean" > "$TEST_ROOT/clean.out" || fail 'a clean older project must not need a decision'
grep -qx 'RENAMED  old-build -> new-build' "$TEST_ROOT/clean.out" || fail 'rename not resolved'
grep -q '^NOTE     new-skill extra ' "$TEST_ROOT/clean.out" || fail 'available skill not reported'
grep -qx 'INSPECT managed=new-build decisions=0 notes=1' "$TEST_ROOT/clean.out" || fail "clean summary: $(tail -1 "$TEST_ROOT/clean.out")"
if grep -q '^RETIRED' "$TEST_ROOT/clean.out"; then fail 'a renamed skill was reported as retired'; fi

# 2. A project edit inside a managed skill is a decision, named by file, and exits 3.
edited=$(make_project edited)
printf 'project addition\n' >> "$edited/.agents/skills/old-build/run.sh"
set +e
inspect "$edited" > "$TEST_ROOT/edited.out"; rc=$?
set -e
[ "$rc" -eq 3 ] || fail "a local edit must exit 3, got $rc"
grep -q '^DECISION local-edit .agents/skills/old-build/run.sh ' "$TEST_ROOT/edited.out" || fail 'local edit not named'
grep -q '^NOTE     pair-drift ' "$TEST_ROOT/edited.out" || fail 'pair drift not reported'
if grep -q 'local-edit .claude/skills' "$TEST_ROOT/edited.out"; then fail 'the untouched copy was reported as edited'; fi
if grep -q 'local-edit .*SKILL.md' "$TEST_ROOT/edited.out"; then fail 'an unedited older file was reported as a local edit'; fi

# 3. A project rule added to AGENTS.md is a decision.
agents=$(make_project agents)
printf '\n## Local Verification Commands\n' >> "$agents/AGENTS.md"
set +e
inspect "$agents" > "$TEST_ROOT/agents.out"; rc=$?
set -e
[ "$rc" -eq 3 ] || fail "an edited AGENTS.md must exit 3, got $rc"
grep -q '^DECISION local-edit AGENTS.md ' "$TEST_ROOT/agents.out" || fail 'AGENTS.md edit not reported'

# 4. A starter newer than the release ships is a downgrade, not an update.
ahead=$(make_project starter-ahead)
printf '# AGENTS.md - Generic Application v1.3\n\nunreleased rules\n' > "$ahead/AGENTS.md"
set +e
inspect "$ahead" > "$TEST_ROOT/ahead.out"; rc=$?
set -e
[ "$rc" -eq 3 ] || fail "a newer starter must exit 3, got $rc"
grep -q '^DECISION starter-ahead AGENTS.md is starter v1.3 but v1.1.0 ships v1.1' "$TEST_ROOT/ahead.out" || fail 'starter downgrade not reported'

# 5. A project that records a version above the newest release.
set +e
inspect "$clean" --current-version 1.2.0 > "$TEST_ROOT/version.out"; rc=$?
set -e
[ "$rc" -eq 3 ] || fail "a project ahead of the release must exit 3, got $rc"
grep -q '^DECISION ahead project records Clarity Framework v1.2.0' "$TEST_ROOT/version.out" || fail 'version downgrade not reported'

# 6. Without a tag for the recorded release, differences are listed as notes instead of guessed.
set +e
inspect "$edited" --current-version 0.9.0 > "$TEST_ROOT/nobase.out"; rc=$?
set -e
[ "$rc" -eq 0 ] || fail "an unknown base must not invent decisions, got $rc"
grep -q '^NOTE     unknown-base ' "$TEST_ROOT/nobase.out" || fail 'unknown base not reported'
grep -q '^NOTE     differs .agents/skills/old-build/run.sh ' "$TEST_ROOT/nobase.out" || fail 'differing file not listed'

# 7. Clutter: sync-conflict copies, a copied template, a translated document name, old pool syntax.
clutter=$(make_project clutter)
printf 'dup\n' > "$clutter/.claude/skills/old-build/SKILL 2.md"
printf '# Plan (translated)\n' > "$clutter/docs/plan.md"
git -C "$clutter" mv docs/02-requirements.md docs/02-kravdokumentation.md
printf 'fallback: --local-fallback\n' >> "$clutter/docs/00-ai-context.md"
inspect "$clutter" > "$TEST_ROOT/clutter.out" || fail 'clutter alone must not need a decision'
grep -q "^NOTE     conflict-copy '.claude/skills/old-build/SKILL 2.md'" "$TEST_ROOT/clutter.out" || fail 'conflict copy not reported'
grep -q '^NOTE     template-copy docs/plan.md ' "$TEST_ROOT/clutter.out" || fail 'template copy not reported'
grep -q '^NOTE     doc-name docs/02-kravdokumentation.md .*02-requirements.md' "$TEST_ROOT/clutter.out" || fail 'translated document name not reported'
grep -q '^NOTE     pool-syntax ' "$TEST_ROOT/clutter.out" || fail 'old pool syntax not reported'
if grep -q 'local-edit' "$TEST_ROOT/clutter.out"; then fail 'a conflict copy was reported as a local edit'; fi

# 8. A name that is neither shipped nor renamed is retired.
inspect "$clean" --managed-skills old-build,gone > "$TEST_ROOT/retired.out"
grep -qx 'RETIRED  gone' "$TEST_ROOT/retired.out" || fail 'retired skill not reported'

# 9. Usage errors.
set +e
(cd "$clean" && bash "$INSPECT" --target-root "$FW" --target-version latest) > /dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "a malformed target version must exit 2, got $rc"

printf 'inspect-project-test: ok\n'
