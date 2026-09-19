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
| `project-driver/` | The user provides project/product intent and wants the orchestrator to drive successive increments with minimal routine interaction |
| `plan-driven-build/` | A non-trivial increment needs bounded planning, cold review, implementation, and verification dispatched to other aimux profiles. Requires a second AI CLI — `codex` today — since the orchestrator dispatches rather than builds |
| `framework-update/` | A project on an older framework version must be upgraded without losing completed work |
| `verification-before-completion/` | Any task, story, build, or checklist item is about to be reported done |
| `systematic-debugging/` | A bug, test failure, crash, or unexpected behavior needs investigating before a fix is proposed |
| `requesting-code-review/` | A change is ready for another reviewer, before merging or asking for approval |
| `receiving-code-review/` | Review feedback has come back and needs a response |
| `finishing-a-development-branch/` | A branch is believed done, or its work has landed and needs closing out |

`clarity-bootstrap/`, `project-driver/`, `plan-driven-build/`, and `framework-update/` are
multi-step workflows dispatched by name. `project-driver/` is the outer project loop: it turns
documented intent into successive increments and invokes `plan-driven-build/` for each non-trivial
one. `project-driver/` persists a Mission Mandate across increments and resumed sessions; its
`scripts/mission-control.sh` continuation state machine and `scripts/authority.sh` approval
firewall make "continue until complete" executable policy rather than conversational memory.
`clarity-bootstrap/` sets up an unmanaged project, while `framework-update/` upgrades a managed
one. `plan-driven-build/` is the execution engine that requires the second CLI noted above.

The five discipline skills (`verification-before-completion/` through
`finishing-a-development-branch/`) are single-file, self-contained, and apply to any task an agent
performs in the project — not only work started through one of the three named workflows. They also
expose small integration contracts for `plan-driven-build`: debugging classifies failures,
verification validates completion claims, review skills handle review boundaries, and branch-finish
handles closeout. Install whichever ones fit the project; the contracts are optional outside that
workflow and do not make the skills depend on one another.

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

### What the files in `project-driver/` do

| File | Role |
| --- | --- |
| `SKILL.md` | Outer delivery loop and Mission Mandate contract |
| `scripts/mission-control.sh` | Persists mission state, continuation checkpoints, deadlines, and human-gate tokens |
| `scripts/authority.sh` | Resolves actions as Delegated, Orchestrator Escalation, or Reserved HUMAN_GATE |
| `tests/authority-test.sh` | Regression test for policy/default authority classification |
| `tests/mission-control-test.sh` | Regression test that successful increments continue and only Reserved actions create human gates |

### What the files in `plan-driven-build/` do

| File | Role |
| --- | --- |
| `SKILL.md` | The procedure; the only file the orchestrator reads when invoked |
| `prompts/*.txt` | Instructions for dispatched agents, kept outside the orchestrator's context |
| `dispatch.sh` | Dispatch entry point; sets sandbox/approval, pins execution policy, starts supervised background jobs, and records native usage |
| `background-supervisor.sh` | Owns a background worker, writes health heartbeats, detects no-progress and wall-clock timeouts, terminates the process tree, and always produces a classified completion sentinel |
| `dispatch-health.sh` | Reads sentinel/health state mechanically as finished, healthy, stale, or lost without tailing the worker log |
| `context-pack.sh` | Compiles exact plan references into the frozen bounded document context used by review/build/verification |
| `tests/dispatch-test.sh` | Regression test for profile resolution, CLI flag ordering, telemetry, sentinels, silent hangs, hard wall timeouts, and watchdog recovery |
| `tests/context-pack-test.sh` | Regression test for heading extraction, byte ceilings, and cold-context rejection |
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

## Writing or auditing a skill

A `SKILL.md` needs YAML frontmatter with exactly two required fields:

- `name` — letters, numbers, and hyphens only, matching the directory name.
- `description` — third person, starting with "Use when…", stating only the triggering
  situation. Never summarize the skill's steps here: an agent that reads a summarized workflow in
  the description tends to follow that summary instead of opening the file, which defeats a skill
  whose actual procedure differs in any detail from its one-line gloss.

Prefer a single self-contained `SKILL.md` (the five discipline skills above are all this shape).
Reach for extra files only for a heavy reference the body would drown in, or a reusable script or
template — `plan-driven-build/` is the example already in this directory. Keep the body scoped to
what an agent must do differently because of this skill; move anything else to the guide or template
that already owns it.

There is no fixed length requirement — a discipline reminder loaded on every relevant task earns
its brevity, while a multi-step, infrequently-invoked orchestration procedure like
`plan-driven-build/` earns the precision that comes with being explicit. Favor tables and short
guardrail lists over prose narrative and flowcharts; a workflow's real decision points are almost
always better shown as a table (see `plan-driven-build/`'s Gate profiles) than as a diagram.

## Precedence

1. An explicit user instruction in the session
2. The project's `docs/` — its decisions, conventions, and deviations
3. The project's framework-owned `AGENTS.md` — how to work where `docs/` is silent
4. The skill's `SKILL.md`

`CLAUDE.md` is absent from this order deliberately: it contains only `@AGENTS.md` and carries no
rules of its own. A skill that conflicts with `docs/` or `AGENTS.md` must be adapted, not followed
blindly.

---

*Clarity Framework v4.3.2*
