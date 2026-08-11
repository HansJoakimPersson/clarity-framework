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

| # | Step | Status | Level / account | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Plan | ☐ | reasoning | `<plan>` |
| 2 | Review | ☐ | review / reasoning | `.runs/.../review.md` |
| 3 | Revision + scope gate | ☐ | orchestrator | — |
| 4 | Build | ☐ | implementation | `.runs/.../build.log` |
| 5 | Verification | ☐ | reasoning | `.runs/.../verification.md` |
| 6 | Commit | ☐ | orchestrator | — |
| 7 | Merge gate | ☐ | human | — |
| 8 | Closeout | ☐ | orchestrator | — |

Status: ☐ not started · ▶ in progress · ☑ complete · ✗ stopped (see Deviations)

---

## Facts needed by the next step

| | |
| --- | --- |
| **Approved at commit** | `[SHA]` – step 5 verifies against this |
| **Build PID / exit** | `[PID]` / `[exit code, or “running”]` |
| **Next step** | [Step number and concrete next action] |
| **Waiting for human** | [Question, or “no”] |

---

## Deviations

- [What went wrong, at which step, and what was done. Empty is valid.]
- [Record every fallback: `codex exec` without an account, `reasoning` instead of `review`, or an
  `aimux handoff`. An unrecorded fallback looks like successful account separation.]

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
