#!/usr/bin/env bash

# Verify that Clarity-managed runtime skills were copied exactly from the pinned target release.
# For plan-driven-build and project-driver, also verify the required payload and optionally run the
# installed runtime's smoke tests.
#
# It writes nothing, so it also serves as a standalone check between updates: point --target-root
# at a checkout of the release the project records and run it with --smoke no in a project gate to
# catch an edited or half-copied managed skill before the next update does.

set -euo pipefail

die() { printf '%s\n' "$1" >&2; exit 2; }

TARGET_ROOT=''
MANAGED_SKILLS=''
SMOKE=yes

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-root) TARGET_ROOT="${2:-}"; shift 2 ;;
    --managed-skills) MANAGED_SKILLS="${2:-}"; shift 2 ;;
    --smoke) SMOKE="${2:-}"; shift 2 ;;
    *) die "verify-managed-runtime.sh: unknown argument '$1'" ;;
  esac
done

[ -n "$TARGET_ROOT" ] || die 'verify-managed-runtime.sh: --target-root is required'
[ -d "$TARGET_ROOT/skills" ] || die "verify-managed-runtime.sh: target skills directory missing: $TARGET_ROOT/skills"
git rev-parse --show-toplevel >/dev/null 2>&1 ||
  die 'verify-managed-runtime.sh: run from the project Git repository'
case "$SMOKE" in yes|no) ;; *) die 'verify-managed-runtime.sh: --smoke must be yes or no' ;; esac

declare -a SKILLS=()
if [ -n "$MANAGED_SKILLS" ]; then
  IFS=',' read -r -a SKILLS <<< "$MANAGED_SKILLS"
fi

has_skill() {
  local wanted=$1 skill
  for skill in "${SKILLS[@]}"; do
    [ "$skill" = "$wanted" ] && return 0
  done
  return 1
}

for skill in "${SKILLS[@]}"; do
  [[ "$skill" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "verify-managed-runtime.sh: invalid skill name '$skill'"
  [ -d "$TARGET_ROOT/skills/$skill" ] ||
    die "RUNTIME-VERIFY: managed skill '$skill' is not shipped by target release"

  for runtime_root in .agents/skills .claude/skills; do
    installed="$runtime_root/$skill"
    [ -d "$installed" ] || die "RUNTIME-VERIFY: missing installed skill: $installed"
    if ! diff -qr -x .DS_Store "$TARGET_ROOT/skills/$skill" "$installed" >/dev/null; then
      printf 'RUNTIME-VERIFY: installed %s differs from target release at %s\n' "$skill" "$installed" >&2
      diff -qr -x .DS_Store "$TARGET_ROOT/skills/$skill" "$installed" >&2 || true
      if find "$installed" -type f -name '* [0-9]*' 2>/dev/null | grep -qE ' [0-9]+(\.[^/ ]+)*$'; then
        printf '%s\n' 'RUNTIME-VERIFY: hint: a file name ending in a space and a number is a sync-conflict copy (iCloud, Dropbox, OneDrive). Delete it and verify again.' >&2
      fi
      exit 2
    fi

    while IFS= read -r -d '' target_file; do
      rel=${target_file#"$TARGET_ROOT/skills/$skill/"}
      installed_file="$installed/$rel"
      if git check-ignore -q -- "$installed_file"; then
        die "RUNTIME-VERIFY: managed runtime file is ignored by Git: $installed_file"
      fi
    done < <(find "$TARGET_ROOT/skills/$skill" -type f -print0)
  done
done

if has_skill plan-driven-build; then
  required_plan_driver=(
    SKILL.md
    setup.md
    plan-template.md
    journal-template.md
    dispatch.sh
    background-supervisor.sh
    dispatch-health.sh
    dispatch-tail.sh
    context-pack.sh
    evidence.sh
    project-health.sh
    usage.awk
    prompts/1-plan.txt
    prompts/2-review.txt
    prompts/3-revise.txt
    prompts/4-build.txt
    prompts/5-verification.txt
    tests/dispatch-test.sh
    tests/context-pack-test.sh
    tests/tools-test.sh
  )
  for rel in "${required_plan_driver[@]}"; do
    for runtime_root in .agents/skills .claude/skills; do
      [ -f "$runtime_root/plan-driven-build/$rel" ] ||
        die "RUNTIME-VERIFY: plan-driven-build payload missing: $runtime_root/plan-driven-build/$rel"
    done
  done
  # dispatch.sh is invoked by path, so a copy that lost its mode fails at the first dispatch.
  for runtime_root in .agents/skills .claude/skills; do
    [ -x "$runtime_root/plan-driven-build/dispatch.sh" ] ||
      die "RUNTIME-VERIFY: not executable: $runtime_root/plan-driven-build/dispatch.sh (copy with cp -R, or chmod +x)"
  done

  if [ "$SMOKE" = yes ]; then
    sh .agents/skills/plan-driven-build/tests/dispatch-test.sh
    sh .agents/skills/plan-driven-build/tests/context-pack-test.sh
    sh .agents/skills/plan-driven-build/tests/tools-test.sh
  fi
fi

if has_skill project-driver; then
  has_skill plan-driven-build ||
    die 'RUNTIME-VERIFY: managed project-driver requires managed plan-driven-build'

  required_project_driver=(
    SKILL.md
    scripts/authority.sh
    scripts/mission-control.sh
    scripts/mission-runner.sh
    prompts/mission-cycle.txt
    prompts/mission-completion-audit.txt
    tests/authority-test.sh
    tests/mission-control-test.sh
    tests/mission-runner-test.sh
  )
  for rel in "${required_project_driver[@]}"; do
    for runtime_root in .agents/skills .claude/skills; do
      [ -f "$runtime_root/project-driver/$rel" ] ||
        die "RUNTIME-VERIFY: project-driver payload missing: $runtime_root/project-driver/$rel"
    done
  done

  if [ "$SMOKE" = yes ]; then
    bash .agents/skills/project-driver/tests/authority-test.sh
    bash .agents/skills/project-driver/tests/mission-control-test.sh
    bash .agents/skills/project-driver/tests/mission-runner-test.sh
  fi
fi

printf 'RUNTIME-VERIFY: ok managed_skills=%s smoke=%s\n' "${MANAGED_SKILLS:-none}" "$SMOKE"
