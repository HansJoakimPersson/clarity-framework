#!/usr/bin/env bash

# Automates AGENTS.md's release-verification steps: a single version marker across tracked
# Markdown, no template missing its version footer, and no undated ("Unreleased") CHANGELOG
# heading left before a release. Run before tagging a release.

set -euo pipefail

die() { printf '%s\n' "$1" >&2; exit 2; }

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die 'check-version-consistency.sh: run from a Git repository'
cd -- "$REPO_ROOT"

FAIL=0

# 1. Exactly one distinct version marker across tracked Markdown, excluding the changelog itself
#    (which legitimately lists every past version).
markers=$(git grep -hoE 'Clarity Framework v[0-9]+\.[0-9]+\.[0-9]+' -- '*.md' ':!framework/CHANGELOG.md' | sort -u)
marker_count=$(printf '%s\n' "$markers" | sed '/^$/d' | wc -l | tr -d ' ')
if [ "$marker_count" -eq 1 ]; then
  printf 'PASS  version marker: %s\n' "$markers"
else
  printf 'FAIL  version marker: expected exactly one, found %s\n' "$marker_count" >&2
  [ -n "$markers" ] && printf '%s\n' "$markers" | sed 's/^/        /' >&2
  FAIL=1
fi

# 2. Every template carries its own version footer (framework-update reads it as a fallback).
missing_footers=''
for f in templates/*.md; do
  grep -q '^\*Clarity Framework v' "$f" || missing_footers="$missing_footers$f"$'\n'
done
if [ -z "$missing_footers" ]; then
  printf 'PASS  template footers: all present\n'
else
  printf 'FAIL  template footers: missing from:\n' >&2
  printf '%s' "$missing_footers" | sed 's/^/        /' >&2
  FAIL=1
fi

# 3. No undated "Unreleased" heading left in the changelog before a release is tagged.
unreleased_count=$(grep -c 'Unreleased' framework/CHANGELOG.md || true)
if [ "$unreleased_count" -eq 0 ]; then
  printf 'PASS  changelog: no Unreleased heading\n'
else
  printf 'FAIL  changelog: %s Unreleased heading(s) still present\n' "$unreleased_count" >&2
  FAIL=1
fi

exit "$FAIL"
