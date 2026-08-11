---
name: ramverksuppdatering
description: Upgrade a project's Clarity Framework documents and tooling to the latest release, preserving everything already written. Use when the project is on an older framework version, when a new release is out, or when the user asks to update or sync the framework.
---

# Framework Update (ramverksuppdatering)

Bring this project to the shape the **current** Clarity Framework release prescribes, without losing
a word of what is already written.

The target state is concrete: the project should end up looking the way it would have looked if the
framework had been applied at today's version from the start — same files, in the same places, with
the same structure — except that every filled-in passage is the one that was already there.

This skill has nothing to do with the plan-driven build workflow. Do not dispatch anything and do
not involve other agents or accounts. You do this yourself, in this session.

## The ownership rule

Every path has exactly one owner, and that decides what happens to it:

- **Framework-owned** files are replaced wholesale. They are never edited in a project, so there is
  nothing in them worth preserving. Do not diff them, do not merge them — overwrite.
- **Project-owned** files hold the user's work. Their *content* is preserved and their *structure*
  is lifted to the new template.
- Everything else is untouched.

Do not carry a copy of the mapping in this file. Read it from the release you fetched, in
`README.md` under **Projektstruktur** and **Vem äger vad** — that section is normative and is what
this skill follows. If it disagrees with anything below, it wins.

Three rules hold throughout: **never delete**, **never touch source code**, and **never edit
`CLAUDE.md`** — it is where the project records its own deviations, and it is the reason
framework-owned files can be replaced safely.

## Preconditions

- `git status --porcelain` is empty. A sync into a dirty tree cannot be told apart from what was
  already uncommitted. If it is dirty, report what is uncommitted and stop.
- `git` is available and github.com is reachable.

## Step 1 — Fetch the framework and read the rules

```bash
TMP=$(mktemp -d)
git clone --quiet --filter=blob:none https://github.com/HansJoakimPersson/clarity-framework "$TMP/cf"
NEW=$(git -C "$TMP/cf" tag -l 'v*' | sort -V | tail -1)
git -C "$TMP/cf" show "$NEW:README.md"          # placement and ownership
git -C "$TMP/cf" show "$NEW:templates/03-sad.md" # read any file at any version like this
```

Read `README.md` at `$NEW` first. Clean up `$TMP` when you are done, whatever the outcome.

## Step 2 — Establish the project's current version

Look in this order and use the first that answers:

1. `docs/.clarity-version` — written by this skill, authoritative when present.
2. The **Ramverksversion** field in `docs/00-ai-context.md`.
3. A `*Clarity Framework vX.Y.Z*` footer in any file under `docs/`.
4. Nothing found — say so, and treat every document as needing a structure check against `$NEW`.
   You do not need the old version to do the work; it only tells you how much to expect.

If the project is already on `$NEW`, say so and stop.

## Step 3 — Decide what happens to each file

**Framework-owned — replace or add, no comparison needed:**

| File | How to place it |
| --- | --- |
| `AGENTS.md` | Copy the matching starter from `$NEW:agents/`. Identify which one from `docs/.clarity-version`, or from the project file's own title line — every starter begins `# AGENTS.md - <Stack> vX.Y`. If the project has none, ask which stack rather than guessing |
| `.claude/skills/<name>/` | Copy the whole directory from `$NEW:skills/<name>/`, including files the project does not have yet |

If a framework-owned file in the project differs from the new release, that is expected — it is an
older version. Replace it. Do not report the difference as a conflict and do not try to preserve
anything from it.

**Project-owned — merge, one document at a time:**

`docs/NN-*.md` hold the user's writing. For each, compare the project's document against the new
template and work out what structurally differs — added sections, renamed headings, reordered
parts. You do not need the project's old template version for this: a template section is
recognisable by its placeholder text and its heading, and the user's prose is recognisable by being
prose. Trust that judgment; it is more reliable than inferring a baseline.

**New templates** the project should have but does not: report them. Copying an unfilled template
into `docs/` is a decision about scope, so let the user choose per file rather than adding all of
them.

**Orphans** — a file in the project that the framework no longer ships: report it with a
recommendation. Check `git -C "$TMP/cf" log --follow --name-status` before calling something an
orphan; it may have been renamed.

## Step 4 — Report, then stop

Present, in this order:

- Detected version → `$NEW`, and how the version was determined.
- Framework-owned files to be replaced or added — a count and the list, no diffs. Nothing here needs
  the user's judgment.
- Project-owned documents needing a merge, each with one line on what structurally changed.
- New templates available, and orphans.

**Stop and wait for approval.** Nothing is written before this point. The user is approving a scope,
not a diff — keep it short enough to actually read.

## Step 5 — Apply

**Framework-owned:** copy verbatim. No edits, no adaptation, no merging.

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

## Step 6 — Stamp the version

Write `docs/.clarity-version`:

```text
version: X.Y.Z
uppdaterad: ÅÅÅÅ-MM-DD
agents-starter: <filename from agents/, without .md>
skills: <comma-separated directories in .claude/skills/, or "inga">
```

Then update the version markers already present in the project's files — the **Ramverksversion**
field in `docs/00-ai-context.md` and any `*Clarity Framework vX.Y.Z*` footers. A stale marker left
behind makes the next run report the wrong starting point.

## Step 7 — Hand back

Tell the user, in this order:

1. **What needs them now** — new empty sections in merged documents, content you had to park at the
   end of a file, and new templates they may want to adopt.
2. What was replaced verbatim, as a count.
3. Orphans, with a recommendation for each.

Then propose a commit and wait. Keep the framework update in its own commit — mixing it with project
work makes it impossible to undo cleanly, and this is a change that occasionally needs undoing.

## Notes

- If a merge is genuinely ambiguous — the new structure splits a section the project filled in as
  one — stop on that document and ask. One question is cheaper than a document the user has to
  reconstruct.
- Two releases apart is not two runs. Go straight to the newest release; stepping through
  intermediate versions re-merges the same documents several times and loses formatting each round.
- A project that edited a framework-owned file will lose that edit here. That is the intended
  behaviour, not an accident: the framework's `README.md` states that such files are never edited in
  a project, and `CLAUDE.md` is where a project's own rules belong. Mention it once in the report if
  you notice it, so the user can move the content to `CLAUDE.md` before approving.
