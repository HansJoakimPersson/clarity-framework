# Skills – reusable workflows for Claude Code and Codex

This directory contains ready-made skills to copy into a project when a workflow is needed.

A copied skill **belongs to the framework and must not be edited in the project**. It is replaced
wholesale when the project updates to a new framework release. Only Clarity skill names listed in
`00-ai-context.md` are managed; local and third-party skills are never touched. Project-specific
workflow differences belong in `docs/00-ai-context.md`. See the ownership table in the framework
`README.md`.

## What is a skill?

A skill is a named workflow in the Agent Skills format that Claude Code and Codex can invoke. It
answers a different question from the other Clarity documents:

| Document | Answers |
| --- | --- |
| `docs/00-ai-context.md` | What is the project? |
| `AGENTS.md` | How must the agent always work here? |
| `.agents/skills/*/SKILL.md` / `.claude/skills/*/SKILL.md` | How is this specific workflow run? |

`AGENTS.md` applies to every task. A skill applies only when invoked.

## Available skills

| Directory | Use when… |
| --- | --- |
| `clarity-bootstrap/` | A new or unmanaged project needs the smallest relevant document set, stack starter, and skills for both clients |
| `plan-driven-build/` | The task is large enough to require scope approval before code is written, with planning, review, and implementation dispatched to other aimux profiles. Requires a second AI CLI — `codex` today — since the orchestrator dispatches rather than builds |
| `framework-update/` | A project on an older framework version must be upgraded without losing completed work |

The three skills are independent. `clarity-bootstrap/` sets up an unmanaged project, while
`framework-update/` works only with projects that already use Clarity. The latter does not
dispatch anything; it runs in the current session and touches only approved framework paths under
`docs/`, `AGENTS.md`, `.agents/skills/`, and `.claude/skills/`.

Unrelated changes in project code, build files, tests, or application configuration do not need to
be committed first. `framework-update` protects its own write surface and proposes a separate
commit using an explicit path list.

## How to use a skill

1. Copy the same directory to both client-specific project locations:

   ```bash
   mkdir -p /path/to/project/.agents/skills /path/to/project/.claude/skills
   cp -R skills/plan-driven-build /path/to/project/.agents/skills/
   cp -R skills/plan-driven-build /path/to/project/.claude/skills/
   diff -qr /path/to/project/.agents/skills/plan-driven-build \
     /path/to/project/.claude/skills/plan-driven-build
   ```

2. Review `setup.md` for profiles, sandbox, approval settings, and permissions. This is a
   one-time setup per machine and determines whether the workflow can run unattended.
3. Invoke it in Claude Code with `/plan-driven-build`, or in Codex with `$plan-driven-build` or through
   `/skills`.

Step 2 concerns the machine, not the copied files. Project deviations belong in
`docs/00-ai-context.md`; leave the copied files unchanged so they can be replaced at the next
framework update.

### What the files in `plan-driven-build/` do

| File | Role |
| --- | --- |
| `SKILL.md` | The procedure; the only file the orchestrator reads when invoked |
| `prompts/*.txt` | Instructions for dispatched agents, kept outside the orchestrator's context |
| `dispatch.sh` | The only dispatch entry point; sets sandbox and approval together and enforces budgets |
| `tests/dispatch-test.sh` | Regression test for profile resolution, CLI flag ordering, and failure sentinels |
| `plan-template.md` | The plan template, identical to `templates/plan.md` |
| `journal-template.md` | The run journal template and handover state |
| `setup.md` | One-time setup for profiles, permissions, and gitignore |
| `settings.example.json` | Claude Code permissions example |

Skills are versioned in the project repository like all other documentation. Use `git check-ignore`
to ensure broad `.claude/` or `.agents/` rules do not exclude the managed copies while local
settings, credentials, and caches remain ignored.

The `prompts/` directories are internal resources for their scripts. They are unrelated to Codex's
deprecated `~/.codex/prompts/` and Claude Code's older `.claude/commands/`; both clients use the
shared `SKILL.md` frontend.

## Precedence

1. An explicit user instruction in the session
2. The project's `docs/` — its decisions, conventions, and deviations
3. The project's framework-owned `AGENTS.md` — how to work where `docs/` is silent
4. The skill's `SKILL.md`

`CLAUDE.md` is absent from this order deliberately: it contains only `@AGENTS.md` and carries no
rules of its own. A skill that conflicts with `docs/` or `AGENTS.md` must be adapted, not followed
blindly.

---

*Clarity Framework v4.0.0*
