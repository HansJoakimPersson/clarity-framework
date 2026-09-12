#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
CHECKER="$SCRIPT_DIR/check-version-consistency.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM

make_repo() {
  local name=$1
  local repo="$TEST_ROOT/$name"
  mkdir -p "$repo/templates" "$repo/framework"
  git -C "$repo" init -q
  git -C "$repo" config user.name 'Clarity test'
  git -C "$repo" config user.email 'clarity-test@example.invalid'
  printf '# Project\n\n*Clarity Framework v1.2.3*\n' > "$repo/README.md"
  printf '# Template\n\nBody.\n\n*Clarity Framework v1.2.3*\n' > "$repo/templates/01-a.md"
  printf '# Template\n\nBody.\n\n*Clarity Framework v1.2.3*\n' > "$repo/templates/02-b.md"
  printf '# CHANGELOG\n\n## [1.2.3] - 2026-01-01\n\n- Initial\n' > "$repo/framework/CHANGELOG.md"
  git -C "$repo" add .
  git -C "$repo" commit -qm initial
  printf '%s\n' "$repo"
}

run_checker() {
  local repo=$1
  (cd "$repo" && "$CHECKER")
}

good_repo=$(make_repo consistent)
run_checker "$good_repo" > "$TEST_ROOT/good.out"
grep -qF 'PASS  version marker: Clarity Framework v1.2.3' "$TEST_ROOT/good.out"
grep -qF 'PASS  template footers: all present' "$TEST_ROOT/good.out"
grep -qF 'PASS  changelog: no Unreleased heading' "$TEST_ROOT/good.out"

drift_repo=$(make_repo version-drift)
printf '# Project\n\n*Clarity Framework v1.2.4*\n' > "$drift_repo/README.md"
if run_checker "$drift_repo" > "$TEST_ROOT/drift.out" 2>&1; then
  printf '%s\n' 'expected version-drift failure' >&2
  exit 1
fi
grep -qF 'FAIL  version marker' "$TEST_ROOT/drift.out"

missing_footer_repo=$(make_repo missing-footer)
printf '# Template\n\nNo footer.\n' > "$missing_footer_repo/templates/02-b.md"
if run_checker "$missing_footer_repo" > "$TEST_ROOT/footer.out" 2>&1; then
  printf '%s\n' 'expected missing-footer failure' >&2
  exit 1
fi
grep -qF 'FAIL  template footers' "$TEST_ROOT/footer.out"
grep -qF 'templates/02-b.md' "$TEST_ROOT/footer.out"

unreleased_repo=$(make_repo unreleased)
printf '# CHANGELOG\n\n## [Unreleased]\n\n- WIP\n\n## [1.2.3] - 2026-01-01\n\n- Initial\n' \
  > "$unreleased_repo/framework/CHANGELOG.md"
if run_checker "$unreleased_repo" > "$TEST_ROOT/unreleased.out" 2>&1; then
  printf '%s\n' 'expected unreleased-heading failure' >&2
  exit 1
fi
grep -qF 'FAIL  changelog' "$TEST_ROOT/unreleased.out"

printf '%s\n' 'check-version-consistency-test: ok'
