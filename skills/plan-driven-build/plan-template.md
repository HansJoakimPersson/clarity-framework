# Plan: [short name]

> **Purpose:** Work order for an agent that did not participate in planning.
> **Lifetime:** Transient. Create, consume, and delete when the change is merged.
> **Location:** `docs/plans/YYYY-MM-DD-short-name.md`
>
> Lines that start with `>` are guidance for whoever writes the plan. They are not part of a
> finished plan: leave them out, so the reader gets the work order and not the template.

| | |
| --- | --- |
| **Created** | YYYY-MM-DD |
| **Branch** | `[branch-name]` |
| **Delivers** | FR-[ID], FR-[ID] — or `None – maintenance: [reason]` |
| **Milestone** | [Milestone this increment moves toward, from `docs/00-ai-context.md`] |
| **Track** | product *(default)* / research |
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
> closeout. Cite an ID only when this increment delivers that story's acceptance criteria.
> `None – maintenance: [reason]` is for work that changes no behavior a user can observe:
> refactoring, infrastructure, tooling, dependency and test maintenance. New or changed observable
> behavior with no covering requirement is not maintenance — it is an **ESCALATION**: the
> requirement is written first, or the deviation is recorded as a decision before the plan is
> approved. A project once shipped six plans in a row as `None`, about 1 800 lines of product code
> in an area its vision calls secondary, while two Must requirements stood untouched.
>
> **Milestone** ties the increment to where the project is going. A plan that cannot name the
> milestone it serves is an **ESCALATION**, not a formality to fill in: forty-six individually
> reasonable plans took one project away from its main chain without any of them being wrong.
>
> **Track** separates product work from experiments. A `research` plan writes only inside the one
> directory it names under **Included**; it adds no types, schemas, commands, or tests to product
> modules, and its output is not a contract. A research result enters the product through a change
> to vision and scope and a `product` plan — never because the code happens to be there.

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
> within 200 lines, the plan is too large. So is an increment that creates or changes more than
> about 12 files or needs more than 8 steps: one build dispatch will not finish it. Steps going
> vague to fit is the symptom, not the workaround. Split by increment, not by layer — the rule that
> governs splitting a story governs splitting a plan. Below the other end, a change too small to
> justify separate planning, review, implementation, and verification does not need a plan at all;
> orchestration overhead costs more than the change.

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
> Runtime instructions are already injected, so do not list `AGENTS.md` or `CLAUDE.md`. Use the
> file names the project actually has; `docs/00-ai-context.md` § Where is more context? maps the
> framework's canonical names to them. Cite `path` for a small whole file or `path#heading text`
> for one section — the heading as written, without backticks even when the heading has them; an
> ID in the heading (`#FR-017`, `#ADR-012`) is enough. Whole files over 24 KiB, directories, and
> anything under `docs/archive/` are rejected automatically.

| Reference | Why |
| --- | --- |
| `docs/00-ai-context.md` | Compact project orientation, runtime/authority contract, and active state |
| `docs/02-requirements.md#FR-[ID]` | Acceptance criteria for the story in **Delivers** |
| `docs/03-sad.md#ADR-[ID]` | Architectural decision governing this change |
| `docs/04-data-model-api.md#[heading text]` | Only the affected data/API contract section |
| `docs/09-visual-profile.md#[heading text]` | Only the visual rules the change actually touches |

## Steps

> **A step's Verification line is run by the build agent inside its sandbox.** Write there only
> what that sandbox can run; everything else belongs in the Verification table below with the owner
> `Orchestrator`.
>
> **Prefer a subshell — `(cd dir && cmd)` — over chaining a relative `cd`.** A failed middle
> command leaves the shell in the wrong directory and the next command reports a false failure.
>
> **In a whole-module compilation language, order steps so each one compiles standalone:** the
> production symbol comes before, or in the same step as, the test that references it.
>
> **A schema-wide directive ("to every X") names every affected table or entity and the ones it
> excludes.** A count drifts silently when the schema is edited later.

1. **[What]** in `path/to/file.ext`
   [Concrete description, sufficient to build without guessing]
   Verification: `[command]`

2. **[What]** in `path/to/file.ext`
   [...]
   Verification: `[command]`

## Verification

> **Who runs what.** The build agent's sandbox cannot launch a browser, Electron, or any GUI
> process, cannot run suites that need many file watchers or sockets, and cannot reach services
> outside the workspace. Such commands get the owner `Orchestrator`: the orchestrator runs them
> outside the sandbox and records the result as evidence for the verifier. Never ask for the
> sandbox to be removed instead, and never leave such a command in a step's Verification line —
> build agents have spent an entire budget debugging a sandbox limit after the code was correct.
>
> **Baseline.** A command that exercises tests which already exist is measured on the baseline
> commit before the plan is approved; the result goes in the Baseline column (`green`, or for
> example `18 of 24 failing — evidence: baseline-e2e`). `new` means the command only covers what
> this plan adds. A plan once required a suite to "exit 0" that was already failing 18 of 24 on
> `main`; nobody who reads code without running it can know that.

| Command | Owner | Baseline |
| --- | --- | --- |
| `[sandbox-safe gate, e.g. unit tests + static analysis]` | Implementation | [green / measure / new] |
| `[browser, GUI, watcher-heavy, or external command]` | Orchestrator | [green / measure / new] |

## Real input for self-check

> Required when the change parses, imports, extracts from, or transforms input that comes from
> outside the project; otherwise write "Not applicable". Synthetic fixtures prove the mechanism,
> not the result: one fix took five build rounds because each round passed its fixture and then
> met a line pattern only the real document had. Name a local, non-versioned copy of real input
> and the properties the result must have, so the build agent can check itself before it stops.

| Real input (local, not versioned) | Expected properties of the result |
| --- | --- |
| `[path under a gitignored directory]` | [e.g. 14 chapters, no empty titles, every section has a parent] |

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
- [ ] The new tests pass, and each command in **Verification** reports no failure that its baseline does not
- [ ] For input from outside the project: run against at least one real source, with the result described
- [ ] Affected Clarity Framework documents are updated in the sections they belong to
- [ ] For UI changes, rendered visual evidence covers the changed journey, states, and target viewports

> Review each condition against the diff with concrete evidence. A condition that cannot be proven
> by a path, symbol, or command result is an assessment, not a condition. Under `unattended`, this is
> a hard requirement. A condition that needs a command result is proven by a recorded run of that
> command, not by the presence of the test.
>
> A condition that checks an **Excluded** boundary held must scan the whole diff or package against
> it, not a single named file or class — a check scoped to one file has repeatedly reported
> "excluded surfaces untouched" while the same change touched other excluded files elsewhere.

## Follow-up rounds

> Empty in a new plan. When a build round does not meet the Definition of Done, record what was
> seen here — as cases, not as rules. Whoever adds a round without having read the code states
> input, what happened, and what should have happened; the rule that follows from the cases is for
> the planner to derive from the code. A rule written in from outside, "a continuation line always
> belongs to the most recently opened node", was too absolute and cost a full build round.

| Round | Reproduction (input or command) | Observed | Expected |
| --- | --- | --- | --- |
| | | | |

## At closeout

Answer before deleting the plan. “Nothing” is valid; no answer is not.

- [ ] Are the stories in **Delivers** set to their new status, with the traceability table in the
      requirements document (§5) updated to the test cases that prove them? Use `Done` only for a
      story run on real input with a recorded result; otherwise it is `Built`.
- [ ] Does `Current status` in `docs/00-ai-context.md` still describe the project? Change it, or
      state that it was checked and is unchanged.
- [ ] Which build decisions belong in the architecture document (`docs/03-sad.md`)?
- [ ] What belongs in change management (`docs/08-change-management.md`)?
- [ ] Has the requirements document's story backlog (§2.6) passed roughly 20 active stories without
      being split into a separate user-stories document? A backlog left unsplit past that threshold
      degrades from a document into an unreadable log.
- [ ] For a `research` plan: is the result recorded, and is anything worth keeping proposed as a
      change to vision and scope rather than left in place as product code?
- [ ] What was wrong with the plan? One sentence makes the next plan better.

> Delete the plan here. Without these answers, the lesson is deleted with it. The story status and
> the traceability table are the record that outlives this plan; write them back before deleting it.

---

*Clarity Framework v4.6.0 – Plan Template*
