# AI Context Document

## [Product name]

> **Purpose:** A compact project overview for a new AI session or team member.
> **Length:** One page maximum. Brevity is a quality, not a deficiency.
> **Update when:** The phase changes, an ADR is added, an NFR changes, or technical debt changes.

| | |
| --- | --- |
| **Last updated** | YYYY-MM-DD |
| **Framework version** | Clarity Framework v3.3.0 |
| **Project phase** | Initiation / Requirements / Design / Implementation / Operations |

---

## What is this?

[2–3 sentences: what the product does, which problem it solves, and for whom. An AI should gain immediate understanding without additional context.]

---

## Technical stack

| Component | Technology | Version |
| --- | --- | --- |
| Backend | [e.g. Spring Boot] | [X.X] |
| Frontend | [e.g. React] | [X.X] |
| Database | [e.g. PostgreSQL] | [X.X] |
| Hosting | [e.g. Hetzner VPS / AWS] | — |
| CI/CD | [e.g. GitHub Actions] | — |

---

## Architecture at a glance

[3–5 sentences about the architecture pattern, key components, and their responsibilities. Enough for an AI to make local design decisions consistent with the whole.]

---

## Key NFRs

| NFR | Requirement |
| --- | --- |
| Performance | [e.g. Response time < 300 ms, p95] |
| Availability | [e.g. 99.5% uptime] |
| Scalability | [e.g. Handle 10x data growth without redesign] |
| [Other critical NFR] | [Concrete requirement] |

---

## Current status

**Work in progress:** [What is active now, e.g. “Implementing FR-005 through FR-009”]
**Latest release:** [Version and date, or “Not released”]
**Next milestone:** [e.g. “MVP release v0.1 – target YYYY-MM-DD”]

---

## Open questions and decisions

[List unresolved architectural or product questions. This helps the AI understand uncertainty and avoid making implicit decisions.]

- [ ] [Open question 1]
- [ ] [Open question 2]

---

## Known technical debt

| ID | Description | Impact |
| --- | --- | --- |
| TD-001 | [Short description] | High / Medium / Low |

---

## Important boundaries

[What has deliberately been excluded from the product. Prevents the AI from suggesting solutions outside scope.]

- [Out-of-scope 1]
- [Out-of-scope 2]

---

## Project conventions

> Rules specific to this project that override the framework-owned `AGENTS.md`. This is the home for
> conventions with no other numbered document: everything architectural belongs in `03-sad.md`,
> operational commands in `07-runbook.md`, test rules in `06-test-documentation.md`, and visual rules
> in `09-visual-profile.md`. Never put project rules in `CLAUDE.md`; it contains only `@AGENTS.md`.
>
> Keep this list short. A convention that needs a paragraph of justification is a decision, and
> decisions belong in an ADR in `08-change-management.md`.

| Convention | Reason |
| --- | --- |
| [e.g. Use the project's package manager wrapper, never the global binary] | [Why it matters here] |
| [e.g. Never modify `legacy/`; it is replaced by FR-0XX] | [Why it matters here] |

---

## AI workflow

[Omit this entire section if the project does not divide work among multiple agents.]

This section is the project's **runtime contract**: it states which agent fills each level, under
which account, and with which permissions. It is the single source for this information; a skill or
script can be replaced without redefining the workflow.

> **The account pool column is the level-to-subscription binding** that `plan-driven-build` reads at
> step 0. Name the project's real aimux accounts here — they are subscriptions, not roles, so any
> account may fill any level, one account may fill several, and a pool (comma-separated, priority
> order) exists to spread load across interchangeable subscriptions, not to give a level its own
> identity. Changing which subscription pays for a level, or adding one to spread load further, is
> an edit to this table and nothing else. The model column is independent of the pool — it overrides
> the model for a dispatch regardless of which pool member ends up running it, which matters once a
> pool has more than one account.

| Level | Agent / account pool | Model | Sandbox + approval | Responsibility |
| --- | --- | --- | --- | --- |
| Orchestrator | [e.g. Claude Code or Codex] | — | [e.g. allowlist in `.claude/settings.json` or a Codex orchestrator profile] | Sequences the workflow, owns gates, and maintains the run journal. Does not read the codebase or diff itself. |
| Reasoning | [e.g. Codex, pool `codework1,codework2`] | [leave empty for the account's own default] | `read-only` + approval `never` | Writes the plan to `docs/plans/` and verifies the diff against it. Does not build or approve its own work. Uses a different account pool from the Orchestrator. |
| Review *(optional)* | [e.g. reuse Reasoning's pool, or its own] | [optional] | `read-only` + approval `never` | Reviews the plan cold against the code, from a different prompt file than Reasoning's. Does not need a different account — the prompt is what separates it. |
| Implementation | [e.g. Codex, pool `codework3,codework4`] | [e.g. a faster/cheaper model once scope is approved] | `workspace-write` + approval `never` | Builds the approved plan. Does not re-plan; stops on a blocking question. |

> Sandbox and approval are independent settings. If only the sandbox is set, approval remains at its
> default and an unattended run may stop to ask. Always set both.

**Skill paths:** Clarity skills used by both clients are installed as identical copies under
`.agents/skills/<name>/` for Codex and `.claude/skills/<name>/` for Claude Code. Claude invokes
`/<name>`; Codex invokes `$<name>` or selects the skill through `/skills`. Internal `prompts/`
directories are resources for the skill's scripts, not client custom-prompt directories.

**Clarity-managed setup:** written by `clarity-bootstrap` and refreshed by `framework-update`.

```text
version: [X.Y.Z]
updated: [YYYY-MM-DD]
agents-starter: [starter name without .md, or none]
skills: [comma-separated Clarity-managed skill names]
skill-paths: .agents/skills, .claude/skills
```

The `skills:` line is the ownership boundary `framework-update` reads: those names are replaced
wholesale on update, and every other skill in the runtime roots is left untouched. A skill missing
from this list is treated as project- or third-party-owned, so adding a Clarity skill later means
adding it here too.

**Build environment:** [None, or path such as `.agents/build-env.sh`. State the required local
runtime/toolchain versions and the project-owned verification that fails on the wrong one, e.g. Maven
Enforcer, package-manager `engines`, `go.mod`, or CI image. State any workspace-local dependency
cache path used by sandboxed builds, e.g. `.m2/repository`.]

**Plans:** `docs/plans/YYYY-MM-DD-short-name.md` (template: framework `templates/plan.md`). The plan
must be committed and pushed for a cloud agent to read it. Delete it when the change is merged.

**Run journal:** `docs/plans/YYYY-MM-DD-short-name.run.md` – workflow state outside the orchestrator's
context: completed step, next action, and report locations. Commit it with the plan. It enables
another session or CLI to take over an interrupted run. Raw output in `docs/plans/.runs/` is local
and gitignored.

**Orchestrator budget:** [What the orchestrator may read per round, e.g. “plan + review ≤ 40 lines +
verification ≤ DoD + 10 lines”. If it reads the codebase or diff, cost separation is illusory.]

**Always requires a human:** [e.g. scope approval, merge, release decision, plan deletion]

---

## Where is more context?

| Question | Document |
| --- | --- |
| Why is it being built? | `docs/01-vision-scope.md` |
| What is being built? | `docs/02-requirements.md` |
| What should it look like? (if UI) | `docs/09-visual-profile.md` |
| How is it built? | `docs/03-sad.md` |
| Data model and API? | `docs/04-data-model-api.md` |
| How is it deployed? | `docs/05-deployment-view.md` |
| How is it tested? | `docs/06-test-documentation.md` |
| How is it operated? | `docs/07-runbook.md` |
| What is being built now? | `docs/plans/` (when the plan-driven workflow is used) |

---

*Clarity Framework v3.3.0 – AI Context Document*
