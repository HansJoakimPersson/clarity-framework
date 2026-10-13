#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
CHECKER="$SCRIPT_DIR/check-skill-snippets.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM

# make_repo NAME: a repository whose SKILL.md body is read from stdin.
make_repo() {
  local name=$1
  local repo="$TEST_ROOT/$name"
  mkdir -p "$repo/skills/demo"
  git -C "$repo" init -q
  cat > "$repo/skills/demo/SKILL.md"
  git -C "$repo" add .
  git -C "$repo" -c user.name='Clarity test' -c user.email='clarity-test@example.invalid' commit -qm initial
  printf '%s\n' "$repo"
}

expect_fail() {
  local repo=$1 rule=$2
  if (cd "$repo" && bash "$CHECKER" > "$TEST_ROOT/out" 2>&1); then
    printf 'check-skill-snippets-test: %s should fail\n' "$rule" >&2
    exit 1
  fi
  grep -F "skills/demo/SKILL.md:4: $rule:" "$TEST_ROOT/out" >/dev/null || {
    printf 'check-skill-snippets-test: missing %s finding on line 4\n' "$rule" >&2
    cat "$TEST_ROOT/out" >&2
    exit 1
  }
}

# The safe spellings of all three constructs pass, and so does prose outside a shell fence.
ok=$(make_repo ok <<'MD'
# Demo

Prose may say $NEW:skills and $model_args freely.

```bash
git ls-tree "${NEW}:skills"
PATH="$JAVA_HOME/bin:$PATH"
set -- --model "$MODEL"
dispatch.sh "$@" --out "$RUN/x"
echo ----
[ "$a" = "$b" ]
x=$(printf '%s' "$model_args")
```

```text
$NEW:skills $model_args ====
```
MD
)
(cd "$ok" && bash "$CHECKER" > "$TEST_ROOT/ok.out")
grep -F 'PASS  skill-snippets' "$TEST_ROOT/ok.out" >/dev/null

colon=$(make_repo colon <<'MD'
# Demo

```bash
git ls-tree "$NEW:skills"
```
MD
)
expect_fail "$colon" colon-modifier

list=$(make_repo list <<'MD'
# Demo

```sh
dispatch.sh $model_args --out x
```
MD
)
expect_fail "$list" unquoted-list

equals=$(make_repo equals <<'MD'
# Demo

```bash
echo =====
```
MD
)
expect_fail "$equals" equals-word

# The documented exemption is honored.
exempt=$(make_repo exempt <<'MD'
# Demo

```bash
git ls-tree "$NEW:skills"  # zsh-ok
```
MD
)
(cd "$exempt" && bash "$CHECKER" > /dev/null)

printf 'check-skill-snippets-test: ok\n'
