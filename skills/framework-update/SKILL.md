---
name: framework-update
description: Upgrade a project's Clarity Framework documents and tooling to the latest release, preserving everything already written. Use when the project is on an older framework version, when a new release is out, or when the user asks to update or sync the framework.
---

# Framework Update (framework-update)

Bring this project to the shape the **current** Clarity Framework release prescribes, without losing
a word of what is already written.

The target state is concrete: the project should end up looking the way it would have looked if the
framework had been applied at today's version from the start — same files, in the same places, with
the same structure — except that every filled-in passage is the one that was already there. When a
Clarity skill is installed, identical copies exist under `.agents/skills/` for Codex and
`.claude/skills/` for Claude Code.

This skill has nothing to do with the plan-driven build workflow. Do not dispatch anything and do
not involve other agents or accounts. You do this yourself, in this session.

## The ownership rule

Every path has exactly one owner, and that decides what happens to it:

- **Framework-owned** files are replaced wholesale. They are never edited in a project, so there is
  nothing in them worth preserving. Do not diff them, do not merge them — replace the approved
  managed path so files removed upstream are removed locally too.
- **Project-owned** files hold the user's work. Their *content* is preserved and their *structure*
  is lifted to the new template.
- Everything else is untouched.

Do not carry a copy of the mapping in this file. Read it from the release you fetched, in
`README.md` under **Project structure** and **Ownership** — that section is normative and is what
this skill follows. If it disagrees with anything below, it wins.

Three rules hold throughout: **never delete project-owned content**, **never touch source code**,
and **never discard anything a project wrote in `CLAUDE.md`**. `CLAUDE.md` is framework-owned and
must end up containing exactly `@AGENTS.md`, but any project-specific lines it currently holds are
project-owned content: propose moving them into the `docs/` document that governs them, and reduce
the file to the import only after the user approves that migration.

Skill ownership is name-scoped, not wildcard-scoped. Only Clarity skill names listed in the
project's `00-ai-context.md` are managed by Clarity. Skills with any other name are project- or
third-party-owned and must remain untouched. If no list exists, propose managed skills explicitly
and ask the user to confirm them before replacing anything.

## Preconditions

- `git` is available and github.com is reachable.
- Run from the project root of a Git repository. Existing source, dependency, test and application
  configuration changes may remain dirty; this skill must neither stage nor modify them.
- A dirty path is a blocker only when it is in the **update surface**: `AGENTS.md`, `CLAUDE.md`,
  `.gitignore`, `docs/NN-*.md`, or a runtime copy of a skill shipped by
  the fetched release. A newly copied, untracked `framework-update` directory under either
  runtime root is a bootstrap artifact and is allowed.

## Step 1 — Fetch the framework and read the rules

```bash
TMP=$(mktemp -d)
git clone --quiet --filter=blob:none https://github.com/HansJoakimPersson/clarity-framework "$TMP/cf"
NEW=$(git -C "$TMP/cf" tag -l --sort=-v:refname 'v*' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
[ -n "$NEW" ] || { printf '%s\n' 'No stable Clarity Framework release tag found' >&2; exit 2; }
NEW_VERSION=${NEW#v}
git -C "$TMP/cf" show "$NEW:README.md"          # placement and ownership
git -C "$TMP/cf" show "$NEW:templates/03-sad.md" # read any file at any version like this

if [ -f .agents/skills/framework-update/scripts/check-update-scope.sh ]; then
  UPDATE_SKILLDIR=.agents/skills/framework-update
elif [ -f .claude/skills/framework-update/scripts/check-update-scope.sh ]; then
  UPDATE_SKILLDIR=.claude/skills/framework-update
else
  printf '%s\n' 'Installed framework-update is missing check-update-scope.sh; install this release first' >&2
  exit 2
fi
FRAMEWORK_SKILLS=$(git -C "$TMP/cf" ls-tree -d --name-only "$NEW:skills" | tr '\n' ',' | sed 's/,$//')
bash "$UPDATE_SKILLDIR/scripts/check-update-scope.sh" --framework-skills "$FRAMEWORK_SKILLS"
```

Read `README.md` at `$NEW` first. Clean up `$TMP` when you are done, whatever the outcome.
The checker prints the pre-existing source paths it will leave untouched. If it reports a conflict,
stop before inspecting or modifying the affected update-surface file. Do not ask the user to clean
unrelated `src/`, build, dependency, test or application-configuration changes.

## Step 2 — Establish the project's current version

Look in this order and use the first that answers:

1. The **Framework version** field in `docs/00-ai-context.md`.
2. A `*Clarity Framework vX.Y.Z*` footer in any project document.
3. Nothing found — say so, and treat every document as needing a structure check against `$NEW`.
   You do not need the old version to do the work; it only tells you how much to expect.

Normalize a leading `v` before comparing. If the project version equals `$NEW_VERSION`, also verify
that every managed skill exists and is identical in both runtime locations before saying it is up
to date. In a Git project, also verify neither copy is ignored. A matching version with a missing,
divergent, or ignored runtime copy still needs repair.

## Step 3 — Decide what happens to each file

**Framework-owned — replace or add, no comparison needed:**

| File | How to place it |
| --- | --- |
| `AGENTS.md` | Copy the matching starter from `$NEW:agents/`. Identify the stack from the project file's own title line or from `00-ai-context.md` — every starter begins `# AGENTS.md - <Stack> vX.Y`. If the project has none, ask which stack rather than guessing |
| `.agents/skills/<managed-name>/` | Replace the whole directory from `$NEW:skills/<managed-name>/`, including removal of files no longer shipped |
| `.claude/skills/<managed-name>/` | Create an identical copy of the same release directory for Claude Code |

If a framework-owned file in the project differs from the new release, that is expected — it is an
older version. Replace it. Do not report the difference as a conflict and do not try to preserve
anything from it. Deleting stale files is allowed only inside one of the approved managed skill
directories, immediately before replacing that directory. Never use a wildcard over all skills.

**Cross-client instructions:** `CLAUDE.md` must contain exactly `@AGENTS.md`. If it is missing,
propose creating that one-line file. If it holds anything else, do not silently replace it: read
what is there, propose a destination in `docs/` for each project-specific rule, and present that
migration as part of the scope. Reducing the file to the import is approved together with the
migration, never before it.

**Project-owned — merge, one document at a time:**

`docs/NN-*.md` hold the user's writing. For each, compare the project's document against the new
template and work out what structurally differs — added sections, renamed headings, reordered
parts. You do not need the project's old template version for this: a template section is
recognisable by its placeholder text and its heading, and the user's prose is recognisable by being
prose. Trust that judgment; it is more reliable than inferring a baseline.

**New framework skills** that exist at `$NEW:skills/` but are not listed in the project's marker:
offer them individually. Do not install them automatically and do not adopt a same-named third-party
skill as framework-owned.

**New templates** the project should have but does not: report them. Copying an unfilled template
into `docs/` is a decision about scope, so let the user choose per file rather than adding all of
them.

**Orphans** — a file in the project that the framework no longer ships: report it with a
recommendation. Check `git -C "$TMP/cf" log --follow --name-status` before calling something an
orphan; it may have been renamed.

## Step 4 — Report, then stop

Present, in this order:

- Detected version → `$NEW`, and how the version was determined.
- Framework-owned files to be replaced or added — a count and the exact managed paths, no diffs.
- Any stale files that will be removed inside those managed paths, plus the proposed `CLAUDE.md`
  change: the import when the file is missing, or the migration of its project-specific rules into
  named `docs/` documents followed by reduction to the import.
- Project-owned documents needing a merge, each with one line on what structurally changed.
- New framework skills available, new templates available, and orphans.
- Existing unrelated dirty paths that were accepted by the scope checker, explicitly saying they
  will remain unstaged and untouched.

**Stop and wait for approval.** Nothing is written before this point. The user is approving a scope,
not a diff — keep it short enough to actually read.

## Step 5 — Apply

**Framework-owned:** replace verbatim. For each approved managed skill name, remove only the two
exact target directories, recreate them from `$NEW:skills/<name>/`, then verify the copies with
`diff -qr`. No edits, adaptation, merging, unresolved globs, or deletion outside those exact paths.

For `CLAUDE.md`, perform only what was approved in step 4. Write the migrated rules into their
`docs/` destinations first, then reduce `CLAUDE.md` to the single line `@AGENTS.md`. If the
migration was not approved, leave the file untouched and report it as outstanding — an unmigrated
rule silently deleted is the one failure this step must never produce.

If `.gitignore` excludes either managed runtime path, narrow the ignore rule as approved so both
copies are versioned. Preserve ignores for local settings, caches, credentials, and machine-only
state; never unignore those as a side effect.

**Project-owned:** one document at a time, and never mechanically.

1. Take the new template as the target structure.
2. Move every filled-in passage from the project's document into the matching section, **unchanged**.
   Same words, new place. You are moving text, not improving it.
3. New sections the project has no content for: keep the template's placeholder text, so it is
   visible that they need filling. Do not invent content, and do not drop a section because it looks
   irrelevant — that is the user's call, and Step 6 asks them.
4. Content with no home in the new structure: keep it under its original heading at the end of the
   document and flag it. Losing it is worse than an untidy document.
5. Preserve the document's front-matter table (dates, status, owner) — those are the project's, not
   the template's, except the framework version field which Step 6 rewrites.

Report each document as you finish it.

**Staging and committing:** Keep an exact `UPDATE_PATHS` list containing only approved files and
directories this run changed: framework-owned paths, merged `docs/NN-*.md`,
and approved `CLAUDE.md` or `.gitignore` changes. Never use `git add .`,
`git add -A`, or a broad `git add docs/`. Pre-existing staged source changes may remain in the
index. If `git diff --cached --name-only` reveals an update-surface path that was already staged
before this run, stop instead of trying to repair the user's index.

Before handing back, generate the commit block with the installed skill's renderer, one complete
relative path per `--path` argument:

```bash
bash "$UPDATE_SKILLDIR/scripts/render-update-commit.sh" --version "$NEW_VERSION" \
  --path AGENTS.md \
  --path <each-other-approved-update-path>
```

Paste the renderer's output verbatim in the handoff. It defines a Bash `UPDATE_PATHS` array, stages
only that array, and commits with `git commit --only`. Never manually wrap a raw path across lines,
never emit a directory prefix such as `.agents/skills/` by itself, and never replace the array with
a hand-written command.

## Step 6 — Stamp the version

Then update the Framework version markers already present in the project's files, including the
version field in `docs/00-ai-context.md` and any `*Clarity Framework vX.Y.Z*` footers. A stale
marker left behind makes the next run report the wrong starting point.

## Step 7 — Hand back

Tell the user, in this order:

1. **What needs them now** — new empty sections in merged documents, content you had to park at the
   end of a file, and new templates they may want to adopt.
2. What was replaced verbatim, as a count, and that both runtime copies passed `diff -qr` and are
   not excluded by `.gitignore`.
3. Orphans, with a recommendation for each.

Then paste the renderer's exact output and wait. Keep the framework update in its own commit —
mixing it with project work makes it impossible to undo cleanly, and this is a change that
occasionally needs undoing.

## Notes

- If a merge is genuinely ambiguous — the new structure splits a section the project filled in as
  one — stop on that document and ask. One question is cheaper than a document the user has to
  reconstruct.
- Two releases apart is not two runs. Go straight to the newest release; stepping through
  intermediate versions re-merges the same documents several times and loses formatting each round.
- A project that edited a framework-owned file will lose that edit here. That is the intended
  behaviour, not an accident: the framework's `README.md` states that such files are never edited in
  a project, and `docs/` is where a project's own rules belong. Mention it once in the report if you
  notice it, so the user can move the content into the governing `docs/` document before approving.
