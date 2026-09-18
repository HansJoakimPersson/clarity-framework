# AI Usage Guide

## Clarity Framework – governed agent execution

AI agents are a first-class execution layer in Clarity Framework. They are optional for simple work,
but when used they operate under documented intent, explicit permissions, verification, and human
accountability. Agents are expected to exercise delegated authority rather than turn reversible
implementation choices into user approval prompts.

## 1. Principles

**Authority follows consequence, not category.** Agents may make reversible decisions inside the
project's documented intent, constraints, architecture, security policy, and risk tolerance. Human
approval is reserved for decisions that materially change intent, create significant external or
irreversible consequences, or cross a boundary the project explicitly reserves.

Clarity uses three decision classes:

| Class | Agent behavior | Typical examples |
| --- | --- | --- |
| **Delegated** | Decide, act, record, and continue | Local design choices, file/class structure, tests, commits, temporary branches/worktrees, internal integration, bounded replanning inside approved intent |
| **Escalation** | Propose the smallest decision needed and stop only for that decision | Material scope change, significant architecture trade-off, new external dependency or cost, security/privacy trade-off, incompatible product behavior choices |
| **Reserved** | Never perform without explicit human authorization | Destructive/irreversible operations, production publication, credential/permission changes, destructive data migrations, other boundaries named by the project |

Uncertainty alone is not an escalation condition. Resolve ordinary ambiguity from repository evidence,
documented intent, established conventions, and the least-consequential reversible choice; record the
assumption and continue.

**Documents are the agent's memory.** Separate sessions do not share memory. The project documents
are the context that lets a new agent understand the product and continue safely.

**Garbage in, garbage out.** Vague vision, requirements, and architecture documents produce vague
agent output. The quality of an agent's contribution depends directly on the quality of its context.

**Generation is not validation.** Agents are good at producing drafts and code quickly. They cannot
decide whether a draft reflects the user's reality. Human stakeholders, real users, and rendered
product behavior remain the source of truth.

## 2. Agent roles by phase

| Phase | Document | Primary agent role | Limitation |
| --- | --- | --- | --- |
| Initiation | Vision & Scope | Ask clarifying questions and structure the vision | Cannot know business context that was not provided |
| Requirements | Requirements Documentation | Draft stories, acceptance criteria, and missing NFRs | Cannot prioritize business trade-offs |
| Design | SAD | Suggest patterns, draft ADRs, and challenge decisions | Cannot know team skills, budget, or hidden dependencies |
| Design | Visual Profile | Structure tokens, calculate contrast, and suggest scales | Cannot make brand decisions |
| Design | Data Model & API | Generate schemas, API structures, and OpenAPI drafts | Cannot choose the correct domain model without domain knowledge |
| Deployment | Deployment View | Draft pipelines, containers, and infrastructure diagrams | Cannot verify the target environment directly |
| Implementation | — | Write code from the approved documents and plan | Context-free code tends to drift from architecture |
| Testing | Test Documentation | Generate test cases and test code | Cannot discover unknown edge cases reliably |
| Operations | Runbook | Troubleshoot from symptoms and logs | Cannot observe the live system without supplied evidence |

## 3. AI Context Document

`templates/00-ai-context.md` is a compact project overview intended for the start of a new session.
Keep it to one page. Update it when Vision & Scope changes, an ADR is approved, an NFR changes, the
project phase changes, or technical debt is added or removed.

It is also useful as onboarding material for a human team member. It should state the current status,
architecture, key NFRs, boundaries, open decisions, and the project's runtime contract.

## 4. Practical workflows

### Solo developer with agents

1. Start a session with `00-ai-context.md`.
2. State the concrete outcome for the session.
3. Let the agent draft or implement within the stated scope.
4. Review the result yourself.
5. Update the affected document when a decision or state change occurred.
6. Update `00-ai-context.md` when the project state changed materially.

### Team using agents

The team remains the source of truth. Decisions are made by the team, generated drafts are reviewed
by a human, and one named owner keeps `00-ai-context.md` current.

### Project without agents

The core framework works without agents. The AI Context Document and this guide may be omitted when
no agent will participate in the project.

## 5. The four-level runtime contract

The following four levels are the only AI runtime model in Clarity Framework:

| Level | Responsibility | Must not |
| --- | --- | --- |
| **Orchestrator** | Sequences work, keeps context small, exercises delegated authority, presents material escalations, and maintains the run journal | Read the entire codebase or diff itself; write production code |
| **Reasoning** | Reads deep context and produces a plan, blocking questions, or pass/fail evidence | Approve its own work, speak directly to the user, or decide scope |
| **Review** *(optional)* | Reviews the plan cold against the code before implementation | Write the plan it reviews |
| **Implementation** | Builds the approved plan in full and reports verification | Re-plan; stop on a blocking question |

A single agent may fill multiple levels, but the contracts and decision boundaries still apply.
Review does not need a different profile from the level that authored the plan: what keeps a review
from repeating the author's blind spots is a different prompt and a stateless invocation, not a
different subscription. Profiles distribute cost; prompts distribute judgment.

## 6. Context and budget boundaries

The orchestrator's context is the scarce resource. Keep these ceilings per round:

| Artifact | Ceiling |
| --- | --- |
| `00-ai-context.md` | One page, once |
| Plan | Once, after planning |
| Review report | 40 lines |
| Build log | Last 30 lines, only on failure |
| Verification report | One line per DoD condition plus 10 deviation lines |
| Run journal | About 30 lines when resuming |

The orchestrator must not read the full codebase, source files, full diff, prompts, or full build log.
Where possible, dispatch commands should enforce the limits and permissions should deny accidental
diff reads.

These ceilings are **reading budgets**, not execution budgets. A short final report does not prevent
a build agent from consuming an entire model allowance. Mutating Implementation dispatches therefore
pin an exact model and a positive rollout-token ceiling before they start. Profile selection chooses
the paying subscription; execution policy chooses the model and maximum consumption.

## 7. State, handovers, and permissions

Workflow state belongs in files, not in the orchestrator's memory. Use
`docs/plans/YYYY-MM-DD-short-name.run.md`, update it after every step, and commit it with the plan.
Store raw dispatch output in `docs/plans/.runs/`, which should be gitignored.

Long-running builds use an exit sentinel as their completion source of truth. When the harness
provides task notifications, the orchestrator records the PID and sentinel, yields control, and
resumes on the notification. It must not use `ScheduleWakeup`, an arbitrary delay, or a second
polling loop merely to check a task the harness already tracks. In a plain CLI environment without
task notifications, a bounded sentinel wait remains the fallback. A notification or sentinel only
establishes completion; the exit code still determines success or failure.

Human gates belong on **impact boundaries**, not implementation mechanics. Commits, temporary
branches/worktrees, merges back from an orchestrator-created worktree, bounded replanning inside
documented intent, and other reversible internal transitions are Delegated by default. Scope,
merge, release, push, or plan deletion are human gates only when the project's runtime contract
classifies that specific transition as Escalation or Reserved.

A plan derived from already-approved project intent does not require a second scope approval merely
because the orchestrator decomposed the project into another increment.

For governed execution, use a bounded preflight before dispatch, classify failures by cause, and
retry only explicitly retryable conditions. Verify the effective model for parent and child agents;
the requested model is not sufficient evidence by itself. Background dispatches apply the same
model-evidence check before their completion sentinel can report success. Keep a compact attempt ledger beside the
raw output, and stop on non-retryable environment, routing, verification, budget, or repository
safety failures. The executable contract and flags live in `skills/plan-driven-build/SKILL.md` and
its `dispatch.sh`.

Discipline skills are modular policy modules. `plan-driven-build` invokes them conditionally at
failure, verification, review, and closeout boundaries through their documented integration
contracts; they are not additional always-on phases.

## 8. aimux profiles

Moving token usage away from an interactive session requires separate subscriptions or accounts, not
merely separate processes. If [aimux](https://github.com/Digital-Threads/aimux) is installed, it
multiplexes multiple subscriptions within the same LLM provider and unifies each into a **profile**:
one object carrying the CLI, the model, the authentication, and the token allowance. A profile is
not an agent persona.

A level may be bound to a **pool** of interchangeable profiles rather than a single one — an
ordered, comma-separated list in the runtime contract, tried in priority order. A pool spreads load
across subscriptions; it does not give a level an identity. For Implementation, a profile's stored
model is never authoritative: the runtime contract supplies the exact model and rollout budget for
every build, so moving to another subscription cannot silently move the build to another model.
Name profiles after the subscriptions
they are, never after the level they happen to fill, or the profile becomes unusable for any other
level. `plan-driven-build`'s `dispatch.sh` resolves the CLI from the profile's `cli` field in
`~/.aimux/config.yaml` at dispatch time, so switching a level's tool is `aimux profile update` and
never a skill edit.

If a run reaches a subscription or token limit, an aimux handoff may continue it under another
profile. The handoff summary is lossy; the committed run journal is the authoritative handover
artifact.

## 9. Plan-driven build

`skills/plan-driven-build/` implements this model for Claude Code and Codex. It dispatches planning,
review, implementation, and verification through separate aimux profiles, preserves the state in a
run journal, and stops only at Escalation or Reserved impact gates. The plan is a transient work order, not an archive of
project documentation. Decisions worth keeping move into the SAD, requirements, change-management,
or other permanent project documents before the plan is deleted.

**Scope one plan as one mergeable increment.** The plan is the unit of verification and internal
integration: a whole diff is checked against its Definition of Done in a single bounded pass, and
that increment is committed and integrated as one. Human approval is required only when that
integration crosses an Escalation or Reserved boundary. Scope it to the smallest change that can merge without
leaving the product broken or half-migrated — usually one user story, and more than one only when
they cannot merge separately.

A milestone-sized plan fails quietly rather than loudly. It cannot state concrete steps within the
plan's line budget, so the steps become vague to fit; verification then compares a milestone-sized
diff against a Definition of Done it cannot cover, and reports conditions as met without real
evidence. The milestone belongs in the story map's release slices and in Change Management, and a
sequence of plans delivers it. At the other end, a change too small to justify separate planning, review, implementation, and
verification does not need this workflow at all — orchestration overhead would cost more than the
change.

## 10. Continuous improvement of governed execution

Experience from repeated framework runs should improve the execution layer itself. Treat recurring
environment failures, unbounded retries, unexpected model routing, opaque run histories, and
duplicate background-job polling as framework risks rather than isolated agent mistakes. The
framework maintainer may keep a local, unversioned implementation backlog for these improvements;
project documentation should contain only the resulting stable execution rules.

---

*Clarity Framework v4.3.0 – AI Usage Guide*
