---
name: clarity-bootstrap
description: Bootstrap Clarity Framework in a new or not-yet-managed software project by selecting the smallest useful document set, stack-specific AGENTS starter, and optional workflows from the product, team, UI, API, deployment, and AI-agent needs.
---

# Clarity Bootstrap

Set up Clarity from the project's actual needs. Produce a scoped proposal first; write only after
the user approves it. Do not generate application code.

## Guardrails

- Work in the project root. Preserve all existing source code and project-authored documentation.
- If Clarity version markers already exist in the project's documents, stop and invoke `framework-update` instead.
- If this is a Git repository and the tree has unrelated uncommitted changes, report them and stop
  before writing.
- If the directory is not under version control, put initialization in the step 4 proposal and
  initialize in step 5 once approved. Never initialize silently, and never initialize a directory
  that already sits inside another repository — that would nest one repository in another.
- Fetch only a stable tagged Clarity release. Never bootstrap from untagged `main` or a prerelease.
- Treat templates as starting structures, not permission to invent product decisions.
- Install every selected Clarity skill identically in both `.agents/skills/<name>/` and
  `.claude/skills/<name>/`. Never overwrite a same-named non-Clarity skill without approval.

## Step 1 — Inspect, then ask only for gaps

Inspect the README, build manifests, directory layout, and existing docs without changing them.
Infer what is already evident. Establish the Git state first, because it decides whether the
documents this skill writes can be versioned at all:

```bash
if TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  if [ "$TOPLEVEL" -ef "$PWD" ]; then GIT_STATE=repo-root; else GIT_STATE=inside-repo; fi
else
  GIT_STATE=none
fi
printf 'git: %s %s\n' "$GIT_STATE" "${TOPLEVEL:-}"
```

`repo-root` is the normal case. `inside-repo` means a parent directory owns the history: use it, and
never initialize a second repository inside it. `none` means the choice below is live.

Ask one compact set of questions covering only unresolved choices:

1. What is being built and for whom?
2. Which runtime and stack will it use?
3. Does it have a visual UI, persistent data, an API, deployment, or ongoing operations?
4. Is it personal, launch-bound, or maintained by a team?
5. Will Claude Code, Codex, or both be used after bootstrap?
6. Is the plan-driven workflow wanted now?
7. Only when `GIT_STATE=none`: should this bootstrap initialize a Git repository? Recommend yes.
   *Documentation as code* is a core framework principle, `.gitignore` handling and the bootstrap
   commit both depend on it, and unversioned Clarity documents lose their history from day one.

Do not ask the user to choose template numbers. Translate product needs into framework artifacts.

## Step 2 — Fetch the release

Use an isolated temporary clone and normalize the tag:

```bash
BOOTSTRAP_TMP=$(mktemp -d)
git clone --quiet --filter=blob:none \
  https://github.com/HansJoakimPersson/clarity-framework "$BOOTSTRAP_TMP/cf"
CLARITY_TAG=$(git -C "$BOOTSTRAP_TMP/cf" tag -l --sort=-v:refname 'v*' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
[ -n "$CLARITY_TAG" ] || { printf '%s\n' 'No stable Clarity release found' >&2; exit 2; }
CLARITY_VERSION=${CLARITY_TAG#v}
git -C "$BOOTSTRAP_TMP/cf" cat-file -e \
  "$CLARITY_TAG:skills/clarity-bootstrap/SKILL.md" || {
  printf '%s\n' "Latest stable release $CLARITY_TAG does not contain Clarity Bootstrap" >&2
  exit 2
}
```

Read the release's `README.md` ownership and scaling sections before selecting files. Remove the
temporary clone when the run completes or aborts. The self-check deliberately stops an unreleased
bootstrap from combining its newer rules with an older release layout; release Clarity first.

## Step 3 — Select the minimum coherent setup

Apply these conditions:

| Artifact | Select when |
| --- | --- |
| `README.md` | Always; preserve and extend an existing README, or create a concise project entry point from approved facts |
| `docs/01-vision-scope.md` | Always |
| `docs/00-ai-context.md` | Claude Code or Codex will be used after bootstrap |
| `docs/02-requirements.md` | The project has a launch, users, acceptance criteria, or a team |
| `docs/02-user-stories.md` | Only when the backlog already exceeds roughly 20 **active** stories or more than one person maintains it; otherwise keep stories in `02-requirements.md` §2.6 |
| `docs/03-sad.md` | The system has meaningful components, integrations, persistence, or deployment decisions |
| `docs/04-data-model-api.md` | Persistent data or an API exists |
| `docs/05-deployment-view.md` | The project is deployed outside a developer machine |
| `docs/06-test-documentation.md` | The project is launch-bound, production-facing, or team-maintained |
| `docs/07-runbook.md` | Someone must operate, back up, restore, or troubleshoot it |
| `docs/08-change-management.md` | Releases or changes need traceability across people or environments |
| `docs/09-visual-profile.md` | Any visual UI will be implemented |

Choose exactly one matching starter from `agents/`. Use `generic.md` when no specialized starter
matches. Never combine starters silently.

Select skills separately:

- `clarity-bootstrap`: keep it installed so the setup remains reproducible.
- `framework-update`: select by default for managed projects.
- `plan-driven-build`: select only when the user wants the multi-agent, approval-gated workflow.

## Step 4 — Propose and stop

Show:

- detected product and stack assumptions;
- the Git state, and when it is `none`, whether this run will initialize a repository — plus, if it
  will not, the exact consequences: no `.gitignore` handling, no `git check-ignore` verification,
  and no bootstrap commit, leaving the documents unversioned;
- release version;
- selected documents with one-line reasons;
- selected starter;
- selected skills and both installation paths;
- existing files that need a merge rather than a copy;
- an existing `AGENTS.md` or `CLAUDE.md` whose project-specific content must be moved into the
  governing `docs/` document before the selected starter can replace it, naming the target document
  for each piece;
- unresolved decisions.

Stop for approval. Do not write before the user approves this scope.

## Step 5 — Apply without losing existing work

After approval:

1. When initialization was approved, run `git init` before writing anything, so every file this
   skill creates is captured by the bootstrap commit rather than arriving as pre-existing untracked
   clutter. Initialize only when `GIT_STATE=none`; never run it for `repo-root` or `inside-repo`.
2. Create or update `README.md` as approved, preserving all existing content, then create `docs/`
   and copy only the approved templates from the stable tag.
3. Fill only facts established by the user's answers or existing project evidence. Leave visible
   placeholders for unknown decisions.
4. Never overwrite an existing project document. Merge the approved template structure around its
   content, or stop and ask if the mapping is ambiguous.
5. If `AGENTS.md` or `CLAUDE.md` already contains project-specific instructions, move them into the
   `docs/` document that governs each one, only as approved. Then copy the selected starter verbatim
   to `AGENTS.md`.
6. Write `CLAUDE.md` containing exactly `@AGENTS.md` and nothing else. Never reduce an existing
   `CLAUDE.md` to the import until its content has been migrated under step 5; losing a project's
   own rules is worse than leaving the file inconsistent for one more round.
7. For each selected skill, replace only its exact Clarity-managed target directory under both
   runtime roots with the release copy. Verify every pair using `diff -qr`.
8. Ensure `.gitignore` does not exclude the selected `.agents/skills/` or `.claude/skills/` files.
   Narrow broad runtime-directory ignores while preserving ignores for local settings and caches.
9. Add `docs/plans/.runs/`, `.agents/build-env.local.sh`, and `.m2/` to `.gitignore` when
   `plan-driven-build` is selected. Preserve all existing ignore rules.

Do not edit the copied `AGENTS.md` or skill files, and never add rules to `CLAUDE.md`.
Project-specific deviations belong in `docs/`, in the document that governs them.

## Step 6 — Stamp and verify

Write the marker into `docs/00-ai-context.md` — the **Clarity-managed setup** block under its AI
workflow section. That document is where `framework-update` looks for both the framework version and
the list of Clarity-managed skill names, so a marker written anywhere else leaves the next update
unable to tell a Clarity skill from a third-party one. There is no separate version file.

```text
agents-starter: <starter name without .md, or none>
skills: <comma-separated Clarity-managed names>
skill-paths: .agents/skills, .claude/skills
```

Set the framework version and date in the document's header table (**Framework version** and
**Last updated**), not in the block. One fact, one place.

When `00-ai-context.md` was not selected in step 3 — no agent will work on the project — skip the
marker and say so in the report. Nothing reads it in that case, and `framework-update` falls back to
the version footers in the other documents.

Verify:

- `CLAUDE.md` contains `@AGENTS.md` and nothing else;
- every selected document exists exactly once at its standard `docs/NN-*.md` path;
- both runtime copies of each managed skill are identical;
- `git check-ignore` confirms that neither managed skill copy is excluded;
- existing Framework version markers match the fetched tag;
- no source file or unapproved documentation file changed.

Report remaining placeholders and decisions first, then created/merged artifacts and verification
results. Propose a dedicated bootstrap commit and wait for approval before committing.

The Git-dependent checks and the commit proposal are unconditional, because step 5 has already
guaranteed a repository in every path except one: the user declined initialization. Only then, skip
those checks and close with what the project is missing and the one command that fixes it —

```text
Not under version control, so .gitignore handling, git check-ignore verification, and the bootstrap
commit were skipped. The Clarity documents exist but are unversioned. Run `git init`, then ask for a
bootstrap commit.
```

Do not present that as a routine closing note. The user declined a recommendation and the setup is
incomplete as a result; say so plainly, once, without repeating the argument for versioning.
