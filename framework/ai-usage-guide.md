# AI Usage Guide

## Clarity Framework – governed agent execution

AI agents are a first-class execution layer in Clarity Framework. They are optional for simple work,
but when used they operate under documented decisions, explicit permissions, verification gates, and
human accountability. AI may propose, draft, implement, and verify; it does not own product decisions.

## 1. Principles

**AI owns no decisions.** Architecture, priorities, and scope remain human decisions. An agent may
propose, challenge, and draft, but it must not silently decide.

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
| **Orchestrator** | Sequences work, keeps context small, presents distillates, owns approval gates, and maintains the run journal | Read the entire codebase or diff itself; write production code |
| **Reasoning** | Reads deep context and produces a plan, blocking questions, or pass/fail evidence | Approve its own work, speak directly to the user, or decide scope |
| **Review** *(optional)* | Reviews the plan cold against the code before implementation | Write the plan it reviews |
| **Implementation** | Builds the approved plan in full and reports verification | Re-plan; stop on a blocking question |

A single agent may fill multiple levels, but the contracts and approval boundaries still apply. The
level that reviews a plan should use a different account from the level that authored it when practical.

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

## 7. State, handovers, and permissions

Workflow state belongs in files, not in the orchestrator's memory. Use
`docs/plans/YYYY-MM-DD-short-name.run.md`, update it after every step, and commit it with the plan.
Store raw dispatch output in `docs/plans/.runs/`, which should be gitignored.

Long-running builds use an exit sentinel rather than log polling. A new session or CLI can read the
journal and the sentinel and continue without reconstructing the entire context.

Human gates belong on decisions: scope, merge, release, and plan deletion. Tool calls inside the
approved sandbox should not become artificial approval gates.

## 8. Accounts and aimux

Moving token usage away from an interactive session requires separate subscriptions or accounts, not
merely separate processes. If [aimux](https://github.com/Digital-Threads/aimux) is installed, it can
multiplex multiple subscriptions or accounts within the same LLM provider. Each account retains its
own authentication and token allowance. aimux does not create agent personas or behavioral profiles.

If a run reaches a subscription or token limit, an aimux handoff may continue it under another account.
The handoff summary is lossy; the committed run journal is the authoritative handover artifact.

## 9. Plan-driven build

`skills/plan-driven-build/` implements this model for Claude Code and Codex. It dispatches planning,
review, implementation, and verification through separate account contexts, preserves the state in a
run journal, and stops at human approval gates. The plan is a transient work order, not an archive of
project documentation. Decisions worth keeping move into the SAD, requirements, change-management,
or other permanent project documents before the plan is deleted.

**Scope one plan as one mergeable increment.** The plan is the unit of the merge gate and the unit
of verification: a whole diff is checked against its Definition of Done in a single bounded pass, and
that increment is approved and merged as one. Scope it to the smallest change that can merge without
leaving the product broken or half-migrated — usually one user story, and more than one only when
they cannot merge separately.

A milestone-sized plan fails quietly rather than loudly. It cannot state concrete steps within the
plan's line budget, so the steps become vague to fit; verification then compares a milestone-sized
diff against a Definition of Done it cannot cover, and reports conditions as met without real
evidence. The milestone belongs in the story map's release slices and in Change Management, and a
sequence of plans delivers it. At the other end, a change too small to need scope approval before
code is written does not need this workflow at all — the dispatches and gates cost more than the
change.

---

*Clarity Framework v3.0.1 – AI Usage Guide*
