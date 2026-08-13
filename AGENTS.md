# AGENTS.md – Clarity Framework repository instructions

> Read automatically by Codex and imported by Claude Code through `CLAUDE.md`.
> These instructions govern the framework repository itself, not projects that use it.

## What this repository is

Clarity Framework is a methodology-agnostic documentation framework for software development. It
scales from a personal side project to a team of 20. AI agents are a first-class execution layer
governed by documented decisions, verification gates, and human accountability.

**Three core principles:** Just enough documentation · Documentation as code · Clarity over completeness

**Current version:** 3.1.0

**Repository structure:**

```text
/framework/    – Framework guides, CHANGELOG, and project instructions
/templates/    – Templates to copy into a project's /docs
/agents/       – AGENTS.md starters by stack
/skills/       – Skills to copy into .agents/skills and .claude/skills
```

All framework content is English. Keep file names, headings, placeholders, paths, commands, and
examples in English as well.

## Commit discipline

Work directly on `main`. One commit is one meaningful, complete unit of change.

**Format:** `[type] Short imperative description`

| Type | When |
| --- | --- |
| `patch` | Corrections, typos, and clarifications |
| `minor` | New sections, templates, or documents |
| `major` | Breaking changes affecting completed documents |
| `docs` | Changes in `/framework` that are not templates |
| `chore` | Repository maintenance and script changes |

A commit is incomplete when it has no CHANGELOG entry, affected guides and templates are inconsistent,
or the version markers were not updated. Every change increments the version in the same commit;
`docs` and `chore` changes do not increment it.

Update all files carrying a framework version:

```bash
git grep -lE 'Clarity Framework v[0-9]+\.[0-9]+\.[0-9]+|Current version:|\*\*Version:\*\*' \
  -- '*.md' ':!framework/CHANGELOG.md'
```

## Files that move together

| Change | Include |
| --- | --- |
| Template change | Template and any affected guide |
| `templates/plan.md` | Identical `skills/plan-driven-build/plan-template.md`; verify with `diff` |
| Dispatch prompt change | The matching prompt and `SKILL.md` when placeholders change |
| New template | New file, README, and CHANGELOG entry |
| Framework guideline change | Guide and affected templates |
| Release | CHANGELOG, version markers, and annotated Git tag |

At the end of a session, summarize changed files, group them logically, and propose commit messages.
Wait for approval before committing.

## Release strategy

Releases are explicit and manually tagged, never automatic.

```text
MAJOR.MINOR.PATCH
  │     │     └── Backward-compatible corrections
  │     └──────── New templates, sections, and additions (backward-compatible)
  └────────────── Breaking changes (require migration of completed documents)
```

The version number has already been incremented when a release is made; that happened in the commit
that introduced the change. A release therefore does not “set the version”; it publishes the version
that already exists.

**When the user triggers a release:**

1. Verify that `git status` is clean.
2. Verify that the version is consistent in every tracked file carrying it:
   `git grep -hoE 'Clarity Framework v[0-9]+\.[0-9]+\.[0-9]+' -- '*.md' ':!framework/CHANGELOG.md' | sort -u`
   must return exactly one line.
3. Date the pending version heading in `framework/CHANGELOG.md`.
4. Run `git add framework/CHANGELOG.md && git commit -m "[chore] Release vX.Y.Z"`.
5. Create an annotated tag:
   `git tag -a vX.Y.Z -m "Clarity Framework vX.Y.Z – description"`.
6. Push the commit and tag with `git push origin main --tags`.

The tag is the only source read by `skills/framework-update/`. A project never updates from untagged
`main`, so it does not matter that the version was incremented before the tag exists.

---

*Clarity Framework v3.1.0*
