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

> **Gate profile** determines where the workflow stops for you. `semi-automatic`, the default, stops
> at scope and merge — the two decisions that are yours and hard to walk back. `interactive` adds
> stops at commit and closeout, worth it for unfamiliar or risky work. `unattended` stops only at
> merge and requires every Definition of Done condition to be command-checkable. The merge gate
> exists in all three. Choose by risk, not impatience.
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
> splitting a plan. Below the other end, a change too small to need scope approval does not need a
> plan at all; five dispatches and four gates cost more than the change.

**Included:**

- [Concrete behavior or surface to build or change]
- [...]

**Excluded:**

- [Explicit boundary: what must not be touched, even if it looks tempting]
- [...]

> This section is authoritative. The build agent must not re-plan. If the plan is wrong or
> incomplete, stop and report instead of improvising.

## Context to read first

| Document | Why |
| --- | --- |
| `AGENTS.md` | Applies in full: style, security, and test requirements |
| `docs/00-ai-context.md` | Project orientation, runtime contract, and deviations from framework defaults |
| `docs/02-requirements.md` § [story IDs] | Acceptance criteria for the stories in **Delivers**; authoritative over this plan |
| `docs/03-sad.md` § [section] | Architecture decision governing this change |
| `docs/04-data-model-api.md` | When the change concerns data models or API contracts |
| `docs/09-visual-profile.md` | When the change affects anything visual |

## Steps

1. **[What]** in `path/to/file.ext`
   [Concrete description, sufficient to build without guessing]
   Verification: `[command]`

2. **[What]** in `path/to/file.ext`
   [...]
   Verification: `[command]`

## Open questions

- [ ] **BLOCKING:** [Must be answered by a human before the build starts]
- [ ] Assume [X] and continue; record the assumption in the report

> Blocking questions stop the build. Resolve other questions with a documented assumption.

## Definition of Done

- [ ] [Checkable condition, not “works well” but “command X produces result Y”]
- [ ] Every acceptance criterion of the stories in **Delivers** is verified, cited by ID: AC-[ID]
- [ ] Tests pass
- [ ] Affected Clarity Framework documents are updated
- [ ] For UI changes, rendered visual evidence covers the changed journey, states, and target viewports

> Review each condition against the diff with concrete evidence. A condition that cannot be proven
> by a path, symbol, or command result is an assessment, not a condition. Under `unattended`, this is
> a hard requirement.

## At closeout

Answer before deleting the plan. “Nothing” is valid; no answer is not.

- [ ] Are the stories in **Delivers** set to their new status, with the traceability table in
      `docs/02-requirements.md` §5 updated to the test cases that prove them?
- [ ] Which build decisions belong in `docs/03-sad.md`?
- [ ] What belongs in `docs/08-change-management.md`?
- [ ] What was wrong with the plan? One sentence makes the next plan better.

> Delete the plan here. Without these answers, the lesson is deleted with it. The story status and
> the traceability table are the record that outlives this plan; write them back before deleting it.

---

*Clarity Framework v3.2.2 – Plan Template*
