# Plan: [short name]

> **Purpose:** Work order for an agent that did not participate in planning.
> **Lifetime:** Transient. Create, consume, and delete when the change is merged.
> **Location:** `docs/plans/YYYY-MM-DD-short-name.md`

| | |
| --- | --- |
| **Created** | YYYY-MM-DD |
| **Branch** | `[branch-name]` |
| **Delivers** | FR-[ID], FR-[ID] — or `None – [reason]` |
| **Status** | Draft / Approved / Building / Complete |
| **Gate profile** | semi-automatic *(default)* / interactive / unattended |
| **Report budget** | Review 40 lines · Verification: one answer per DoD condition + 10 deviation lines |
| **Run journal** | `docs/plans/YYYY-MM-DD-short-name.run.md` (when an automated workflow is used) |

> **Gate profile** controls supervision, not authority. `semi-automatic`, the default, executes
> Delegated work end-to-end. `interactive` may add inspection pauses only for standalone runs.
> During an active project-driver Mission Mandate, the mission's reserved-only human-gate policy
> takes precedence: Escalations return to the orchestrator and only Reserved actions may stop for a
> human. `unattended` executes every Delegated transition and reports only completion, failure, or
> a real Reserved gate. There is no universal merge gate. Check `docs/00-ai-context.md` for the
> project's authority contract and declared default.
>
> **Delivers** names the user stories this plan implements. Cite the IDs; never copy their
> acceptance criteria into this plan. The plan is transient and the requirements document is the
> source of truth, so a copy made here diverges the moment a story changes and is deleted at
> closeout. Refactoring, infrastructure, and maintenance work legitimately has no story — write
> `None – [reason]` rather than inventing one.

---

## Goal

[One sentence: what must be true when this is complete?]

## Scope

> **One plan is one mergeable increment.** It covers the smallest change that can merge on its own
> without leaving the product broken or half-migrated. That is usually a single user story; take
> more than one only when they cannot merge separately. A milestone is not a plan — it lives as a
> release slice in the story map and as a release in Change Management, and a sequence of plans
> delivers it.
>
> **Size test:** if every step cannot state a real file path and a runnable verification command
> within 200 lines, the plan is too large. Steps going vague to fit is the symptom, not the
> workaround. Split by increment, not by layer — the rule that governs splitting a story governs
> splitting a plan. Below the other end, a change too small to justify separate planning, review, implementation, and
> verification does not need a plan at all; orchestration overhead costs more than the change.

**Included:**

- [Concrete behavior or surface to build or change]
- [...]

**Excluded:**

- [Explicit boundary: what must not be touched, even if it looks tempting]
- [...]

> Goal, Included, Excluded, requirements, and documented architecture are authoritative. The build
> agent may correct local reversible implementation gaps inside those boundaries and must record the
> correction. Escalate only when the correction would materially change a boundary or consequence.

## Context to read first

> These references are compiled into one frozen context pack before review/build/verification.
> Runtime instructions are already injected, so do not list `AGENTS.md` or `CLAUDE.md`. Prefer
> `path#heading selector` over whole-file reads. Whole files over 24 KiB and anything under
> `docs/archive/` are rejected automatically.

| Reference | Why |
| --- | --- |
| `docs/00-ai-context.md` | Compact project orientation, runtime/authority contract, and active state |
| `docs/02-requirements.md#FR-[ID]` | Acceptance criteria for the story in **Delivers** |
| `docs/03-sad.md#ADR-[ID]` | Architectural decision governing this change |
| `docs/04-data-model-api.md#[exact heading]` | Only the affected data/API contract section |
| `docs/09-visual-profile.md#[exact heading]` | Only the visual rules the change actually touches |

## Steps

> **A step whose Verification launches a real browser (Playwright, or anything else that spawns
> Chromium/WebKit/Firefox) must not chain that command into the same Verification line as the rest
> of the step's build/test work.** Under this workflow's default `--mode workspace-write` dispatch,
> codex's own sandbox denies Chromium's dynamic Mach-port service registration
> (`bootstrap_check_in ... MachPortRendezvousServer: Permission denied (1100)`) — confirmed to be the
> sandbox policy itself, not the project or the browser binary, by launching the same binary
> unsandboxed on the same machine, which succeeds cleanly. Write the browser-launching command as its
> own step (or its own final Verification line) and note in that step that the orchestrator must
> dispatch it under `--mode danger-full-access` instead of `workspace-write`. Keep everything else —
> writing application code, `npm run lint`, `npm run build`, the Maven/test gate — under
> `workspace-write`; `danger-full-access` removes the sandbox entirely and must stay scoped to the one
> command that needs it.
>
> **Prefer a subshell — `(cd dir && cmd)` — over chaining a relative `cd` into the rest of a
> Verification line.** A command written as `cd frontend && npm run build && cd .. && jar tf
> target/app.jar` leaves the shell in `frontend` if the middle command fails before the trailing `cd
> ..` runs, so the next command in the chain (or the next step, if the shell persists) resolves paths
> against the wrong directory and reports a false failure — observed as a spurious "JAR not found"
> after a successful build, costing a full build cycle to diagnose. A subshell confines the directory
> change to that command alone regardless of how it exits.
>
> **In a whole-module compilation language (Java, C#, Go, and similar), order steps so each one
> compiles standalone.** A step that writes a test referencing a production type another, later step
> introduces fails at compilation, not just at assertion — Implementation cannot build it in
> isolation and has no scope to improvise the missing type. Put the production symbol before, or in
> the same step as, the test that exercises it.
>
> **A schema-wide directive (a trigger, constraint, index, or grant applied "to every X") must name
> every affected table or entity explicitly, and state which related tables are excluded and why.**
> Phrasing it as a count ("all five tables") drifts silently as the schema section is edited later
> without the count being rechecked, and Implementation has no way to notice the mismatch except by
> guessing or stopping mid-build.

1. **[What]** in `path/to/file.ext`
   [Concrete description, sufficient to build without guessing]
   Verification: `[command]`

2. **[What]** in `path/to/file.ext`
   [...]
   Verification: `[command]`

## Open questions

- [ ] **ESCALATION:** [Material choice whose alternatives change scope, behavior, architecture, security/privacy, cost, or reversibility]
- [ ] **RESERVED:** [Action the project explicitly keeps for a human]
- [ ] Assume [X] and continue; record the assumption in the report

> Resolve Delegated questions from project evidence and continue. During an active Mission
> Mandate, Escalation means "return to the orchestrator for resolution", not "ask the user". Only
> Reserved items may become human gates, and only after project-driver issues a `HUMAN_GATE` token.

## Definition of Done

- [ ] [Checkable condition, not “works well” but “command X produces result Y”]
- [ ] Every acceptance criterion of the stories in **Delivers** is verified, cited by ID: AC-[ID]
- [ ] Tests pass
- [ ] Affected Clarity Framework documents are updated
- [ ] For UI changes, rendered visual evidence covers the changed journey, states, and target viewports

> Review each condition against the diff with concrete evidence. A condition that cannot be proven
> by a path, symbol, or command result is an assessment, not a condition. Under `unattended`, this is
> a hard requirement.
>
> A condition that checks an **Excluded** boundary held must scan the whole diff or package against
> it, not a single named file or class — a check scoped to one file has repeatedly reported
> "excluded surfaces untouched" while the same change touched other excluded files elsewhere.

## At closeout

Answer before deleting the plan. “Nothing” is valid; no answer is not.

- [ ] Are the stories in **Delivers** set to their new status, with the traceability table in
      `docs/02-requirements.md` §5 updated to the test cases that prove them?
- [ ] Which build decisions belong in `docs/03-sad.md`?
- [ ] What belongs in `docs/08-change-management.md`?
- [ ] Has `docs/02-requirements.md` §2.6 passed roughly 20 active stories without being split into
      `docs/02-user-stories.md`? A backlog left unsplit past that threshold degrades from a document
      into an unreadable log.
- [ ] What was wrong with the plan? One sentence makes the next plan better.

> Delete the plan here. Without these answers, the lesson is deleted with it. The story status and
> the traceability table are the record that outlives this plan; write them back before deleting it.

---

*Clarity Framework v4.3.0 – Plan Template*
