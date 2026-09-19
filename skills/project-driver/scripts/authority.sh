#!/usr/bin/env bash

# Resolve one proposed action against Clarity's consequence-based authority model.
# Exit codes: 0 Delegated, 10 Orchestrator-only escalation, 20 Human gate (Reserved), 2 usage/config.

set -euo pipefail

die() { printf '%s\n' "$1" >&2; exit 2; }

ACTION=''
IMPACT='unknown'
POLICY='docs/00-ai-context.md'

while [ "$#" -gt 0 ]; do
  case "$1" in
    --action) ACTION="${2:-}"; shift 2 ;;
    --impact) IMPACT="${2:-}"; shift 2 ;;
    --policy) POLICY="${2:-}"; shift 2 ;;
    *) die "authority.sh: unknown argument '$1'" ;;
  esac
done

[ -n "$ACTION" ] || die 'authority.sh: --action is required'
[[ "$ACTION" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die "authority.sh: invalid action '$ACTION'"

case "$IMPACT" in
  unknown|reversible-local|external-reversible|architecture|security|cost|behavior|production|irreversible|credential|permission|economic) ;;
  *) die "authority.sh: invalid --impact '$IMPACT'" ;;
esac

matches() {
  local action=$1 pattern=$2 prefix
  case "$pattern" in
    *'.*')
      prefix=${pattern%\*}
      [[ "$action" == "$prefix"* ]]
      ;;
    *)
      [ "$action" = "$pattern" ]
      ;;
  esac
}

emit() {
  local class=$1 decision=$2 source=$3 code=$4
  printf 'AUTHORITY\tclass=%s\tdecision=%s\taction=%s\tsource=%s\n' \
    "$class" "$decision" "$ACTION" "$source"
  exit "$code"
}

declare -a POLICY_DELEGATE=()
declare -a POLICY_ESCALATE=()
declare -a POLICY_RESERVE=()
UNKNOWN_REVERSIBLE='delegated'
UNKNOWN_EXTERNAL='escalation'

if [ -r "$POLICY" ]; then
  while IFS='=' read -r key value; do
    [ -n "$key" ] || continue
    value=${value%%#*}
    value=${value#"${value%%[![:space:]]*}"}
    value=${value%"${value##*[![:space:]]}"}
    case "$key" in
      delegate) [ -n "$value" ] && POLICY_DELEGATE+=("$value") ;;
      escalate) [ -n "$value" ] && POLICY_ESCALATE+=("$value") ;;
      reserve) [ -n "$value" ] && POLICY_RESERVE+=("$value") ;;
      unknown_reversible) UNKNOWN_REVERSIBLE="$value" ;;
      unknown_external) UNKNOWN_EXTERNAL="$value" ;;
    esac
  done < <(
    awk '
      /^<!-- clarity-authority:start -->$/ { in_block=1; next }
      in_block && /^<!-- clarity-authority:end -->$/ { exit }
      in_block { print }
    ' "$POLICY"
  )
fi

for pattern in "${POLICY_RESERVE[@]}"; do
  matches "$ACTION" "$pattern" && emit reserved HUMAN_GATE policy 20
done
for pattern in "${POLICY_ESCALATE[@]}"; do
  matches "$ACTION" "$pattern" && emit escalation ORCHESTRATOR policy 10
done
for pattern in "${POLICY_DELEGATE[@]}"; do
  matches "$ACTION" "$pattern" && emit delegated DELEGATED policy 0
done

DEFAULT_RESERVED=(
  production.deploy
  production.release
  production-data.delete
  migration.destructive
  credential.'.*'
  permission.'.*'
  economic.commitment
  git.push.protected-main
  git.merge.protected-main
  mission.material-intent-change
)
DEFAULT_ESCALATION=(
  architecture.material-change
  product-scope.material-change
  dependency.new-external-service
  dependency.new-paid-service
  public-api.breaking-change
  security-boundary.change
  externally-visible-behavior.change
)
DEFAULT_DELEGATED=(
  code.'.*'
  tests.'.*'
  docs.'.*'
  git.commit
  git.worktree.'.*'
  git.branch.local
  git.merge.internal
  git.push.task-branch
  dependency.update-existing
  dependency.add-free-local
  migration.create-reversible
  network.dependency-resolution
  plan.'.*'
  debug.'.*'
  ci.fix
)

for pattern in "${DEFAULT_RESERVED[@]}"; do
  matches "$ACTION" "$pattern" && emit reserved HUMAN_GATE default 20
done
for pattern in "${DEFAULT_ESCALATION[@]}"; do
  matches "$ACTION" "$pattern" && emit escalation ORCHESTRATOR default 10
done
for pattern in "${DEFAULT_DELEGATED[@]}"; do
  matches "$ACTION" "$pattern" && emit delegated DELEGATED default 0
done

case "$IMPACT" in
  reversible-local)
    [ "$UNKNOWN_REVERSIBLE" = delegated ] && emit delegated DELEGATED fallback 0
    [ "$UNKNOWN_REVERSIBLE" = escalation ] && emit escalation ORCHESTRATOR fallback 10
    emit reserved HUMAN_GATE fallback 20
    ;;
  external-reversible|architecture|security|cost|behavior|unknown)
    [ "$UNKNOWN_EXTERNAL" = delegated ] && emit delegated DELEGATED fallback 0
    [ "$UNKNOWN_EXTERNAL" = reserved ] && emit reserved HUMAN_GATE fallback 20
    emit escalation ORCHESTRATOR fallback 10
    ;;
  production|irreversible|credential|permission|economic)
    emit reserved HUMAN_GATE impact 20
    ;;
esac
