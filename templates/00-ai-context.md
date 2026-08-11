# AI Context Document

## [Product name]

> **Purpose:** A compact project overview for a new AI session or team member.
> **Length:** One page maximum. Brevity is a quality, not a deficiency.
> **Update when:** The phase changes, an ADR is added, an NFR changes, or technical debt changes.

| | |
| --- | --- |
| **Last updated** | YYYY-MM-DD |
| **Framework version** | Clarity Framework v2.0.5 |
| **Project phase** | Initiation / Requirements / Design / Implementation / Operations |

---

## What is this?

[2–3 sentences: what the product does, which problem it solves, and for whom. An AI should gain immediate understanding without additional context.]

---

## Technical stack

| Component | Technology | Version |
| --- | --- | --- |
| Backend | [t.ex. Spring Boot] | [X.X] |
| Frontend | [t.ex. React] | [X.X] |
| Databas | [t.ex. PostgreSQL] | [X.X] |
| Hosting | [t.ex. Hetzner VPS / AWS] | — |
| CI/CD | [t.ex. GitHub Actions] | — |

---

## Architecture at a glance

[3–5 sentences about the architecture pattern, key components, and their responsibilities. Enough for an AI to make local design decisions consistent with the whole.]

---

## Key NFRs

| NFR | Requirement |
| --- | --- |
| Prestanda | [t.ex. Svarstid < 300 ms, p95] |
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

## AI workflow

[Omit this entire section if the project does not divide work among multiple agents.]

This section is the project's **runtime contract**: it states which agent fills each level, under
which account, and with which permissions. It is the single source for this information; a skill or
script can be replaced without redefining the workflow.

| Level | Agent / account | Sandbox + approval | Responsibility |
| --- | --- | --- | --- |
| Orchestrator | [e.g. Claude Code or Codex] | [e.g. allowlist in `.claude/settings.json` or a Codex orchestrator profile] | Sequences the workflow, owns gates, and maintains the run journal. Does not read the codebase or diff itself. |
| Reasoning | [e.g. Codex, account `reasoning`] | `read-only` + approval `never` | Writes the plan to `docs/plans/` and verifies the diff against it. Does not build or approve its own work. Uses a different account from the Orchestrator. |
| Review *(optional)* | [e.g. Codex, account `review`] | `read-only` + approval `never` | Reviews the plan cold against the code. Uses a different account from Reasoning. |
| Implementation | [e.g. Codex, account `implementation`] | `workspace-write` + approval `never` | Builds the approved plan. Does not re-plan; stops on a blocking question. |

> Sandbox and approval are independent settings. If only the sandbox is set, approval remains at its
> default and an unattended run may stop to ask. Always set both.

**Skill paths:** Clarity skills used by both clients are installed as identical copies under
`.agents/skills/<name>/` for Codex and `.claude/skills/<name>/` for Claude Code. Claude invokes
`/<name>`; Codex invokes `$<name>` or selects the skill through `/skills`. Internal `prompts/`
directories are resources for the skill's scripts, not client custom-prompt directories.

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

*Clarity Framework v2.0.5 – AI Context Document*
