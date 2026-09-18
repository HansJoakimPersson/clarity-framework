#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
PACKER="$SCRIPT_DIR/context-pack.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

cd "$TEST_ROOT"
git init -q
git config user.name 'Clarity test'
git config user.email 'clarity-test@example.invalid'
mkdir -p docs/archive docs/plans

cat > docs/00-ai-context.md <<'EOF'
# AI Context

## Current status
Compact project state.
EOF

cat > docs/02-requirements.md <<'EOF'
# Requirements

## NFRs
Stable NFR content.

##### FR-017 · Export report

**Acceptance criteria:**
AC-017-1: export succeeds.

##### FR-018 · Another story

Do not include this.
EOF

cat > docs/large.md <<'EOF'
# Large
EOF
awk 'BEGIN { for (i=0; i<30000; i++) printf "x" }' >> docs/large.md

cat > docs/archive/old.md <<'EOF'
# Old
Cold history.
EOF

cat > docs/plans/test.md <<'EOF'
# Plan

## Context to read first

| Reference | Why |
| --- | --- |
| `AGENTS.md` | Runtime instructions |
| `docs/00-ai-context.md` | Orientation |
| `docs/02-requirements.md#FR-017` | Story contract |

## Steps
EOF

git add .
git commit -qm initial

sh "$PACKER" --plan docs/plans/test.md --out docs/plans/context.md > pack.out
grep -F 'Compact project state.' docs/plans/context.md >/dev/null
grep -F 'FR-017 · Export report' docs/plans/context.md >/dev/null
grep -F 'AC-017-1: export succeeds.' docs/plans/context.md >/dev/null
if grep -F 'FR-018 · Another story' docs/plans/context.md >/dev/null; then
  printf 'context-pack-test: selected section leaked into next story\n' >&2
  exit 1
fi
if grep -F 'AGENTS.md' docs/plans/context.md >/dev/null; then
  printf 'context-pack-test: runtime instructions were duplicated into the pack\n' >&2
  exit 1
fi
grep -F 'CONTEXT_PACK refs=2' pack.out >/dev/null

cat > docs/plans/large.md <<'EOF'
# Plan
## Context to read first
| Reference | Why |
| --- | --- |
| `docs/large.md` | Too large whole-file read |
## Steps
EOF
if sh "$PACKER" --plan docs/plans/large.md --out docs/plans/large-context.md 2> large.err; then
  printf 'context-pack-test: oversized whole-file reference should fail\n' >&2
  exit 1
fi
grep -F 'whole-file reference exceeds' large.err >/dev/null

cat > docs/plans/archive.md <<'EOF'
# Plan
## Context to read first
| Reference | Why |
| --- | --- |
| `docs/archive/old.md` | Cold history |
## Steps
EOF
if sh "$PACKER" --plan docs/plans/archive.md --out docs/plans/archive-context.md 2> archive.err; then
  printf 'context-pack-test: archive reference should fail\n' >&2
  exit 1
fi
grep -F 'cold context' archive.err >/dev/null

if sh "$PACKER" --plan docs/plans/test.md --out docs/plans/tiny.md --max-bytes 100 2> tiny.err; then
  printf 'context-pack-test: pack byte ceiling should fail\n' >&2
  exit 1
fi
grep -F 'context pack exceeds' tiny.err >/dev/null

printf 'context-pack-test: ok\n'
