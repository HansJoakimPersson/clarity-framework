# Run Journal: [short name]

> **Purpose:** Workflow state outside the orchestrator's context.
> **Lifetime:** Follows the plan and is deleted when the plan is deleted.
> **Location:** `docs/plans/YYYY-MM-DD-short-name.run.md`, committed with the plan.
>
> This file is the template and remains in the skill. Copy it; never edit it in place.
>
> Update it **after every step, before the next dispatch**. An orchestrator interrupted by a token
> limit, session end, or CLI switch leaves only this file behind. The next operator must be able to
> answer “where are we?” by reading it and nothing else.

| | |
| --- | --- |
| **Plan** | `docs/plans/YYYY-MM-DD-short-name.md` |
| **Branch** | `[branch-name]` |
| **Gate profile** | interactive / semi-automatic / unattended |
| **Orchestrator** | [CLI and account currently running the workflow] |
| **Raw output** | `docs/plans/.runs/YYYY-MM-DD-short-name/` (local, gitignored) |

---

## Steps

| # | Step | Status | Level — account used | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Plan | ☐ | Reasoning — `[account]` | `<plan>` |
| 2 | Review | ☐ | Review — `[account]` | `.runs/.../review.md` |
| 3 | Revision + scope gate | ☐ | Orchestrator | — |
| 4 | Build | ☐ | Implementation — `[account]` | `.runs/.../build.log` |
| 5 | Verification | ☐ | Reasoning — `[account]` | `.runs/.../verification.md` |
| 6 | Commit | ☐ | orchestrator | — |
| 7 | Merge gate | ☐ | human | — |
| 8 | Closeout | ☐ | orchestrator | — |

Status: ☐ not started · ▶ in progress · ☑ complete · ✗ stopped (see Deviations)

---

## Facts needed by the next step

| | |
| --- | --- |
| **Approved at commit** | `[SHA]` – step 5 verifies against this |
| **Build env file** | `[none / .agents/build-env.sh / .agents/build-env.local.sh / other]` |
| **Build PID / exit** | `[PID]` / `[exit code, or “running”]` |
| **Next step** | [Step number and concrete next action] |
| **Waiting for human** | [Question, or “no”] |

---

## Deviations

- [What went wrong, at which step, and what was done. Empty is valid.]
- [Record every fallback: a dispatch that ran on the logged-in account because the mapped one was
  missing, the Reasoning account standing in for Review, or an `aimux handoff`. Name the account
  that actually paid — an unrecorded fallback looks like successful account separation.]
- [Record every environment correction: env file added or changed, toolchain observed by the
  sandbox, and why it stayed within the approved runtime baseline.]

---

## Budget outcome

Record the orchestrator's own reading per step in lines. This is the only evidence that the workflow
keeps its context budget.

| Step | Artifact read | Lines | Over budget? |
| --- | --- | --- | --- |
| 1 | Plan | | |
| 2 | Review (limit 40) | | |
| 4 | Build log (limit 30, only on failure) | | |
| 5 | Verification (limit: DoD conditions + 10) | | |

> Consistent overruns mean the workflow is not saving what it claims. Tighten dispatch prompt limits;
> do not raise the ceilings.

---

*Clarity Framework – Run Journal for Plan-Driven Build*
