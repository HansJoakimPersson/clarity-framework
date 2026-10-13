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
>
> **It is state, not a log.** Keep it near 60 lines: overwrite a row when the fact changes, and put
> narrative in the commit message, not here. Write dates from `date +%F`, never from memory.
>
> **Only the orchestrator writes this file.** A build agent that changes it is overridden: the
> build dispatch protects it and restores it.

| | |
| --- | --- |
| **Plan** | `docs/plans/YYYY-MM-DD-short-name.md` |
| **Branch** | `[branch-name]` |
| **Gate profile** | interactive / semi-automatic / unattended |
| **Orchestrator** | [CLI and profile currently running the workflow] |
| **Raw output** | `docs/plans/.runs/YYYY-MM-DD-short-name/` (local, gitignored) |

Every dispatch summary should preserve the resolved `profile`, `cli`, `model`,
`reasoning_effort`, `rollout_budget`, `mode`, and `failure_class`. `model` identifies the model; `reasoning_effort`
is a separate setting and may be `profile-default`. Do not describe `medium` as a model name. When
child agents are possible, also preserve the model-evidence path and the `model_policy` result from
the compact ledger. Record `total_tokens` from each dispatch's ledger or health line; `unavailable`
means the event stream carried no usage. A routing mismatch is a stopped run, not a successful
fallback.

---

## Steps

| # | Step | Status | Level — profile used | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Plan | ☐ | Reasoning — `[profile]` | `<plan>` |
| 2 | Review | ☐ | Review — `[profile]` | `.runs/.../review.md` |
| 3 | Baseline + revision + scope gate | ☐ | Orchestrator / Reasoning — `[profile]` | `.runs/.../plan.revised.md` |
| 4 | Build | ☐ | Implementation — `[profile]` | `.runs/.../build.log`, `build.report.md` |
| 4b | Evidence: verification commands + real input | ☐ | Orchestrator | `.runs/.../evidence.md` |
| 5 | Verification | ☐ | Reasoning — `[profile]` | `.runs/.../verification.md` |
| 6 | Commit | ☐ | orchestrator | — |
| 7 | Impact gate / delegated transition | ☐ | orchestrator / human only if Escalation or Reserved | — |
| 8 | Closeout | ☐ | orchestrator | — |

Status: ☐ not started · ▶ in progress · ☑ complete · ✗ stopped (see Deviations)

---

## Facts needed by the next step

| | |
| --- | --- |
| **Baseline commit** | `[SHA]` – step 5 verifies against this |
| **Build env file** | `[none / .agents/build-env.sh / .agents/build-env.local.sh / other]` |
| **Preflight** | `[none / path / passed / blocked]` |
| **Context pack** | `[path]` / `[bytes]` / `[hash]` |
| **Implementation model / rollout budget** | `[exact model]` / `[token ceiling]` |
| **Build PID / exit** | `[PID]` / `[exit code, or “running”]` |
| **Build result** | `[failure_class]` / steps complete `[yes / no]` / `[total_tokens]` of `[ceiling]` |
| **Build round** | `[1 / 2 after budget stop — checkpoint SHA]` |
| **Baseline results** | `[label: green / n of m failing]` per Verification row marked `measure` |
| **Evidence** | `[label exit=N]` per command run in step 4b |
| **Open DoD conditions** | `[condition: not done / not in evidence / uncertain]`, or “none” |
| **Next step** | [Step number and concrete next action] |
| **Waiting for decision** | [Escalation/Reserved question, or “no”] |

---

## Project health notes

- [Each `NOTE` line from `project-health.sh` at step 0, with what was done about it. Empty is valid.]

---

## Deviations

- [What went wrong, at which step, and what was done. Empty is valid.]
- [Record every fallback: a dispatch that ran on a `cli:NAME` entry because no mapped profile
  resolved, the Reasoning profile standing in for Review, or an `aimux handoff`. Name the profile
  that actually paid — an unrecorded fallback looks like successful subscription separation.]
- [Record every environment correction: env file added or changed, toolchain observed by the
  sandbox, and why it stayed within the documented runtime baseline.]
- [Record every Step 0 prerequisite exception: which paths the working tree carried, the user's
  confirmation that they belong to other in-flight work, and that they were left untouched.]

---

## Budget outcome

Record the orchestrator's own reading per step in lines. This is the only evidence that the workflow
keeps its context budget.

| Step | Artifact read | Lines | Over budget? |
| --- | --- | --- | --- |
| 1 | Plan | | |
| 1 | Context pack (limit 64 KiB by default) | | |
| 2 | Review (limit 40) | | |
| 4 | Build log summary (limit 45) | | |
| 4b | Evidence summary lines | | |
| 5 | Verification (limit: DoD conditions + 10) | | |

> Consistent overruns mean the workflow is not saving what it claims. Tighten prompt/report limits
> or narrow context references; do not raise ceilings as the default response. The context-pack row
> measures dispatched project-document input. Implementation model and rollout-token ceiling are
> recorded above and enforced separately.

---

*Clarity Framework – Run Journal for Plan-Driven Build*
