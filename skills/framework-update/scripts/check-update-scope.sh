#!/usr/bin/env bash

# Classify existing worktree changes before framework-update writes anything. Source and other
# project-owned paths may remain dirty; only paths the framework might update are conflicts.

set -euo pipefail

die() { printf '%s\n' "$1" >&2; exit 2; }

FRAMEWORK_SKILLS=''
MANAGED_SKILLS=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --framework-skills) FRAMEWORK_SKILLS="${2:-}"; shift 2 ;;
    --managed-skills) MANAGED_SKILLS="${2:-}"; shift 2 ;;
    *) die "check-update-scope.sh: unknown argument '$1'" ;;
  esac
done

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die 'check-update-scope.sh: run from a Git repository'
cd -- "$REPO_ROOT"
[ -n "$FRAMEWORK_SKILLS" ] || die 'check-update-scope.sh: --framework-skills is required'

ALL_SKILLS="$FRAMEWORK_SKILLS"
[ -z "$MANAGED_SKILLS" ] || ALL_SKILLS="$ALL_SKILLS,$MANAGED_SKILLS"
IFS=',' read -r -a SKILL_NAMES <<< "$ALL_SKILLS"
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
    [[ "$path" == "$root/framework-update" || "$path" == "$root/framework-update/"* ]] && return 0
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
      AGENTS.md|CLAUDE.md|.gitignore|docs/[0-9][0-9]-*.md)
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
  # The block is correct but its cause is usually ordinary: say what clears it.
  copies=0
  for entry in "${CONFLICTS[@]}"; do
    if [[ "${entry:0:2}" == '??' && "${entry:3}" =~ \ [0-9]+(\.[^/\ ]+)*$ ]]; then copies=$((copies + 1)); fi
  done
  printf '%s\n' 'UPDATE-SCOPE: hint: these paths are ones the update itself writes. Commit them (an ordinary commit of your own work is enough) or discard them, then run the update again. Nothing has been changed.' >&2
  if [ "$copies" -gt 0 ]; then
    printf 'UPDATE-SCOPE: hint: %s untracked path(s) end in a space and a number, the name a sync client (iCloud, Dropbox, OneDrive) gives a conflict copy. They are duplicates, not project content: delete them.\n' "$copies" >&2
  fi
  exit 2
fi

printf 'UPDATE-SCOPE: allowed unrelated dirty paths: %s\n' "${#ALLOWED[@]}"
[ "${#ALLOWED[@]}" -eq 0 ] || printf '  %s\n' "${ALLOWED[@]}"
printf 'UPDATE-SCOPE: allowed untracked updater bootstrap paths: %s\n' "${#BOOTSTRAP[@]}"
[ "${#BOOTSTRAP[@]}" -eq 0 ] || printf '  %s\n' "${BOOTSTRAP[@]}"
