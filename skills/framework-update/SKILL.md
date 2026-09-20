---
name: framework-update
description: Use when a project is on an older Clarity Framework version, a new release is out, or the user asks to update or sync the framework — upgrades documents and tooling without losing anything already written.
---

# Framework Update (framework-update)

Bring this project to the shape the current stable Clarity release prescribes without losing
project-owned content.

The installed copy of this skill is only the bootstrap entry point. Once the latest stable target tag
is resolved, that tag's `skills/framework-update/SKILL.md` and scripts govern the rest of the run.

Do not dispatch other agents. Perform the update in this session.

## Ownership and authority

Read the target release's `README.md` **Ownership** section first; it is normative.

- **Framework-owned:** `AGENTS.md`, `CLAUDE.md`, and each Clarity-managed skill name listed in the
  project's `docs/00-ai-context.md`. Replace these from the target release.
- **Project-owned:** `docs/`. Preserve its authored content while lifting active standard documents
  to the target template structure.
- **Everything else:** untouched.

Never delete project-owned content, never touch source code, and never wildcard across all skills.

Routine upgrades are **Delegated** when every write is deterministic, reversible, and
content-preserving. Stop only for an **Escalation** or **Reserved** condition such as ambiguous skill
ownership, ambiguous document mapping, project-authored content inside a retired managed-skill
directory, or a project rule that reserves framework commits.

`CLAUDE.md` must end as exactly `@AGENTS.md`. If it currently contains project-specific rules,
move each rule first to its unambiguous home under `docs/`. If destination or meaning is ambiguous,
leave `CLAUDE.md` untouched and escalate before deleting anything.

Skill ownership is name-scoped. If the Clarity-managed setup block or its `skills:` line is absent,
ownership is ambiguous: present the discovered Clarity-looking names as one Escalation decision and
record the resolved list before replacing any skill.

## Preconditions

- Run from the project root of a Git repository.
- `git` is available and github.com is reachable.
- Unrelated source/build/test/application changes may remain dirty and staged.
- A dirty update-surface path is a blocker: `AGENTS.md`, `CLAUDE.md`, `.gitignore`,
  `docs/NN-*.md`, or either runtime copy of a skill shipped by the target release or already listed
  as managed by the project.
- An untracked `framework-update` directory copied only to bootstrap this run is allowed.

## Step 1 — Resolve and pin the target release

```bash
TMP=$(mktemp -d)
git clone --quiet --filter=blob:none https://github.com/HansJoakimPersson/clarity-framework "$TMP/cf"
NEW=$(git -C "$TMP/cf" tag -l --sort=-v:refname 'v*' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
[ -n "$NEW" ] || { printf '%s\n' 'No stable Clarity Framework release tag found' >&2; exit 2; }
NEW_VERSION=${NEW#v}

git -C "$TMP/cf" checkout --quiet --detach "$NEW"
TARGET_UPDATE_SKILLDIR="$TMP/cf/skills/framework-update"
[ -r "$TARGET_UPDATE_SKILLDIR/SKILL.md" ] || {
  printf '%s\n' "Release $NEW is missing framework-update" >&2
  exit 2
}

FRAMEWORK_SKILLS=$(git -C "$TMP/cf" ls-tree -d --name-only "$NEW:skills" | tr '\n' ',' | sed 's/,$//')
PROJECT_MANAGED_SKILLS=''
if [ -r docs/00-ai-context.md ]; then
  PROJECT_MANAGED_SKILLS=$(sed -n 's/^skills:[[:space:]]*//p' docs/00-ai-context.md \
    | head -1 | tr -d '[:space:]')
fi

bash "$TARGET_UPDATE_SKILLDIR/scripts/check-update-scope.sh" \
  --framework-skills "$FRAMEWORK_SKILLS" \
  --managed-skills "$PROJECT_MANAGED_SKILLS"
```

The detached checkout is the **only** release source for this run. Never copy from `main` or another
branch. Read `$TMP/cf/README.md` and then the target release's copy of this skill. If it differs
from the installed copy, continue using the target procedure; do not combine old procedure text with
new release files.

Clean up `$TMP` when the run completes or aborts.

## Step 2 — Establish current project state

Determine the current framework version in this order:

1. `Framework version` in `docs/00-ai-context.md`;
2. a `*Clarity Framework vX.Y.Z*` footer in an active standard project document;
3. no marker — treat every active standard document as needing a structural check.

Normalize a leading `v` before comparison.

Read the project's Clarity-managed setup block when present:

```text
agents-starter: <name or none>
skills: <comma-separated managed names>
skill-paths: .agents/skills, .claude/skills
```

If the project already reports `$NEW_VERSION`, still verify that the selected starter and every
managed skill exist, match the target release, exist identically in both runtime roots, and are not
ignored by Git. A matching version marker alone is not proof of a complete update.

## Step 3 — Build the update set

### Framework-owned

- Replace `AGENTS.md` with the matching starter from `$TMP/cf/agents/`.
- For each managed skill still shipped by the target release, replace both exact runtime directories
  from `$TMP/cf/skills/<name>/`; remove stale files inside those two directories first.
- Verify each runtime pair with `diff -qr`.
- `project-driver` has a hard runtime dependency on `plan-driven-build`. If `project-driver` is
  managed but `plan-driven-build` is not, stop as an ownership/runtime Escalation rather than
  installing an undeclared dependency or leaving a runner that cannot dispatch.
- A managed `project-driver` replacement includes its complete nested runtime payload — scripts,
  prompts, and tests. Never copy only `SKILL.md`; the Mission Runner, completion-audit prompt,
  authority resolver, and mission controller are part of the managed skill.
- Ensure `CLAUDE.md` contains exactly `@AGENTS.md`, migrating existing project rules first.
- Narrow `.gitignore` only when required to keep managed runtime copies versioned; preserve ignores
  for local settings, caches, credentials, and machine-only state.

A framework-owned difference from the target release is expected. Do not merge or preserve edits
inside framework-owned copies.

### Retired managed skills

If a project-managed skill name is absent from the target release, it is retired. Removing its two
exact runtime directories and the name from the managed setup block is Delegated **only** when both
directories contain framework-owned copies with no project-authored additions. Otherwise escalate
before removal.

### Project-owned active documents

For each existing `docs/NN-*.md` with a corresponding target template:

1. Use the target template as the structural destination.
2. Move filled-in project passages to the matching section **unchanged**.
3. Keep new template sections with their placeholder text when the project has no content yet.
4. Re-attempt placement of any existing
   `## Parked content (no matching section in current template)` entries.
5. Put content that still has no matching home under that exact parked-content heading.
6. Preserve project metadata such as owner/status/date except the framework version fields stamped
   later.

If a target structure splits one existing passage in a way that has materially different reasonable
mappings, stop on that document as Escalation. Straightforward heading/semantic mappings are
Delegated.

A framework update is a **structural migration, not a retention sweep**. New lifecycle rules such as
archiving completed stories, superseded ADRs, resolved debt, or old incidents apply to subsequent
project work. Do not retroactively move historical content to `docs/archive/` during the upgrade
unless the user separately requested that cleanup.

### New optional artifacts and orphans

- New framework skills not already managed: report them as available with a one-line use/trigger
  description. Do not install them automatically.
- New templates not already used: report them as available. Add one autonomously only when existing
  documented project intent makes it clearly required without inventing product content.
- Files no longer shipped by the framework but not covered by retired managed-skill handling:
  report them with a recommendation. Check target/history before calling a rename an orphan.

These are non-blocking unless ownership is ambiguous.

## Step 4 — Classify and continue

Record a compact update summary: detected version → target tag, exact framework-owned replacements
and removals, active document structural merges, unrelated dirty paths accepted by the checker, and
non-blocking optional/orphan findings.

Continue directly when all operations are Delegated. Do not create a universal "approve update"
checkpoint.

For one real Escalation/Reserved condition, present only that decision and stop. Resume the same run
after it is resolved.

## Step 5 — Apply

Apply only the update set from Step 3 using files from the detached target checkout.

Never use broad deletion or copy commands over `.agents/`, `.claude/`, `skills/`, or `docs/`.
A managed skill replacement may delete only:

```text
.agents/skills/<managed-name>/
.claude/skills/<managed-name>/
```

Keep a logical `UPDATE_PATHS` set containing every path changed by this run. Pre-existing staged
source changes may remain staged; do not reset, unstage, or include them.

## Step 6 — Stamp, verify, and commit

Stamp the target version in **active standard project documents only** (`docs/NN-*.md`):

- update the `Framework version` field in `docs/00-ai-context.md`;
- update existing `*Clarity Framework vX.Y.Z*` footers;
- refresh the Clarity-managed setup block when the starter or managed skill list changed.

Do **not** rewrite `docs/archive/`; archived records describe historical states.

Add every stamped active document to `UPDATE_PATHS`, even when version stamping is its only change.
A stale active marker makes the next update report the wrong starting point.

Before committing, verify:

- `CLAUDE.md` is exactly `@AGENTS.md`;
- every managed skill pair passes `diff -qr`;
- neither managed runtime copy is ignored by Git;
- all active standard framework markers equal `$NEW_VERSION`;
- no source/build/test/application path was modified by this run;
- unrelated pre-existing staged paths remain staged but outside `UPDATE_PATHS`.

Then re-read the final managed-skill list from the updated AI Context and run the target release's
runtime verifier against the **installed** copies:

```bash
FINAL_MANAGED_SKILLS=''
if [ -r docs/00-ai-context.md ]; then
  FINAL_MANAGED_SKILLS=$(sed -n 's/^skills:[[:space:]]*//p' docs/00-ai-context.md     | head -1 | tr -d '[:space:]')
fi

bash "$TARGET_UPDATE_SKILLDIR/scripts/verify-managed-runtime.sh"   --target-root "$TMP/cf"   --managed-skills "$FINAL_MANAGED_SKILLS"   --smoke yes
```

This verification is release-critical, not optional. For a managed `project-driver` it proves that
both runtime roots contain the target release's exact Mission Runner, mandatory handoff rules,
completion-audit prompt, mission controller, authority resolver, and the supervised
`plan-driven-build` dependency. It also runs the installed runtime's regression tests, including
multi-cycle continuation, rejection of premature mission completion, mission-bound runner/gate
ownership, and dispatch watchdog recovery. A successful version stamp without this runtime
verification is an incomplete framework update.

Generate the exact commit script **after stamping** with the target release renderer:

```bash
bash "$TARGET_UPDATE_SKILLDIR/scripts/render-update-commit.sh" --version "$NEW_VERSION" \
  --path AGENTS.md \
  --path <each-other-update-path> > "$TMP/commit-update.sh"
bash -n "$TMP/commit-update.sh"
```

The renderer also auto-includes tracked active `docs/NN-*.md` carrying a Clarity marker. That is a
backward-compatibility safeguard for older updater procedures that rendered before stamping.

Inspect the generated `UPDATE_PATHS`. If commits are Delegated, execute:

```bash
bash "$TMP/commit-update.sh"
```

If commits are Reserved, do not execute it; preserve the generated block for handoff.

After a Delegated commit, verify the commit contains only update paths and unrelated previously staged
paths remain staged and uncommitted.

## Step 7 — Hand back

Report, in this order:

1. Anything that still needs human action: Escalation/Reserved items, new empty sections, parked
   content, and optional new skills/templates worth considering.
2. Framework-owned replacements/removals and confirmation that both runtime copies match and are not
   ignored.
3. Active project documents structurally merged/stamped, plus orphans/recommendations.
4. The update commit SHA when Delegated; otherwise the renderer's exact commit block.

Do not ask for routine confirmation after a successful Delegated update.

## Notes

- Upgrade directly to the newest stable tag; do not replay intermediate releases.
- A project edit inside a framework-owned file is not preserved by default. Project rules belong in
  `docs/`; if you discover such content before replacement, move it only when its destination is
  unambiguous, otherwise escalate.
- A new optional skill is not a migration requirement merely because the target release ships it.
- The target tag, not the installed updater version and not repository `main`, defines the run.
