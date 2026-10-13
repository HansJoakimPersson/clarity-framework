---
name: plan-driven-build
description: Use when a task is large enough to benefit from bounded multi-agent planning, critique, implementation, and verification, and a second AI CLI is available via aimux for dispatch.
---

# Plan-Driven Build (plan-driven-build)

You are the **orchestrator**. You sequence the flow, exercise the project's delegated authority,
hold only material impact gates, and dispatch the thinking and building elsewhere. You write no production code and you never read the codebase or the
full diff — you read bounded distillates produced by agents that did that reading for you.

| Level | Does | Must not |
| --- | --- | --- |
| **Orchestrator** (you) | Sequences, holds gates, writes the run journal, runs the verification commands and the product itself and records the result as evidence | Read code or diffs, write production code |
| **Reasoning** | Drafts and revises the plan (steps 1 and 3), verifies the diff against it (step 5) | Change documented project intent or cross an authority boundary |
| **Implementation** | Builds an approved plan (step 4) | Change Goal/Included/Excluded, requirements, or architectural boundaries; write the plan, the journal, or run state; may resolve local reversible plan gaps |

Reasoning and Implementation must run under **a different aimux profile than you**. That is the
point of the workflow: not context isolation, but moving token spend off the metered interactive
session. A Claude subagent shares your account and does not achieve this. A profile pool may be one
profile or a prioritized list of interchangeable ones — see Step 0. Review does not need a different
profile from Reasoning; what keeps it from repeating Reasoning's blind spots is a different prompt
file, not a different subscription.

Setup — aimux profiles, sandbox and approval flags, permission allowlist — is in `setup.md`.
Read it only if a prerequisite check fails.

## The budget (the hard rule)

Everything below exists to keep **your** context small. Per round you may read:

| Artifact | Ceiling |
| --- | --- |
| `docs/00-ai-context.md` | 1 page, once |
| Context pack | Generated mechanically; do not read unless diagnosing a pack failure |
| The plan | Once, after step 1 |
| Critique report | 40 lines |
| Build log | `tail -45`: the summary the supervisor appends when the build ends |
| Event stream | `dispatch-tail.sh --events FILE --lines 15`, only on failure |
| Evidence file | The `EVIDENCE` summary lines; one entry's tail when a command failed |
| Verification report | One line per Definition of Done condition + 10 lines of deviations |
| Run journal | ~30 lines, on resume |

If the plan sets a `Report budget` other than the default, pass it to `--max-lines` instead.

That is the **orchestrator reading budget**. Dispatched agents have a separate **context budget**:
review, implementation, and verification receive one frozen pack built from the plan's exact
`path#heading` references, capped by default at 64 KiB; they do not independently wander through
`docs/`. Implementation also has an **execution budget**: its model must be pinned explicitly and
`dispatch.sh` must receive a positive `--max-rollout-tokens` value. Output, context, and execution
budgets are distinct controls.

You may **not** read: `git diff`, source files, the full build log, the prompt files, or a report
that exceeds its budget — truncate it and say you did. If you find yourself reading the codebase
"to be sure", the workflow has already failed; say so rather than continue.

**Running is not reading.** The ban covers source and diffs. It does not cover executing the
project: you run the plan's Orchestrator-owned verification commands, and the product itself on
real input, and you look at what comes out. That is the one thing no read-only agent can do for
you, and three projects reached "Done" on fixtures while the real input still failed. Keep the
output out of your context with `evidence.sh` (step 4b); read its summary line, not the log.

A dispatch's stdout is a JSONL event stream, not prose. Never `tail` or `grep` a `*.events.jsonl`
or `*.raw.log` file; `dispatch-tail.sh` prints the same information as one bounded line per event.

## Shell rules for the commands below

The snippets run unchanged in `sh`, `bash`, and `zsh`. When you adapt one, keep three habits —
each has cost a real run a failed command:

- **Optional arguments go through `set --` and `"$@"`**, never through an unquoted string
  variable. zsh does not split `$model_args` into words, so the whole string arrives as one
  argument.
- **Write `${VAR}` when a colon follows**: `"${TAG}:path"`. In zsh `"$TAG:path"` applies `:p` as
  a modifier and silently produces a different string.
- **Dates come from `$(date +%F)`**, never from memory. A journal has been written with a date
  two years off, which then made every age check wrong.

Each snippet assumes the variables from step 0 are set in the same shell. If your harness starts
a fresh shell per command, keep the assignments in `$RUN/vars.sh` and begin each command with
`. "$RUN/vars.sh"`.

## Execution safety contract

Every dispatch has a bounded execution contract. The lifecycle is:

```text
preflight -> planning -> implementation -> verification -> review -> finalization
```

Use the phase that matches the dispatch and record its status in the journal. The shared failure
classes are `environment`, `environment.rate_limit`, `environment.preflight`,
`environment.sandbox-nested`, `configuration`, `model-routing`, `timeout`, `timeout.stalled`,
`timeout.wall`, `budget`, `verification`, `implementation`, `plan`, and `unknown`; a failure is
retryable only when the dispatch evidence says it is. Rate limits,
temporary service unavailability, and timeouts may be retryable. Runtime, repository, model-routing,
verification, and plan failures are not automatically retryable.

`dispatch.sh` runs a Git and index-lock preflight for every invocation. Add a project-owned,
read-only check when a runtime or service is required:

```bash
"$SKILLDIR/dispatch.sh" --profile "$PROFILE_REASONING" --mode read-only \
  --preflight .agents/preflight.sh --job-id "${ID}-plan" \
  --prompt-file "$SKILLDIR/prompts/1-plan.txt" \
  --var TASK="<outcome>" --var PLAN_TEMPLATE="$SKILLDIR/plan-template.md" \
  --var PLAN="$PLAN" --var BRANCH="$BRANCH" \
  --var DATE="$(date +%F)" --out "$PLAN" --max-lines 220
```

A failed preflight stops before the agent runs and is never sent through the read-only retry pool.
The preflight script must not repair the environment or modify application files. A preflight that
only checks that a directory exists proves nothing: have it run the build tool once
(`mvn -q -version`, `npm --version`, `go version`) under the same env file the build will get, so a
broken toolchain path fails here in a second instead of inside a build that spends its budget on it.

Every dispatch runs with **stdin closed** and under a watchdog. A foreground dispatch that produces
no output for 15 minutes, or runs longer than an hour, is terminated with exit `124` and
`failure_class=timeout.stalled` or `timeout.wall` and, for a read-only level, retried on the next
profile in the pool; change the ceilings with `--stall-timeout-seconds` and
`--wall-timeout-seconds`. You never need to wrap a dispatch in your own timeout or redirect.

`environment.sandbox-nested` means the dispatched CLI could not start its own sandbox because the
orchestrator's shell is itself sandboxed (`operation not permitted` before the first event). No
profile change fixes that: run the dispatch from an unsandboxed shell, as `setup.md` describes.

When a dispatch creates or may create child agents, pass the requested model to both aimux and the
underlying CLI (the dispatcher does this for Codex), and supply model evidence after the run. The
file contains one observed parent or child model per non-empty line:

```bash
--model "$MODEL_IMPLEMENTATION" \
--model-evidence "$RUN/implementation.models" \
--ledger "$RUN/implementation.ledger"
```

Any observed model different from the effective model fails closed with `failure_class=model-routing`.
An explicit model handoff must be documented in the journal before it is accepted. A compact ledger
is written automatically unless `--ledger` overrides its path. It records the job, phase, profile,
requested and effective model, reasoning effort, rollout-budget ceiling, attempt count,
retryability, failure class, model policy, exit status, and token usage. Raw output remains a
debugging artifact, not the primary run record.

**Where a dispatch puts its files.** `--out` receives the report and nothing else. Events, stderr,
and the ledger of a foreground dispatch go to a run directory: beside `--out` when that is already
under `.runs/`, otherwise `<out directory>/.runs/<out name>/`, so a plan written to `docs/plans/`
never gets raw attempt files next to it. `--artifacts-dir DIR` overrides the location. A background
dispatch writes beside `--log`: `<name>.exit` (sentinel), `<name>.health`, `<name>.events.jsonl`,
`<name>.report.md` (the build agent's own report), `<name>.final.md` (its last message), and
`<name>.ledger.tsv`. A second dispatch to the same `--log` archives the earlier attempt's files to
`attempts/<name>-N/` first, so a retry never overwrites the failure it follows.

**Token figures.** Usage is read from the event stream: per-turn `turn.completed` usage summed, or
the last cumulative token count when a run dies before a turn completes — the budget stop being
exactly that case. `total_tokens` in the ledger and health file is input plus output, and input
includes cached input. The rollout budget is enforced by the CLI on its own count, which need not
equal that sum, so compare a run to its ceiling by `failure_class=budget`, not by arithmetic.
`unavailable` means the stream carried no usage at all; `CF_INPUT_TOKENS`, `CF_OUTPUT_TOKENS`, and
`CF_TOTAL_TOKENS` are then copied if the runtime exports them. Record the figure in the journal
after each dispatch — an unmeasured budget is how one project raised its ceiling four times on
experience instead of data.

Retries are bounded by the remaining read-only profile pool and may be further limited with
`--max-retries N`. Workspace-write and background dispatches never retry automatically after launch.
Stop and record the next action when preflight, routing, environment, verification, budget, or
repository safety fails.

## Optional discipline hooks

The five discipline skills remain independently installable, but `plan-driven-build` invokes them
when their trigger is present. Their contracts keep the workflow modular:

| Event | Skill | Required result |
| --- | --- | --- |
| Bug, build failure, test failure, or unexpected behavior | `systematic-debugging` | Root cause, failure class, retryability, next action |
| Verification or completion claim | `verification-before-completion` | Evidence and result for every condition |
| External review requested | `requesting-code-review` | Review package and bounded request |
| Review findings received | `receiving-code-review` | Disposition and evidence for every finding |
| Branch or plan work is complete | `finishing-a-development-branch` | Closeout options and merge/cleanup evidence |

If a hooked skill is not installed, follow the equivalent guardrail in this workflow and record the
missing module in the journal. A hook is conditional: a successful implementation does not invoke
debugging, and a run with no external review does not invoke the review-request or review-reception
skills. The orchestrator still owns phase order, dispatch, journal state, model policy, and human
gates.

## Authority and gate profiles

The plan's `Gate profile` field controls how much routine execution is surfaced, but **authority
comes first**. Classify decisions as Delegated, Escalation, or Reserved from
`docs/00-ai-context.md`.

When `docs/plans/.runs/project-driver-mission/active.tsv` reports an active mission, that mandate
takes precedence over gate-profile pauses. Delegated work cannot be converted into a human approval
checkpoint by `interactive`, and an Escalation returns to the outer project-driver orchestrator for
resolution rather than directly to the user. Only a Reserved action with an issued `HUMAN_GATE`
may become a user-facing question.

| Profile | Behavior |
| --- | --- |
| `semi-automatic` *(default)* | Execute Delegated work end-to-end; surface meaningful assumptions in the report; stop only for Escalation/Reserved decisions |
| `interactive` | For standalone runs, pause before committing or externally integrating when explicitly chosen. An active project-driver mission suppresses these routine pauses; its reserved-only human-gate policy wins. |
| `unattended` | Execute every Delegated transition, including commits, temporary worktrees/branches, and internal integration; notify only on completion, failure, or Escalation/Reserved decisions |

Scope decomposition is Delegated when it is derived from already-documented project intent and does
not materially alter it. Commits and merges from an orchestrator-created worktree back into the
work branch are Delegated. A push to a shared branch, release, production deployment, or other
externally visible transition is gated only when the project's authority contract reserves it.

Choose `interactive` for deliberately supervised work, not because the framework is uncertain about
normal implementation detail.

## Prerequisites

Check, and if anything is missing: report it and stop.

- `command -v codex`, `command -v aimux`, and `AGENTS.md` in the project root. **This workflow
  needs a second CLI**: the orchestrator dispatches to it, so a project with only one AI CLI
  installed cannot run it. `codex` is the only dispatch adapter implemented; adding another
  (gemini, claude, opencode) is a one-function framework change to `dispatch.sh`, not a project
  setting.
- This skill exists at `.agents/skills/plan-driven-build/` or `.claude/skills/plan-driven-build/`.
  Install it in both locations when both Codex and Claude Code are used. The copies must be identical.
- Prefer a clean owning branch. For a standalone run, a dirty target tree is still a material
  repository-safety condition: report it rather than silently mixing work. Under an active
  project-driver mission, **do not ask the user merely because the current tree is dirty**. Preserve
  the dirty tree untouched and use an orchestrator-created clean worktree from the documented owning
  branch when the increment can be isolated safely. If required work depends on uncommitted content
  that is absent from the documented baseline and cannot be isolated without risking loss, return a
  repository-safety blocker to project-driver; it is not permission to stash, reset, overwrite, or
  ask a routine continuation question.
- `docs/00-ai-context.md` names an aimux profile pool for each level — one profile or several,
  comma-separated, tried in priority order. `aimux profile list` (or `~/.aimux/config.yaml`) shows
  the profiles that exist. **A profile selects its CLI, authentication and paying subscription; its stored model is only a
  default for levels that do not pin one — it is not a role**: the same profile may fill several levels or appear in several pools, and Review does not
  need a pool distinct from Reasoning's. Step 0 verifies the mapping; without it cost is not
  separated, only context. When a pool entry is missing from `~/.aimux/config.yaml`, `dispatch.sh`
  prints a `FALLBACK:` line — pass it on to the user and record it in the journal rather than
  letting it scroll past.

Templates: `plan-template.md` and `journal-template.md` in this skill's directory. Copy them, never edit them in
place. Do not look for `templates/` — that path exists in the framework repo, not in projects.

## Step 0 — Open the run journal

Set the identifiers once and reuse them:

```bash
ID=YYYY-MM-DD-short-name
if [ -f .agents/skills/plan-driven-build/SKILL.md ]; then
  SKILLDIR=.agents/skills/plan-driven-build
elif [ -f .claude/skills/plan-driven-build/SKILL.md ]; then
  SKILLDIR=.claude/skills/plan-driven-build
else
  printf '%s\n' 'plan-driven-build is not installed for Codex or Claude Code' >&2
  exit 2
fi
PLAN="docs/plans/${ID}.md"
JOURNAL="docs/plans/${ID}.run.md"
RUN="docs/plans/.runs/${ID}"
CONTEXT_PACK="$RUN/context.md"
EVIDENCE="$RUN/evidence.md"
BRANCH=$(git rev-parse --abbrev-ref HEAD)
MAX_CONTEXT_PACK_BYTES=65536
MAX_CONTEXT_FILE_BYTES=24576
mkdir -p "$RUN" && cp "$SKILLDIR/journal-template.md" "$JOURNAL"
sh "$SKILLDIR/project-health.sh"
```

`ID` starts with today's date from `date +%F`. `project-health.sh` prints one `NOTE` line per rule
the project has drifted from — plans that outlived their change, an AI Context that became a log,
modified files left uncommitted for days, a run of plans that deliver no requirement, runtime
copies of a skill that differ, a repository inside a cloud-synced folder. It never blocks. Copy the
`NOTE` lines into the journal and act on the ones that bear on this run before step 1:

- **`worktree`** — tracked files modified more than a day ago are someone's unfinished work, not
  background noise. Do not plan on top of them: get them committed or discarded first, or build in
  a clean worktree. One project carried 47 uncommitted files for five days as its only copy.
- **`plans`** — close out a stale plan before opening another; a transient plan that stays is a
  second, wrong source of truth.
- **`delivers`** — surface it. Three maintenance plans in a row is the signal that product work is
  happening outside the requirements; see step 1 on `Delivers`.
- **`location`** — a cloud-synced repository produces conflict copies such as `SKILL 2.md` while
  agents write. Build in a git worktree outside the synced root.

Then bind each level to a profile pool. **The profile names are the project's own aimux
profiles** — read them from the runtime contract in `docs/00-ai-context.md` and set them here.
They are not role names, a pool is one profile or several comma-separated ones tried in priority
order, and the skill has no defaults to fall back on:

```bash
PROFILE_REASONING=<profile pool from docs/00-ai-context.md, e.g. codework1,codework2>
PROFILE_IMPLEMENTATION=<profile pool from docs/00-ai-context.md>
PROFILE_REVIEW=<profile pool from docs/00-ai-context.md, or reuse $PROFILE_REASONING>
MODEL_REASONING=          # from docs/00-ai-context.md; may be empty to use the profile default
MODEL_IMPLEMENTATION=     # REQUIRED: exact model from docs/00-ai-context.md, e.g. gpt-5.6-luna
MAX_ROLLOUT_TOKENS_IMPLEMENTATION= # REQUIRED: positive execution ceiling from docs/00-ai-context.md
REASONING_EFFORT_REASONING=      # optional: none, low, medium, high, or xhigh
REASONING_EFFORT_IMPLEMENTATION= # optional: none, low, medium, high, or xhigh

aimux_config="${AIMUX_CONFIG:-$HOME/.aimux/config.yaml}"
for pool in "$PROFILE_REASONING" "$PROFILE_IMPLEMENTATION" "$PROFILE_REVIEW"; do
  found=0
  for p in $(printf '%s' "$pool" | tr ',' ' '); do
    case "$p" in cli:*) found=1; continue ;; esac
    grep -qE "^  ${p}:[[:space:]]*\$" "$aimux_config" && { printf 'ok       %s\n' "$p"; found=1; }
  done
  [ "$found" -eq 1 ] || printf 'MISSING  %s\n' "$pool"
done
```

A `MISSING` line means every profile in that pool is absent from `~/.aimux/config.yaml`, so the
dispatch will fail unless the pool ends in a `cli:NAME` fallback entry — fix the pool in
`docs/00-ai-context.md`, or run `aimux profile add <name> --cli <cli>`. `dispatch.sh` re-checks
this per dispatch and, when no entry resolves, lists the profiles that do exist — but catch it here
before the run starts. A pool is written as profile names or `cli:NAME`; a bare CLI name such as
`codex` is read as a profile name. Which subscriptions fill which level,
and in what order, is the project's decision: one profile may fill several levels, any profile may
fill any level, and a pool exists to spread load across interchangeable subscriptions — not to give
a level its own identity. For Implementation, the profile answers **who pays**; the explicit
`MODEL_IMPLEMENTATION` and rollout budget answer **what may run and how much it may consume**.
Review does not need to differ from Reasoning's pool; the prompt file is
what keeps a review from sharing the drafting level's blind spots, not the profile.

Every dispatch goes through `$SKILLDIR/dispatch.sh`, which takes its instructions from
`$SKILLDIR/prompts/`. **Do not read the prompt files** — keeping roughly a thousand words of
instruction text out of your context is the point of them living in files. You fill their
placeholders with `--var` and never see the rest.

The script also sets sandbox and approval policy together, reports a fallback when a profile in the
pool cannot be resolved and a later entry or a `cli:NAME` fallback runs instead, and prints the
report's line count against its budget so you know whether a report fits before opening it. Calling
`codex` directly loses all three.

The journal is committed; `docs/plans/.runs/` is local scratch and belongs in `.gitignore`.

**Update the journal after every step, before the next dispatch.** It is the only place the flow's
state exists — your context is not state, it disappears at a usage limit or a session boundary. A
correctly kept journal means any CLI, including another one under another profile, can answer
"where are we?" by reading ~30 lines and continue from there.

## Step 1 — Dispatch the plan

Do not read the project's documents or code beyond what you need to state the task. Let Reasoning
read what it needs — that is the context you are not paying for twice.

```bash
set --
[ -n "${MODEL_REASONING:-}" ] && set -- "$@" --model "$MODEL_REASONING"
[ -n "${REASONING_EFFORT_REASONING:-}" ] && set -- "$@" --reasoning-effort "$REASONING_EFFORT_REASONING"

"$SKILLDIR/dispatch.sh" --profile "$PROFILE_REASONING" "$@" --mode read-only \
  --phase planning \
  --prompt-file "$SKILLDIR/prompts/1-plan.txt" \
  --var TASK="<one or two sentences: what should be true when this is done>" \
  --var PLAN_TEMPLATE="$SKILLDIR/plan-template.md" \
  --var PLAN="$PLAN" --var BRANCH="$BRANCH" \
  --var DATE="$(date +%F)" \
  --out "$PLAN" --max-lines 220
```

`TASK` is the only thing you contribute here, so make it carry the intent — the plan is only as good
as this sentence. Build nothing in this step.

**State the requirement and the milestone in `TASK` when you know them.** The plan's `Delivers`
and `Milestone` fields are how an increment stays tied to where the project is going. `Delivers:
None – maintenance` is for work with no behavior a user can observe. If the plan comes back `None`
for work that adds or changes observable behavior, or cannot name a milestone, that is an
**Escalation**, not a field to accept: write the requirement first, or record the deviation as a
decision. Use `Track: research` for an experiment; it confines the work to one directory and keeps
its output out of the product's contracts.

**Size.** A plan that creates or changes more than about 12 files or needs more than 8 steps will
not finish in one build dispatch. Split it now — two plans that each merge cost less than one build
that stops at 80 % with an empty report.

Immediately compile the plan's document references into the bounded context pack:

```bash
sh "$SKILLDIR/context-pack.sh" --plan "$PLAN" --out "$CONTEXT_PACK" \
  --max-bytes "$MAX_CONTEXT_PACK_BYTES" \
  --max-file-bytes "$MAX_CONTEXT_FILE_BYTES"
```

A pack failure is a planning defect, not permission to raise the ceiling. Narrow an oversized
whole-file reference to an exact heading, remove irrelevant context, or split the increment. A
heading reference matches the heading text as written, without backticks, or any unique part of
it; an ID is enough (`#FR-017`). Record
the resulting byte count and `git hash-object "$CONTEXT_PACK"` in the journal. The pack is local run state under `.runs/`; it is not
committed and is never a new source of truth.

When `TASK` fixes a defect, leak, or regression suspected to recur across a family of similar units
(test classes, endpoints, migrations, and the like), run or dispatch a full diagnostic sweep of that
family before writing `TASK`, so the plan's scope covers every affected instance up front. A `TASK`
that only names the first instance found produces a plan that only fixes that instance — a real
project needed five separate build-and-reverify rounds to work through five sibling classes because
each round only surfaced the next one, when a single upfront sweep would have shown all five at once.

## Step 2 — Dispatch a critique of the plan

A fresh, stateless invocation reading the plan cold against the code, under a different prompt file
from the one that drafted it. `prompts/2-review.txt` is what keeps this from repeating step 1's
blind spots — `$PROFILE_REVIEW` may be the same pool as `$PROFILE_REASONING`, nothing here requires
the profile to differ. Listing `$PROFILE_REASONING` after `$PROFILE_REVIEW` in `--profile` still
protects against `$PROFILE_REVIEW` being unresolved at runtime; if that fallback fires, it is
recorded on stdout and belongs in the journal.

```bash
set --
[ -n "${MODEL_REASONING:-}" ] && set -- "$@" --model "$MODEL_REASONING"
[ -n "${REASONING_EFFORT_REASONING:-}" ] && set -- "$@" --reasoning-effort "$REASONING_EFFORT_REASONING"

"$SKILLDIR/dispatch.sh" --profile "${PROFILE_REVIEW},${PROFILE_REASONING}" "$@" --mode read-only \
  --phase review \
  --prompt-file "$SKILLDIR/prompts/2-review.txt" \
  --var PLAN="$PLAN" --var CONTEXT_PACK="$CONTEXT_PACK" \
  --out "$RUN/review.md" --max-lines 40
```

The command prints `budget=within budget (n/40)` or `OVER BUDGET`. If it is over, read the first 40
lines only and note the truncation in the journal.

## Step 3 — Measure the baseline, revise, and classify decisions

### 3a — Measure what the plan claims about today

Every row of the plan's **Verification** table whose Baseline says `measure` is run now, on the
commit the build will start from, before anything is approved:

```bash
sh "$SKILLDIR/evidence.sh" --out "$EVIDENCE" --label baseline-e2e \
  --timeout-seconds 1800 --cmd '<the command from the Verification table>'
```

Add `--env-file .agents/build-env.sh` when the project has one. The script prints one `EVIDENCE`
line with the exit code and keeps the output in `$RUN/evidence/`. Write the result into the plan's
Baseline column (`green`, or `18 of 24 failing — evidence: baseline-e2e`) and make the Definition
of Done relative to it. A plan that demands "exits 0" from a suite that is already red on the
baseline cannot be met by a correct build, and neither the planner nor the reviewer can see that:
they read code, they do not run it.

A command that cannot run here cannot run for the verifier either. Fix the command, or the
environment, before approving the plan.

### 3b — Revise

Review objections that turn on the code — a parser rule, an invariant, a data shape — go back to
the planner, who has read the code. You have not, and a rule you write in from outside is a guess:
one such rule ("a continuation line always belongs to the most recently opened node") was too
absolute and cost a full build round. Marked **SPEC** in the review, they are revised by dispatch:

```bash
set --
[ -n "${MODEL_REASONING:-}" ] && set -- "$@" --model "$MODEL_REASONING"
[ -n "${REASONING_EFFORT_REASONING:-}" ] && set -- "$@" --reasoning-effort "$REASONING_EFFORT_REASONING"

"$SKILLDIR/dispatch.sh" --profile "$PROFILE_REASONING" "$@" --mode read-only \
  --phase planning \
  --prompt-file "$SKILLDIR/prompts/3-revise.txt" \
  --var PLAN="$PLAN" --var REVIEW="$RUN/review.md" \
  --var NOTES="<which objections you accept, which you dismiss and why; measured baselines>" \
  --var PLAN_TEMPLATE="$SKILLDIR/plan-template.md" \
  --out "$RUN/plan.revised.md" --max-lines 220
```

On exit 0, replace the plan with the revision (`cp "$RUN/plan.revised.md" "$PLAN"`). What you may
write into the plan yourself is bounded: header fields, measured baselines, a resolved open
question, wording — and, under **Follow-up rounds**, what you observed as a case: input, what
happened, what should have happened. Never a rule about how the code must behave. Briefly justify
the objections you dismiss; silent dismissal hides that the review happened.

**Re-review when the revision changed behavior.** A revision that alters a step's description, the
Verification table, or the Definition of Done is a new plan for the purposes of step 2: run the
review once more against it. A revision that only tightens wording or fills a baseline is not.
Stop after two revision rounds; a plan that still draws substantive objections is too large or
rests on an unresolved decision — split it or escalate.

### 3c — Scan and classify

Before presenting it, scan the plan itself once more: placeholders ("TBD", "handle appropriately",
a step with no file path or verification command), tasks that contradict each other or the stated
`Excluded` list, requirements a reader could take two ways, a step whose Verification line needs a
browser or GUI process instead of an Orchestrator-owned row, and a change that handles outside
input with no **Real input for self-check**. This is a bounded read of the plan
you already hold, not the source-diff reading the budget forbids. Fix what you can inline; classify anything you cannot resolve as Escalation or Reserved rather
than using uncertainty itself as a blocker.

Record the goal, `Included` / `Excluded`, material assumptions, and what the review changed in the
journal. Present them to the user only when an impact-gate decision actually requires input or when
the selected supervision profile calls for an informational checkpoint.

Classify every open question. Resolve Delegated questions from repository evidence, documented
intent, and the least-consequential reversible assumption; write that assumption into the plan and
continue. Stop only for Escalation or Reserved questions.

When the plan is a decomposition of the documented project-intent baseline, set `Status: Approved`
once its review objections are resolved — the status means executable under the authority contract,
not that another human checkpoint occurred. If the plan materially changes intent, present that delta
as the single Escalation decision and stop for it.

If revision changed any `Context to read first` reference, rebuild `$CONTEXT_PACK` now with the same
limits. From this point through verification the pack is frozen. Document changes produced by the
build are outputs visible in the diff, not an excuse to silently expand the run's input context.

## Step 4 — Dispatch the build

Commit the plan and journal first, so it is visible which version was built. Record the commit SHA
in the journal — step 5 diffs against it.

Run in the background with a sentinel, never in the foreground: a build routinely exceeds the
foreground timeout and a killed process leaves half the change on disk.
`dispatch.sh --background` detaches the child with `nohup`; a log that remains empty and has no
sentinel after the PID is gone is still a wrapper failure, not a successful build.

**Never wrap the call in your own backgrounding** (a trailing `&`, an outer `nohup`, `disown`) —
`dispatch.sh --background` already detaches the process. A second layer of backgrounding can orphan
it past the point where anything is still waiting on its sentinel; on a real project one such orphan
kept running roughly 40 minutes after its round was believed done and overwrote the `--log`/`--out`
path of a later, already-reviewed round that reused the same path, which looked like a hostile
concurrent writer until traced.

If the project has a build environment bootstrap file, pass it explicitly with `--env-file`. The
standard committed path is `.agents/build-env.sh`; a machine-specific override may use
`.agents/build-env.local.sh` when the project gitignores it. Use only one per dispatch. This hook is
language-agnostic: it may set `JAVA_HOME`, activate a Node package manager, select a Go toolchain,
put dependency caches inside the workspace, or do nothing in projects that do not need it. Prefer a
workspace-local cache over granting the implementation sandbox write access to user-level caches
such as `~/.m2`.

Environment corrections are allowed during step 4 when the sandbox sees the wrong local toolchain.
Record the file used and the reason in the journal. Do not use an environment correction to change a
project runtime baseline, supported dependency line, or ADR; that is a scope or decision change.

**The build needs network, so pass `--network`.** `workspace-write` denies network access by
default, which stops any build that has to resolve a dependency — and a build cannot ask for
permission, because `-a never` is what keeps a background dispatch from hanging on a prompt nobody
will answer. `--network` sets the sandbox's `network_access` for that one dispatch only; the
read-only levels keep the default and the profile's stored configuration is untouched.

```bash
test -n "${MODEL_IMPLEMENTATION:-}" || printf '%s\n' 'STOP: MODEL_IMPLEMENTATION is required' >&2
test -n "${MAX_ROLLOUT_TOKENS_IMPLEMENTATION:-}" || printf '%s\n' 'STOP: MAX_ROLLOUT_TOKENS_IMPLEMENTATION is required' >&2

STALL_TIMEOUT_IMPLEMENTATION=${STALL_TIMEOUT_IMPLEMENTATION:-1800}
WALL_TIMEOUT_IMPLEMENTATION=${WALL_TIMEOUT_IMPLEMENTATION:-7200}
HEARTBEAT_IMPLEMENTATION=${HEARTBEAT_IMPLEMENTATION:-30}
MAX_SELF_HEAL_RESTARTS=${MAX_SELF_HEAL_RESTARTS:-1}

set -- --model "$MODEL_IMPLEMENTATION" --max-rollout-tokens "$MAX_ROLLOUT_TOKENS_IMPLEMENTATION"
[ -n "${REASONING_EFFORT_IMPLEMENTATION:-}" ] && set -- "$@" --reasoning-effort "$REASONING_EFFORT_IMPLEMENTATION"
if [ -f .agents/build-env.local.sh ]; then set -- "$@" --env-file .agents/build-env.local.sh
elif [ -f .agents/build-env.sh ]; then set -- "$@" --env-file .agents/build-env.sh
fi
[ -f .agents/preflight.sh ] && set -- "$@" --preflight .agents/preflight.sh

"$SKILLDIR/dispatch.sh" --profile "$PROFILE_IMPLEMENTATION" "$@" --mode workspace-write --background --network \
  --phase implementation \
  --stall-timeout-seconds "$STALL_TIMEOUT_IMPLEMENTATION" \
  --wall-timeout-seconds "$WALL_TIMEOUT_IMPLEMENTATION" \
  --heartbeat-seconds "$HEARTBEAT_IMPLEMENTATION" \
  --protect "$JOURNAL" --protect "$PLAN" \
  --prompt-file "$SKILLDIR/prompts/4-build.txt" \
  --var PLAN="$PLAN" --var CONTEXT_PACK="$CONTEXT_PACK" \
  --log "$RUN/build.log"
```

`--protect` makes the orchestrator's files tamper-proof for the length of the build: the
supervisor snapshots each one at launch and restores it if the build changed it, and names it in
the build log. The journal and the plan are yours. A build agent once marked its own verification
and review complete in the journal while it was still implementing.

The build agent writes its own account to `$RUN/build.report.md` as it goes — which steps are
done, which commands it ran with which result, what it corrected, what is `SANDBOX-BLOCKED` — and
ends it with the line `IMPLEMENTATION_STEPS_COMPLETE` once every step is implemented. The
dispatcher supplies that path to the prompt; you pass nothing for it.

`$PROFILE_IMPLEMENTATION` may be a pool. `dispatch.sh` picks the first profile in it that
resolves from `~/.aimux/config.yaml` to start the build, but never retries a failed build on the
next one — see `dispatch.sh`'s
own header comment for why.

The dispatcher refuses an Implementation phase with no explicit model or rollout budget. This is a
mechanical invariant, not a prompt convention: changing or borrowing the paying profile never changes
`MODEL_IMPLEMENTATION` or the budget.

The sandbox still confines writes to the workspace. Network access widens what the build can reach,
not what it can overwrite, which is why it is granted per dispatch rather than stored on the
profile.

The command returns immediately and prints the **supervisor PID**, sentinel path, health path,
report path, heartbeat interval, stall ceiling, and wall-clock ceiling. Record the supervisor PID
and artifact paths in the journal. It refuses to start while an earlier supervisor for the same
`--log` is still alive; that is a running build, not an obstacle to remove.

The supervisor, not the worker CLI, is the process the harness should track. It launches the CLI as
its child, samples observable progress once per second, writes a compact `.health` heartbeat at the
configured cadence, and guarantees that either:

- the worker exits and a normal sentinel is written;
- no observable log/event progress for the stall ceiling becomes exit `124` with
  `failure_class=timeout.stalled`; or
- the hard wall ceiling becomes exit `124` with `failure_class=timeout.wall`.

Defaults are 30 minutes without observable progress and two hours total for one implementation
dispatch. These are per-job ceilings, not a limit on an overnight Mission Mandate; a mission may run
many healthy dispatches in sequence.

The sentinel remains the completion source of truth. Do not tail a running build. The `.health`
file is the liveness source of truth while no sentinel exists.

### Wait for the supervised build

If the harness provides task notifications, track the **supervisor** task. A worker hang can no
longer suppress completion forever because the supervisor terminates it at the configured ceiling
and then exits itself. On every notification or resumed session, inspect state mechanically:

```bash
set +e
HEALTH=$(sh "$SKILLDIR/dispatch-health.sh" --log "$RUN/build.log")
HEALTH_RC=$?
set -e
printf '%s\n' "$HEALTH"
```

Interpret it as follows:

| Health result | Action |
| --- | --- |
| exit 0 / `state=finished` | The line carries `exit`, `reason`, `steps_complete`, and `total_tokens`. Continue from them; on anything but `exit=0`, `tail -45 "$RUN/build.log"` is the readable summary. |
| exit 10 / healthy running | Keep waiting; do not read the log. |
| exit 20 / stale heartbeat | Treat the supervisor itself as unhealthy; do not assume the worker is fine. |
| exit 30 / lost or unknown | Treat the dispatch as lost infrastructure state; never wait indefinitely for a sentinel that may never arrive. |

For plain CLI environments without task notifications, use a bounded health loop rather than an
unbounded sentinel loop:

```bash
while :; do
  set +e
  sh "$SKILLDIR/dispatch-health.sh" --log "$RUN/build.log"
  rc=$?
  set -e
  case "$rc" in
    0) break ;;
    10) sleep 20 ;;
    20|30) break ;;
    *) break ;;
  esac
done
```

A stale/lost supervisor is an environment failure, not evidence that implementation is still
progressing.

When the build has ended, the last lines of `$RUN/build.log` are a summary written for you: status
and failure class, whether every step was reported complete, tokens used, protected files that
were restored, files that are new and untracked since launch, the end of the build report, and —
on failure — the last events in readable form. `tail -45` of it is the whole diagnosis you need in
the normal case. Record `total_tokens` in the journal.

### If the build stops on its rollout budget

`reason=budget` is not one situation but two, and `steps_complete` tells them apart. The stop cuts
the worker off mid-turn, so there is no final message; the build report and the working tree are
what remain. The dispatcher asks the CLI to warn the agent when a quarter and a tenth of the
budget is left, and the build prompt tells it to stop adding work and write its report at that
point — but treat that as help, not a guarantee.

| `steps_complete` | What happened | Do |
| --- | --- | --- |
| `yes` | The code was finished; the budget went on verification or on a command the sandbox could not run | **Do not re-dispatch.** Go to step 4b, run the verification yourself, then step 5 |
| `no` | The build stopped part-way | Checkpoint, then continue with a narrower dispatch (below) |

Raising the ceiling is the wrong first move in both rows. In four of five budget stops across
three projects the code was already correct, and the fifth was a plan that was too large.

To continue a part-way build without losing or re-doing work:

1. Read the end of `$RUN/build.report.md` (it is in the log summary) for what is done and what is
   not. If the report is empty, run the plan's sandbox-safe gate through `evidence.sh` to learn
   whether the tree at least compiles.
2. Commit the tree as it stands as a checkpoint, in the project's commit format and marked as such, on
   the work branch or in the isolated worktree. This is Delegated; a checkpoint commit is what
   makes the next dispatch's diff readable and its failure recoverable.
3. Add a row to the plan's **Follow-up rounds** naming the steps that remain, and commit it.
4. Dispatch step 4 again with the same plan. The earlier attempt's files are archived
   automatically. The agent sees the committed checkpoint and the remaining steps; it does not
   start over.

If the same plan stops on its budget twice with `steps_complete=no`, the plan is too large: split
it. Do not dispatch a third time.

### Self-heal a timed-out implementation

For a **background build**, `timeout.stalled` and `timeout.wall` are **retryable only from a clean
baseline**. Never launch a second writer into the same partially modified tree. (A read-only
foreground dispatch that times out wrote nothing and is retried on the next profile automatically.)

When the increment runs in an orchestrator-owned isolated worktree, persist the restart budget in
the run directory before recreating anything:

```bash
SELF_HEAL_COUNT_FILE="$RUN/build.self-heal-count"
SELF_HEAL_COUNT=$(cat "$SELF_HEAL_COUNT_FILE" 2>/dev/null || printf 0)
case "$SELF_HEAL_COUNT" in *[!0-9]*|'') SELF_HEAL_COUNT=0 ;; esac

if [ "$SELF_HEAL_COUNT" -ge "$MAX_SELF_HEAL_RESTARTS" ]; then
  printf 'SELF_HEAL exhausted count=%s max=%s\n' "$SELF_HEAL_COUNT" "$MAX_SELF_HEAL_RESTARTS"
else
  next_count=$((SELF_HEAL_COUNT + 1))
  printf '%s\n' "$next_count" > "$SELF_HEAL_COUNT_FILE.tmp"
  mv -- "$SELF_HEAL_COUNT_FILE.tmp" "$SELF_HEAL_COUNT_FILE"
  printf 'SELF_HEAL restart=%s/%s\n' "$next_count" "$MAX_SELF_HEAL_RESTARTS"
fi
```

That file is local run-state and survives an orchestrator/session handoff. Never infer the retry
budget from conversational memory.

For an allowed restart:

1. record the timeout class, supervisor health, pre-dispatch baseline SHA, and incremented restart
   count;
2. mark the timed-out worktree tainted and remove it after the supervisor has finished;
3. recreate a fresh temporary worktree from the same pre-dispatch baseline;
4. reuse the same committed plan and frozen context pack;
5. if a distinct leased profile from the same interchangeable pool is available, the retry may use
   it; the model and rollout budget remain pinned;
6. verify normally after a successful restart.

The clean restart is Delegated recovery under an active Mission Mandate. Record it and continue; do
not ask the user whether to retry.

If the increment is not isolated in an orchestrator-owned worktree, or the clean restart also times
out, do **not** reset/stash/overwrite uncertain work. Classify the result as an environment/repository
blocker and return it to project-driver. Under an active mission, project-driver may choose another
ready independent increment; it must not continue pretending the hung job is healthy.

For ordinary non-timeout build/verification failures, apply `systematic-debugging` when installed,
using the bounded failure report and reproduction command. A recoverable diagnosis re-enters the
mission continuation loop; a non-recoverable blocker is recorded explicitly.

### If Implementation discovers a plan gap

Implementation may correct a local, reversible plan defect when the correction is necessary to
satisfy the existing Goal and Included scope and does not change a requirement, ADR, runtime
baseline, excluded area, security boundary, cost commitment, or externally visible product behavior.
It must record the correction in its final report.

For a material change, Implementation stops with the smallest concrete Escalation decision. The
orchestrator updates the plan after that decision and re-dispatches. Do not escalate a missing file
path, ordinary refactor, local test adjustment, or equivalent implementation detail that can be
resolved safely from repository evidence.

### If a dispatched call hits a usage limit mid-run

If the blocked level's own profile pool has an untried member, dispatch on that instead — that is
what a pool is for. Only once the whole pool is exhausted do the options below apply.

Before stopping, consider borrowing a profile from a different level's pool for this one blocked
call: dispatch it under that profile instead, and record the borrow and the reason in the journal's
Deviations. **Keep the blocked level's explicit model and rollout budget unchanged**: borrowing a
profile changes the payer, never the execution policy. Revert to the normal split on the next
dispatch — the borrow is a one-off, not a standing
reassignment. This was needed in both directions on a real project when one level's pool ran out
mid-plan and the other level's pool still had headroom.

If no profile anywhere has headroom, stop, write it in the journal, report to the user. `aimux
handoff <sessionId> --to <profile>` can continue the same session under another profile via a lossy
summary — re-check its grasp of scope and Definition of Done before trusting it unattended. Untested
end-to-end here; if it misbehaves, stop and report rather than improvising a fix mid-build.

## Step 4b — Run the verification and record the evidence

The verification agent is read-only. It cannot build, start a browser, or run the gate, so a
condition that needs a command result reaches it only through what you record here. Skip this step
and the honest answer to most of the Definition of Done is "uncertain" — which is what three
projects got, and then accepted.

Run every row of the plan's **Verification** table, whoever owns it. The build agent's own run of
an Implementation-owned command is its claim; yours is the evidence.

```bash
sh "$SKILLDIR/evidence.sh" --out "$EVIDENCE" --label gate \
  --timeout-seconds 1800 --cmd '<command from the Verification table>'
```

One call per command, with a label the verifier can cite (`gate`, `e2e`, `real-input`). Add
`--env-file` as in step 4. The script closes stdin, keeps the full output in `$RUN/evidence/`,
appends the command, exit code, commit, and last lines to `$EVIDENCE`, and prints one `EVIDENCE`
line. It returns 0 whatever the command returned: a failing command is a finding to record, not a
reason to stop recording.

**Then run the product on real input** when the plan has a **Real input for self-check** row —
the import, the conversion, the page, the command a user would run:

```bash
sh "$SKILLDIR/evidence.sh" --out "$EVIDENCE" --label real-input \
  --cmd '<the product command on the real file, printing the properties the plan names>'
```

Compare what it prints with the plan's expected properties yourself. This is the check that is
yours alone: the build agent and the verifier both work from fixtures and code, and "all tests
green" has repeatedly coexisted with a product that mangled the first real document it met.

What you do with a failure:

| Result | Do |
| --- | --- |
| Fails the same way the baseline did | Not this plan's failure. The evidence shows it; continue |
| A new failure, or the real input is wrong | Record it under the plan's **Follow-up rounds** as input / observed / expected, commit, and dispatch step 4 again. Do not write the fix or the rule |
| The command cannot run on this machine | An environment finding. Fix the environment or record the condition as unproven; never report it as passed |

Record each `EVIDENCE` line in the journal.

## Step 5 — Dispatch verification against the plan

Do not read the diff yourself.

Before reporting the result, apply `verification-before-completion` when it is installed. It owns
the evidence check for each Definition of Done condition; this workflow owns dispatching the
verification agent and deciding which gate comes next.

```bash
set --
[ -n "${MODEL_REASONING:-}" ] && set -- "$@" --model "$MODEL_REASONING"
[ -n "${REASONING_EFFORT_REASONING:-}" ] && set -- "$@" --reasoning-effort "$REASONING_EFFORT_REASONING"

"$SKILLDIR/dispatch.sh" --profile "$PROFILE_REASONING" "$@" --mode read-only \
  --phase verification \
  --prompt-file "$SKILLDIR/prompts/5-verification.txt" \
  --var PLAN="$PLAN" --var CONTEXT_PACK="$CONTEXT_PACK" \
  --var SHA="<baseline SHA from the journal>" \
  --var BUILD_LOG="$RUN/build.log" \
  --var EVIDENCE="$EVIDENCE" \
  --out "$RUN/verification.md"
```

The report answers each Definition of Done condition with `done`, `not done`, `not in evidence`,
or `uncertain`. Only `done` closes a condition:

- **`not in evidence`** — the condition needs a command result nobody recorded. Go back to step 4b,
  run it, and dispatch verification again. Do not accept the increment on it.
- **`uncertain`** — the verifier could not decide from the diff and the evidence. Resolve it with a
  recorded run or a spot-check of one hunk; an increment is not complete with an open `uncertain`.
- **`not done`** — a follow-up round: step 4b's table applies.

In a standalone run, report to the user what is done, what is not, and what was built outside
`Included`. Under an active project-driver mission, return that same bounded result to the outer
orchestrator instead. Do **not** phrase increment completion as completion of the user's overall
mission; `INCREMENT_COMPLETE` is an inner-workflow result, while only Mission Mandate state may
declare `MISSION_COMPLETE`. You may spot-check a single hunk for a high-risk change or a report
that looks wrong — a judgment call, not the default.

**Say what was proven, not only what was built.** "Implemented and tests pass" and "run on real
input with this result" are different claims. Use the second only when step 4b recorded it, and
set a story to `Done` at closeout only then; otherwise it is `Built`.

If Implementation stops, classify the cause. For a Delegated implementation or environment failure,
apply the debugging/retry rules and re-dispatch rather than asking the user what to do. Under an
active project-driver mission, return Escalations to the outer orchestrator for resolution and return
Reserved actions as candidate gates; do not address either question directly to the user. In a
standalone run, report the smallest material decision. The orchestrator still does not take over
production coding itself.

## Step 6 — Commit and integrate internally

Never leave the build as an ambiguous dirty tree. Commit verified Delegated work automatically.
Before committing, look at `git status --short`: a file whose name ends in a space and a number
(`dispatch 2.sh`, `SKILL 3.md`) is a sync-conflict copy, not part of the change — remove it rather
than commit it.
A standalone `interactive` run may still request its explicitly selected commit pause, but an active
project-driver mission suppresses that pause. If the work ran in an orchestrator-created temporary
branch or `.worktree`, integrate it back into the task's owning branch, verify the resulting commit
contains the work, and remove the temporary worktree/branch when safe. This is internal execution
plumbing, not a human decision.

Do not merge unrelated concurrent work or overwrite a dirty target branch. That is a repository
safety failure, not permission to guess.

## Step 7 — Impact handoff

Determine the next transition from the project's authority contract.

- If it is Delegated, perform it and continue.
- Under an active project-driver mission, return an Escalation to project-driver as orchestrator work.
  Return a Reserved action as a candidate human gate. **Do not ask the user from this inner
  workflow.** Project-driver's `mission-control.sh authorize` is the only component allowed to issue
  a `HUMAN_GATE` token.
- In a standalone run with no active mission, present the smallest unresolved material decision when
  the workflow cannot safely resolve it.
- If no further transition is needed, continue directly to closeout.

There is no universal merge gate and no inner-workflow "should I continue?" gate.

If an external code review is requested, use `requesting-code-review` to prepare the review package.
When findings return, use `receiving-code-review` to disposition each finding before entering a fix
round. The internal plan review in step 2 remains part of this workflow and does not replace an
external code review.

## Step 8 — Close out

After the transition recorded in step 7, answer the plan's **At closeout** section from the run
evidence and project documents. Write durable results immediately: architectural decisions to
`docs/03-sad.md`, status/traceability to requirements, and durable change records where applicable.
Write each into the section of the document where the subject already lives, replacing what it
supersedes; never append a dated section ("Update 2026-…") to the end of a document — nine of
those turned one project's architecture document into a log nobody could read as a description.
Confirm `Current status` in `docs/00-ai-context.md` still describes the project, and run
`sh "$SKILLDIR/project-health.sh"` once more: a `NOTE` it prints now is cheaper to clear than at
the start of the next run.
Escalate only when a closeout item itself crosses the authority boundary; do not turn bookkeeping
into a user questionnaire.

Use `finishing-a-development-branch` when it is installed. Give it the final verification result,
changed-path summary, open findings, branch state, authority contract, and release requirement. It
performs Delegated integration/cleanup and returns only any remaining Escalation/Reserved transition.

Then delete the plan and its journal in their own commit, and remove `$RUN` when that cleanup is
Delegated by the project. If plan deletion is explicitly Reserved, leave the artifacts and report
that single pending transition. Under an active project-driver mission, closeout returns control to
project-driver; it does not end the mission merely because this plan is finished.
`plan-template.md` and `journal-template.md` stay in the skill directory — they are templates,
not artifacts.

## Resuming an interrupted run

If you are picking up a run you did not start — a new session, or another CLI taking over at a usage
limit — read `docs/plans/*.run.md` and nothing else. It tells you the last completed step, whether a
build is still running, and where the reports are. If it records a running build, ask
`dispatch-health.sh` before anything else; a second build into the same tree is refused while the
first supervisor lives. Continue from the next step. Do not re-dispatch a
step the journal records as done, and do not reconstruct context by reading code.

## Notes

- The four runtime levels may be assigned to one or more agents. The point is not fewer total tokens — it is keeping your session
  small and moving the expensive reading onto profiles you are not metered against. For a change the
  user can review in five minutes this is not worth it; say so instead of running it.
- The levels, plan, journal, budgets and gates are tool-independent; only `dispatch.sh` knows how a
  given CLI spells sandbox, approval, output and network, and it keeps that in one adapter
  block. Which CLI runs a level comes from its aimux profile's `cli` field, resolved from
  `~/.aimux/config.yaml` at dispatch time — a project never edits this skill to change tools, it
  runs `aimux profile update <name> --cli <cli>`. `codex` is the only adapter implemented today;
  adding another is a framework change, not a project one. `docs/00-ai-context.md` records which
  profile pool fills each level.
- The rationale behind all of this — why cost separation and not just context isolation, why the
  gates sit where they do — is in the framework's `ai-usage-guide.md` § 5. It is not needed to run
  the workflow, which is why it is not here.
- This file is the shared procedure for both orchestrators. Claude Code discovers the copy under
  `.claude/skills/` and invokes `/plan-driven-build`; Codex discovers the copy under `.agents/skills/`
  and invokes `$plan-driven-build` or selects it through `/skills`. No separate custom-prompt frontend
  is needed. The journal is how a run continues when the first orchestrator hits a usage limit.
