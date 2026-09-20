#!/usr/bin/env bash

# Verify that Clarity-managed runtime skills were copied exactly from the pinned target release.
# For project-driver, also verify its required dependency and optionally run runtime smoke tests.

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
    if ! diff -qr "$TARGET_ROOT/skills/$skill" "$installed" >/dev/null; then
      printf 'RUNTIME-VERIFY: installed %s differs from target release at %s\n' "$skill" "$installed" >&2
      diff -qr "$TARGET_ROOT/skills/$skill" "$installed" >&2 || true
      exit 2
    fi
  done
done

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

  required_plan_driver=(
    dispatch.sh
    background-supervisor.sh
    dispatch-health.sh
    tests/dispatch-test.sh
  )
  for rel in "${required_plan_driver[@]}"; do
    for runtime_root in .agents/skills .claude/skills; do
      [ -f "$runtime_root/plan-driven-build/$rel" ] ||
        die "RUNTIME-VERIFY: plan-driven-build payload missing: $runtime_root/plan-driven-build/$rel"
    done
  done

  if [ "$SMOKE" = yes ]; then
    bash .agents/skills/project-driver/tests/authority-test.sh
    bash .agents/skills/project-driver/tests/mission-control-test.sh
    bash .agents/skills/project-driver/tests/mission-runner-test.sh
    sh .agents/skills/plan-driven-build/tests/dispatch-test.sh
  fi
fi

printf 'RUNTIME-VERIFY: ok managed_skills=%s smoke=%s\n' "${MANAGED_SKILLS:-none}" "$SMOKE"
