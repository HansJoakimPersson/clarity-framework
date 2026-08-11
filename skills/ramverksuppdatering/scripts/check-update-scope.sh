#!/usr/bin/env bash

# Classify existing worktree changes before ramverksuppdatering writes anything. Source and other
# project-owned paths may remain dirty; only paths the framework might update are conflicts.

set -euo pipefail

die() { printf '%s\n' "$1" >&2; exit 2; }

FRAMEWORK_SKILLS=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --framework-skills) FRAMEWORK_SKILLS="${2:-}"; shift 2 ;;
    *) die "check-update-scope.sh: unknown argument '$1'" ;;
  esac
done

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die 'check-update-scope.sh: run from a Git repository'
cd -- "$REPO_ROOT"
[ -n "$FRAMEWORK_SKILLS" ] || die 'check-update-scope.sh: --framework-skills is required'

IFS=',' read -r -a SKILL_NAMES <<< "$FRAMEWORK_SKILLS"
for skill in "${SKILL_NAMES[@]}"; do
  [[ "$skill" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "check-update-scope.sh: invalid skill name '$skill'"
done

declare -a CONFLICTS=()
declare -a ALLOWED=()
declare -a BOOTSTRAP=()

is_framework_skill_path() {
  local path=$1 root skill
  for root in .agents/skills .claude/skills; do
    for skill in "${SKILL_NAMES[@]}"; do
      [[ "$path" == "$root/$skill" || "$path" == "$root/$skill/"* ]] && return 0
    done
  done
  return 1
}

is_untracked_updater_bootstrap() {
  local status=$1 path=$2 root
  [[ "$status" == '??' ]] || return 1
  for root in .agents/skills .claude/skills; do
    [[ "$path" == "$root/ramverksuppdatering" || "$path" == "$root/ramverksuppdatering/"* ]] && return 0
  done
  return 1
}

classify() {
  local status=$1 path=$2
  if is_untracked_updater_bootstrap "$status" "$path"; then
    BOOTSTRAP+=("$status $path")
  elif is_framework_skill_path "$path"; then
    CONFLICTS+=("$status $path")
  else
    case "$path" in
      AGENTS.md|CLAUDE.md|.gitignore|docs/.clarity-version|docs/[0-9][0-9]-*.md)
        CONFLICTS+=("$status $path") ;;
      *)
        ALLOWED+=("$status $path") ;;
    esac
  fi
}

while IFS= read -r -d '' record; do
  status=${record:0:2}
  path=${record:3}
  classify "$status" "$path"

  # Porcelain v1 -z records the second path of a rename/copy as the next NUL-delimited record.
  if [[ ${status:0:1} == R || ${status:0:1} == C ]]; then
    IFS= read -r -d '' original || die 'check-update-scope.sh: malformed rename/copy status'
    classify "$status" "$original"
  fi
done < <(git status --porcelain=v1 -z --untracked-files=all)

if [ "${#CONFLICTS[@]}" -gt 0 ]; then
  printf '%s\n' 'UPDATE-SCOPE: blocked; resolve or explicitly approve these update-surface changes first:' >&2
  printf '  %s\n' "${CONFLICTS[@]}" >&2
  exit 2
fi

printf 'UPDATE-SCOPE: allowed unrelated dirty paths: %s\n' "${#ALLOWED[@]}"
[ "${#ALLOWED[@]}" -eq 0 ] || printf '  %s\n' "${ALLOWED[@]}"
printf 'UPDATE-SCOPE: allowed untracked updater bootstrap paths: %s\n' "${#BOOTSTRAP[@]}"
[ "${#BOOTSTRAP[@]}" -eq 0 ] || printf '  %s\n' "${BOOTSTRAP[@]}"
