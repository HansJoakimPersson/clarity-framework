---
name: ramverksuppdatering
description: Upgrade a project's Clarity Framework documents and tooling to the latest release, preserving everything already written. Use when the project is on an older framework version, when a new release is out, or when the user asks to update or sync the framework.
---

# Framework Update (ramverksuppdatering)

Bring this project to the shape the **current** Clarity Framework release prescribes, without losing
a word of what is already written.

The target state is concrete: the project should end up looking the way it would have looked if the
framework had been applied at today's version from the start — same files, same structure, same
sections — except that every filled-in passage is the one that was already there.

This skill has nothing to do with the plan-driven build workflow. Do not dispatch anything, do not
involve other agents or accounts. You do this yourself, in this session.

## What you may touch

| Framework path | Project path | Note |
| --- | --- | --- |
| `templates/NN-*.md` | `docs/NN-*.md` | Only those the project already has, plus new ones it should have |
| `agents/<stack>.md` | `AGENTS.md` | Always adapted by the project — never a straight overwrite |
| `skills/<name>/` | `.claude/skills/<name>/` | Copied verbatim unless locally modified |
| `templates/plan.md` | — | Not copied into projects; the skill that needs it carries its own copy |
| `framework/`, `README.md` | — | The framework's own documents. Never copied into a project |

Three rules that hold throughout:

- **Never delete anything.** A file the framework dropped is reported, not removed.
- **Never touch source code**, build config, or anything outside the paths above.
- **Never overwrite a file that differs from the version it was copied from.** That difference is
  the user's work, by definition.

## Preconditions

- `git status --porcelain` is empty. A sync into a dirty tree cannot be told apart from what was
  already uncommitted. If it is dirty, report what is uncommitted and stop.
- `git` is available and github.com is reachable.

## Step 1 — Establish the project's current version

Look in this order and use the first that answers:

1. `docs/.clarity-version` — written by this skill, authoritative when present.
2. The **Ramverksversion** field in `docs/00-ai-context.md`.
3. A `*Clarity Framework vX.Y.Z*` footer in any file under `docs/`.
4. Nothing found. Then infer from which templates and sections exist, compare against each release,
   and pick the closest match — but **say that you inferred it and which evidence you used**. A
   wrong baseline makes every classification in Step 3 wrong, so this is worth being explicit about.

Also note which `agents/` starter `AGENTS.md` came from, if `.clarity-version` records it. If it
does not, do not guess from content — treat `AGENTS.md` as *migrate* in Step 3 and let the user
confirm.

## Step 2 — Fetch the framework

Clone once, outside the project, and read any version from it:

```bash
TMP=$(mktemp -d)
git clone --quiet --filter=blob:none https://github.com/HansJoakimPersson/clarity-framework "$TMP/cf"
BASE=$(git -C "$TMP/cf" tag -l 'v*' | sort -V | grep -x "v<project version>" || echo "")
NEW=$(git -C "$TMP/cf" tag -l 'v*' | sort -V | tail -1)
git -C "$TMP/cf" show "$NEW:templates/03-sad.md"      # read any file at any version like this
```

If `$NEW` equals the project's version, say so and stop — there is nothing to do. If the project's
version has no matching tag, use the oldest tag as baseline and flag that the comparison is coarser.

Clean up `$TMP` when you are done, whatever the outcome.

## Step 3 — Classify every file three ways

For each framework-owned file, compare **three** versions: the file at the baseline release, the
file at the new release, and the file in the project. That is what makes the classification exact
instead of a guess.

| Project file | Baseline vs new | Class | Action |
| --- | --- | --- | --- |
| Missing | exists in new | **add** | Copy in verbatim |
| Identical to baseline | changed | **replace** | Copy in verbatim — untouched since it was copied |
| Identical to baseline | unchanged | **skip** | Nothing to do |
| Differs from baseline | unchanged | **leave** | Local work, no framework change. Do not touch |
| Differs from baseline | changed | **migrate** | The hard case. Step 5 |
| Exists, gone from new | — | **orphan** | Report only. Never delete |

Renames between releases follow the rename — check `git -C "$TMP/cf" log --follow --name-status` for
a file that looks orphaned before reporting it as such.

For every **migrate**, work out *what* changed structurally rather than diffing prose:

````bash
headings() { awk '/^```/{f=!f;next} !f && /^#+ /'; }   # skips fenced code blocks
diff <(git -C "$TMP/cf" show "$BASE:templates/05-deployment-view.md" | headings) \
     <(git -C "$TMP/cf" show "$NEW:templates/05-deployment-view.md"  | headings)
````

Added and removed headings are the migration, and they are what the user needs to see to judge it.
The code-block filter matters: several templates contain shell comments that a plain `grep '^#'`
reports as new sections.

## Step 4 — Report, then stop

Present:

- Detected version → target version, and whether the baseline was read or inferred.
- Counts per class, then every **migrate** and **orphan** by name with one line on what changed.
- New templates the project will gain, with a note that they arrive empty and need filling.

**Stop and wait for approval.** Nothing is written before this point. The user is approving a scope,
not a diff — keep the report short enough to actually read.

## Step 5 — Apply

Work in class order, and report each file as you go.

**add** and **replace** — copy verbatim from the new release. No edits, no adaptation.

**migrate** — one file at a time, and never mechanically:

1. Take the new release's template as the target structure.
2. Move every filled-in passage from the project's file into the matching section of that structure,
   unchanged. Same words, new place.
3. New sections that the project has no content for: keep the template's placeholder text so it is
   visible that they need filling. Do not invent content, and do not quietly drop a section because
   it looks irrelevant.
4. Content in the project's file with no home in the new structure: keep it. Put it under its
   original heading at the end and flag it in the report. Losing it is worse than an untidy document.

`AGENTS.md` is always a migrate, never a replace: it is adapted per project by design. Bring in new
sections from the starter — the *When You Are a Dispatched Agent* section, for instance — and leave
the project's own rules alone.

**skip**, **leave**, **orphan** — no writes.

## Step 6 — Stamp the version

Write `docs/.clarity-version`:

```text
version: X.Y.Z
uppdaterad: ÅÅÅÅ-MM-DD
agents-starter: <stack, or "egen">
skills: <comma-separated skill directories in .claude/skills/, or "inga">
```

Then update the version markers that already exist in the project's own files — the
**Ramverksversion** field in `docs/00-ai-context.md` and any `*Clarity Framework vX.Y.Z*` footers.
Leaving a stale marker behind makes the next run start from the wrong baseline.

## Step 7 — Hand back

Tell the user, in this order:

1. **What needs them now** — new empty templates, new empty sections in migrated documents, and any
   content you had to park at the end of a file.
2. What was replaced verbatim.
3. Orphans, and your recommendation for each.

Then propose a commit and wait. Keep the framework update in its own commit — mixing it with project
work makes it impossible to undo cleanly, and this is a change that occasionally needs undoing.

## Notes

- A project that skipped `docs/00-ai-context.md` has no version marker at all before the first run
  of this skill. That is expected for small projects; the inference path in Step 1 exists for
  exactly that case, and `docs/.clarity-version` fixes it permanently from then on.
- Two releases apart is not two runs. Classify against the project's actual baseline and go straight
  to the newest release — stepping through intermediate versions re-migrates the same documents
  several times and loses formatting each round.
- If a migrate looks genuinely ambiguous — the new structure splits a section the project filled in
  as one — stop on that file and ask. One question is cheaper than a document the user has to
  reconstruct.
