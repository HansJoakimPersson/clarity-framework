#!/usr/bin/env bash

# Inspect a project against the pinned target release before framework-update writes anything.
#
# check-update-scope.sh answers "is the update surface clean?". This script answers the questions a
# clean tree hides: was a managed skill renamed rather than retired, is the project ahead of the
# newest release, were framework-owned files edited in the project, and what in the project looks
# like a stale or duplicated framework file. It writes nothing.
#
# Output: one line per finding.
#   DECISION <kind> ...   replacing would lose or downgrade something; resolve before applying
#   NOTE     <kind> ...   report in the hand-back; does not block
#   RENAMED  old -> new   update under the new name and rewrite the `skills:` line
#   RETIRED  name         no longer shipped and not renamed
# and a final `INSPECT managed=<resolved names> decisions=N notes=N` line.
#
# Exit: 0 no decision needed, 3 at least one DECISION line, 2 usage error.
#
# Usage: inspect-project.sh --target-root DIR --target-version X.Y.Z
#          [--managed-skills a,b] [--starter NAME] [--current-version X.Y.Z] [--docs DIR]
# The three optional values default to what docs/00-ai-context.md records.

set -euo pipefail

die() { printf '%s\n' "$1" >&2; exit 2; }

TARGET_ROOT=''
TARGET_VERSION=''
MANAGED=''
MANAGED_SET=0
STARTER=''
CURRENT=''
DOCS=docs
while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-root) TARGET_ROOT="${2:-}"; shift 2 ;;
    --target-version) TARGET_VERSION="${2:-}"; shift 2 ;;
    --managed-skills) MANAGED="${2:-}"; MANAGED_SET=1; shift 2 ;;
    --starter) STARTER="${2:-}"; shift 2 ;;
    --current-version) CURRENT="${2:-}"; shift 2 ;;
    --docs) DOCS="${2:-}"; shift 2 ;;
    *) die "inspect-project.sh: unknown argument '$1'" ;;
  esac
done

[ -n "$TARGET_ROOT" ] || die 'inspect-project.sh: --target-root is required'
[ -d "$TARGET_ROOT/skills" ] || die "inspect-project.sh: target skills directory missing: $TARGET_ROOT/skills"
TARGET_VERSION=${TARGET_VERSION#v}
[[ "$TARGET_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'inspect-project.sh: --target-version must be X.Y.Z'
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die 'inspect-project.sh: run from the project Git repository'
cd -- "$REPO_ROOT"

CTX="$DOCS/00-ai-context.md"
if [ -r "$CTX" ]; then
  if [ "$MANAGED_SET" -eq 0 ]; then
    MANAGED=$(sed -n 's/^skills:[[:space:]]*//p' "$CTX" | head -1 | tr -d '[:space:]')
  fi
  [ -n "$STARTER" ] || STARTER=$(sed -n 's/^agents-starter:[[:space:]]*//p' "$CTX" | head -1 | tr -d '[:space:]')
  [ -n "$CURRENT" ] || CURRENT=$(grep -m1 -F 'Framework version' "$CTX" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
fi
CURRENT=${CURRENT#v}
[ -z "$CURRENT" ] || [[ "$CURRENT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'inspect-project.sh: --current-version must be X.Y.Z'
case "$STARTER" in none|'['*) STARTER='' ;; esac
case "$MANAGED" in '['*) MANAGED='' ;; esac

decisions=0
notes=0
decision() { decisions=$((decisions + 1)); printf 'DECISION %s\n' "$1"; }
note() { notes=$((notes + 1)); printf 'NOTE     %s\n' "$1"; }

# 0 when $1 is a higher version than $2; both are dotted numbers of any length.
version_gt() {
  local -a a b
  local i x y
  IFS=. read -r -a a <<< "$1"
  IFS=. read -r -a b <<< "$2"
  for i in 0 1 2; do
    x=${a[$i]:-0}; y=${b[$i]:-0}
    [ "$((10#$x))" -gt "$((10#$y))" ] && return 0
    [ "$((10#$x))" -lt "$((10#$y))" ] && return 1
  done
  return 1
}

is_conflict_copy() { [[ "$1" =~ \ [0-9]+(\.[^/\ ]+)*$ ]]; }

WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT HUP INT TERM

# The release the project says it has, extracted from the same clone, is what separates "an older
# framework copy" (expected, replace it) from "a copy somebody edited here" (would be lost).
BASE_TAG=''
if [ -n "$CURRENT" ] && git -C "$TARGET_ROOT" rev-parse -q --verify "refs/tags/v$CURRENT" >/dev/null 2>&1; then
  BASE_TAG="v$CURRENT"
fi

base_tree() {
  # Print a directory holding path $1 as of the base release, or nothing when it did not exist.
  local path=$1 out="$WORK/base/$1"
  [ -n "$BASE_TAG" ] || return 0
  if [ ! -e "$WORK/base-done/$path" ]; then
    mkdir -p "$WORK/base" "$WORK/base-done/$(dirname "$path")"
    : > "$WORK/base-done/$path"
    if git -C "$TARGET_ROOT" cat-file -e "$BASE_TAG:$path" 2>/dev/null; then
      git -C "$TARGET_ROOT" archive "$BASE_TAG" -- "$path" | tar -x -C "$WORK/base"
    fi
  fi
  [ -e "$out" ] && printf '%s\n' "$out"
  return 0
}

# --- Version direction ---------------------------------------------------------------------------
if [ -n "$CURRENT" ] && version_gt "$CURRENT" "$TARGET_VERSION"; then
  decision "ahead project records Clarity Framework v$CURRENT but the newest release is v$TARGET_VERSION; updating would downgrade it. The project was installed from an unreleased state: wait for a release, or confirm the downgrade"
fi
if [ -n "$CURRENT" ] && [ -z "$BASE_TAG" ] && ! version_gt "$CURRENT" "$TARGET_VERSION"; then
  note "unknown-base release v$CURRENT has no tag; a difference from the target cannot be told apart from a project edit, so differing framework-owned files are listed below for review"
fi

# --- Managed skill names: renamed, retired, resolved ---------------------------------------------
declare -a NAMES=()
if [ -n "$MANAGED" ]; then IFS=',' read -r -a NAMES <<< "$MANAGED"; fi
declare -a RESOLVED=()
declare -a INSTALLED_AS=()
renamed_to() {
  local old=$1 file="$TARGET_ROOT/skills/RENAMES" from to rest hops=0 current
  current=$old
  [ -r "$file" ] || return 1
  while [ "$hops" -lt 5 ]; do
    to=''
    while read -r from to_candidate rest; do
      case "$from" in ''|'#'*) continue ;; esac
      if [ "$from" = "$current" ]; then to=$to_candidate; break; fi
    done < "$file"
    [ -n "$to" ] || break
    current=$to
    hops=$((hops + 1))
    [ -d "$TARGET_ROOT/skills/$current" ] && { printf '%s\n' "$current"; return 0; }
  done
  return 1
}
in_resolved() {
  local want=$1 existing
  for existing in ${RESOLVED[@]+"${RESOLVED[@]}"}; do [ "$existing" = "$want" ] && return 0; done
  return 1
}
for name in ${NAMES[@]+"${NAMES[@]}"}; do
  [[ "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "inspect-project.sh: invalid skill name '$name'"
  if [ -d "$TARGET_ROOT/skills/$name" ]; then
    in_resolved "$name" || { RESOLVED+=("$name"); INSTALLED_AS+=("$name"); }
  elif new_name=$(renamed_to "$name"); then
    printf 'RENAMED  %s -> %s\n' "$name" "$new_name"
    in_resolved "$new_name" || { RESOLVED+=("$new_name"); INSTALLED_AS+=("$name"); }
  else
    printf 'RETIRED  %s\n' "$name"
  fi
done

# --- Framework-owned copies edited in the project -------------------------------------------------
report_local_edits() {
  # $1 installed directory, $2 base directory (may be empty), $3 target directory
  local installed=$1 base=$2 target=$3 file rel listed=0 differs=0
  [ -d "$installed" ] || { note "missing $installed is managed but not installed; the update installs it"; return 0; }
  diff -qr -x .DS_Store "$target" "$installed" >/dev/null 2>&1 && return 0
  while IFS= read -r -d '' file; do
    rel=${file#"$installed/"}
    case "$rel" in .DS_Store|*/.DS_Store) continue ;; esac
    if is_conflict_copy "$rel"; then continue; fi
    if [ -f "$target/$rel" ] && cmp -s "$file" "$target/$rel"; then continue; fi
    if [ -n "$base" ]; then
      if [ -f "$base/$rel" ] && cmp -s "$file" "$base/$rel"; then continue; fi
      decision "local-edit $installed/$rel differs from the v$CURRENT release it was installed from; the change is lost on replacement. Move project rules to docs/ first, or confirm the loss"
    else
      differs=$((differs + 1))
      [ "$listed" -ge 5 ] || note "differs $installed/$rel is not what v$TARGET_VERSION ships"
      listed=$((listed + 1))
    fi
  done < <(find "$installed" -type f -print0 | sort -z)
  [ "$differs" -le 5 ] || note "differs $installed has $differs files that differ from v$TARGET_VERSION in total"
  return 0
}

i=0
for name in ${RESOLVED[@]+"${RESOLVED[@]}"}; do
  old=${INSTALLED_AS[$i]}
  i=$((i + 1))
  base=$(base_tree "skills/$old")
  [ -n "$base" ] || base=$(base_tree "skills/$name")
  for root in .agents/skills .claude/skills; do
    report_local_edits "$root/$old" "$base" "$TARGET_ROOT/skills/$name"
  done
  if [ -d ".agents/skills/$old" ] && [ -d ".claude/skills/$old" ] &&
     ! diff -qr -x .DS_Store ".agents/skills/$old" ".claude/skills/$old" >/dev/null 2>&1; then
    note "pair-drift the .agents and .claude copies of $old differ from each other; one of them was changed in the project"
  fi
done

# --- AGENTS.md against its starter ---------------------------------------------------------------
starter_version() { sed -n '1s/.* v\([0-9][0-9]*\.[0-9][0-9]*\)[[:space:]]*$/\1/p' "$1"; }
if [ -n "$STARTER" ] && [ -f AGENTS.md ]; then
  target_starter="$TARGET_ROOT/agents/$STARTER.md"
  if [ ! -f "$target_starter" ]; then
    decision "starter-missing agents/$STARTER.md is not shipped by v$TARGET_VERSION; choose a starter before AGENTS.md is replaced"
  elif ! cmp -s AGENTS.md "$target_starter"; then
    local_v=$(starter_version AGENTS.md)
    target_v=$(starter_version "$target_starter")
    if [ -n "$local_v" ] && [ -n "$target_v" ] && version_gt "$local_v" "$target_v"; then
      decision "starter-ahead AGENTS.md is starter v$local_v but v$TARGET_VERSION ships v$target_v; replacing it is a downgrade"
    else
      base_starter=$(base_tree "agents/$STARTER.md")
      if [ -n "$base_starter" ] && ! cmp -s AGENTS.md "$base_starter"; then
        decision "local-edit AGENTS.md differs from the v$CURRENT $STARTER starter it was installed from; project rules in it are lost on replacement. Move them to docs/ first, or confirm the loss"
      elif [ -z "$base_starter" ]; then
        note "differs AGENTS.md is not the v$TARGET_VERSION $STARTER starter; check it for project rules before it is replaced"
      fi
    fi
  fi
fi

# --- Clutter the update would otherwise carry along -----------------------------------------------
while IFS= read -r path; do
  [ -n "$path" ] || continue
  case "$path" in
    .agents/skills/*|.claude/skills/*|"$DOCS"/*|AGENTS*|CLAUDE*) ;;
    *) continue ;;
  esac
  is_conflict_copy "$path" || continue
  note "conflict-copy '$path' looks like a sync-conflict duplicate; delete it before updating, it is not project content"
done < <(git ls-files --others --cached --exclude-standard 2>/dev/null)

if [ -d "$DOCS" ]; then
  for file in "$DOCS"/*.md; do
    [ -f "$file" ] || continue
    base_name=$(basename "$file")
    case "$base_name" in [0-9][0-9]-*.md) continue ;; esac
    if is_conflict_copy "$base_name"; then continue; fi
    if [ -f "$TARGET_ROOT/templates/$base_name" ] ||
       tail -n 5 "$file" | grep -qE '^\*Clarity Framework( v[0-9.]+)? [–-] '; then
      note "template-copy $file looks like a copy of a framework template, which the update cannot keep current. If it is the plan template, plan-driven-build ships its own; remove the copy"
    fi
  done

  # A standard document under another name (for example a translated file name) is still the
  # project's copy of that template; without the mapping the update skips it.
  for template in "$TARGET_ROOT"/templates/[0-9][0-9]-*.md; do
    [ -f "$template" ] || continue
    t_name=$(basename "$template")
    [ -f "$DOCS/$t_name" ] && continue
    number=${t_name%%-*}
    for candidate in "$DOCS/$number"-*.md; do
      [ -f "$candidate" ] || continue
      c_name=$(basename "$candidate")
      [ -f "$TARGET_ROOT/templates/$c_name" ] && continue
      if is_conflict_copy "$c_name"; then continue; fi
      note "doc-name $candidate has no template of that name; by number it may be the project's $t_name. Record the mapping in the AI Context table 'Where is more context?' and lift it against that template"
    done
  done
fi

if [ -r "$CTX" ] && grep -qE -- '--local-fallback' "$CTX"; then
  note "pool-syntax $CTX uses '--local-fallback'; write the fallback as a 'cli:NAME' pool entry instead (for example 'codework1,cli:codex')"
fi

for dir in "$TARGET_ROOT"/skills/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  in_resolved "$name" || note "new-skill $name is shipped by v$TARGET_VERSION and not managed here; see 'Add a skill to a managed project'"
done

resolved_csv=$(IFS=,; printf '%s' "${RESOLVED[*]-}")
printf 'INSPECT managed=%s decisions=%s notes=%s\n' "${resolved_csv:-none}" "$decisions" "$notes"
[ "$decisions" -eq 0 ] || exit 3
