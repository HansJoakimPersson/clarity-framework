# Plan: [short name]

> **Purpose:** Work order for an agent that did not participate in planning.
> **Lifetime:** Transient. Create, consume, and delete when the change is merged.
> **Location:** `docs/plans/YYYY-MM-DD-short-name.md`

| | |
| --- | --- |
| **Created** | YYYY-MM-DD |
| **Branch** | `[branch-name]` |
| **Status** | Draft / Approved / Building / Complete |
| **Gate profile** | interactive / semi-automatic / unattended |
| **Report budget** | Review 40 lines · Verification: one answer per DoD condition + 10 deviation lines |
| **Run journal** | `docs/plans/YYYY-MM-DD-short-name.run.md` (when an automated workflow is used) |

> **Gate profile** determines where the workflow stops for you. `interactive` stops at scope,
> commit, merge, and closeout. `semi-automatic` stops at scope and merge. `unattended` stops only
> at merge and requires every Definition of Done condition to be command-checkable. The merge gate
> exists in all three. Choose by risk, not impatience.

---

## Goal

[One sentence: what must be true when this is complete?]

## Scope

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
| `CLAUDE.md` | Project-specific deviations after the `@AGENTS.md` import, if present |
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
- [ ] Tests pass
- [ ] Affected Clarity Framework documents are updated
- [ ] For UI changes, rendered visual evidence covers the changed journey, states, and target viewports

> Review each condition against the diff with concrete evidence. A condition that cannot be proven
> by a path, symbol, or command result is an assessment, not a condition. Under `unattended`, this is
> a hard requirement.

## At closeout

Answer before deleting the plan. “Nothing” is valid; no answer is not.

- [ ] Which build decisions belong in `docs/03-sad.md`?
- [ ] What belongs in `docs/08-change-management.md`?
- [ ] What was wrong with the plan? One sentence makes the next plan better.

> Delete the plan here. Without these answers, the lesson is deleted with it.

---

*Clarity Framework v2.0.5 – Plan Template*
