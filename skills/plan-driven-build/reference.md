# Plan-Driven Build: situational reference

`SKILL.md` is the procedure and is read on every run. This file holds what a run needs only when
something specific happens. **Read the one section your situation names, not the whole file.**

| Situation | Section |
| --- | --- |
| You are adapting a snippet, or a command failed in `zsh` | [Shell rules](#shell-rules) |
| `project-health.sh` printed a `NOTE` | [Project health notes](#project-health-notes) |
| Step 0 printed `MISSING`, or a dispatch printed `FALLBACK:` | [Profile pools](#profile-pools) |
| A dispatch exited non-zero | [Failure classes](#failure-classes) |
| You need the gate-profile table or a discipline skill's contract | [Gate profiles and discipline hooks](#gate-profiles-and-discipline-hooks) |
| A runtime or service must exist before a dispatch | [Preflight](#preflight) |
| A dispatch may create child agents | [Model evidence](#model-evidence) |
| You need to find a dispatch's files or read its token figure | [Dispatch files and token figures](#dispatch-files-and-token-figures) |
| The build needs a toolchain path, a cache, or network | [Build environment](#build-environment) |
| The harness has no task notifications | [Waiting without notifications](#waiting-without-notifications) |
| The build ended with `reason=budget` | [Budget stop](#budget-stop) |
| The build ended with `timeout.stalled` or `timeout.wall` | [Timed-out build](#timed-out-build) |
| The build report names a plan gap | [Plan gap](#plan-gap) |
| A usage limit stopped a dispatch | [Usage limit](#usage-limit) |
| You want to know why the tooling is shaped this way | [Design notes](#design-notes) |

## Shell rules

The snippets in `SKILL.md` run unchanged in `sh`, `bash`, and `zsh`. When you adapt one, keep three
habits — each has cost a real run a failed command:

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

## Project health notes

`project-health.sh` reports rules the project has drifted from: plans that outlived their change,
an AI Context that became a log, modified files left uncommitted for days, a run of plans that
deliver no requirement, runtime copies of a skill that differ, a repository inside a cloud-synced
folder. It never blocks. Act on the notes that bear on this run before step 1:

- **`worktree`** — tracked files modified more than a day ago are someone's unfinished work, not
  background noise. Do not plan on top of them: get them committed or discarded first, or build in
  a clean worktree. One project carried 47 uncommitted files for five days as its only copy.
- **`plans`** — close out a stale plan before opening another; a transient plan that stays is a
  second, wrong source of truth.
- **`delivers`** — surface it. Three maintenance plans in a row is the signal that product work is
  happening outside the requirements; see step 1 on `Delivers`.
- **`location`** — a cloud-synced repository produces conflict copies such as `SKILL 2.md` while
  agents write. Build in a git worktree outside the synced root.
- **`ai-context`** — the document is over its size limit or has not been updated for many commits.
  Move delivered work to change management and confirm `Current status` at closeout.
- **`skills`** — the `.agents` and `.claude` copies of a managed skill differ. Managed skills are
  framework-owned; restore them from the framework rather than choosing a copy by hand.
- **`runs`**, **`tooling`** — housekeeping: remove the run directories of closed plans; add the
  workflow or preflight the documents and build env file imply.

## Profile pools

A pool is one aimux profile or several comma-separated ones, tried in priority order, and is
written as profile names or `cli:NAME`; a bare CLI name such as `codex` is read as a profile name.
`aimux profile list` (or `~/.aimux/config.yaml`) shows the profiles that exist.

A profile selects its CLI, authentication, and paying subscription. Its stored model is only a
default for levels that do not pin one — it is not a role. Which subscriptions fill which level,
and in what order, is the project's decision: one profile may fill several levels, any profile may
fill any level, and a pool exists to spread load across interchangeable subscriptions — not to give
a level its own identity. Review does not need to differ from Reasoning's pool; the prompt file is
what keeps a review from sharing the drafting level's blind spots. Without a profile different
from the orchestrator's, cost is not separated, only context.

**`MISSING`** at step 0 means every profile in that pool is absent from `~/.aimux/config.yaml`, so
the dispatch will fail unless the pool ends in a `cli:NAME` fallback entry. Fix the pool in
`docs/00-ai-context.md`, or run `aimux profile add <name> --cli <cli>`. `dispatch.sh` re-checks
this per dispatch and, when no entry resolves, lists the profiles that do exist.

**`FALLBACK:`** from `dispatch.sh` means a pool entry could not be resolved and a later entry or a
`cli:NAME` fallback ran instead. Pass the line on to the user and record it in the journal's
Deviations rather than letting it scroll past: an unrecorded fallback looks like successful
subscription separation.

`$PROFILE_IMPLEMENTATION` may be a pool. `dispatch.sh` picks the first profile in it that resolves
to start the build, but never retries a failed build on the next one — see `dispatch.sh`'s own
header comment for why. The dispatcher refuses an Implementation phase with no explicit model or
rollout budget. This is a mechanical invariant, not a prompt convention: changing or borrowing the
paying profile never changes `MODEL_IMPLEMENTATION` or the budget.

## Gate profiles and discipline hooks

The plan's `Gate profile` field controls how much routine execution is surfaced. Authority comes
first: a gate profile never converts Delegated work into a human decision.

| Profile | Behavior |
| --- | --- |
| `semi-automatic` *(default)* | Execute Delegated work end-to-end; surface meaningful assumptions in the report; stop only for Escalation/Reserved decisions |
| `interactive` | For standalone runs, pause before committing or externally integrating when explicitly chosen. An active project-driver mission suppresses these routine pauses; its reserved-only human-gate policy wins. |
| `unattended` | Execute every Delegated transition, including commits, temporary worktrees/branches, and internal integration; notify only on completion, failure, or Escalation/Reserved decisions |

Choose `interactive` for deliberately supervised work, not because the framework is uncertain about
normal implementation detail.

The five discipline skills remain independently installable, but `plan-driven-build` invokes them
when their trigger is present:

| Event | Skill | Required result |
| --- | --- | --- |
| Bug, build failure, test failure, or unexpected behavior | `systematic-debugging` | Root cause, failure class, retryability, next action |
| Verification or completion claim | `verification-before-completion` | Evidence and result for every condition |
| External review requested | `requesting-code-review` | Review package and bounded request |
| Review findings received | `receiving-code-review` | Disposition and evidence for every finding |
| Branch or plan work is complete | `finishing-a-development-branch` | Closeout options and merge/cleanup evidence |

If a hooked skill is not installed, follow the equivalent guardrail in `SKILL.md` and record the
missing module in the journal. A hook is conditional: a successful implementation does not invoke
debugging, and a run with no external review does not invoke the review-request or review-reception
skills. The orchestrator still owns phase order, dispatch, journal state, model policy, and human
gates. Give `finishing-a-development-branch` the final verification result, changed-path summary,
open findings, branch state, authority contract, and release requirement; it performs Delegated
integration and cleanup and returns only any remaining Escalation or Reserved transition.

## Failure classes

Every dispatch has a bounded execution contract. The lifecycle is:

```text
preflight -> planning -> implementation -> verification -> review -> finalization
```

Use the phase that matches the dispatch and record its status in the journal. A failure is
retryable only when the dispatch evidence says it is.

| `failure_class` | Meaning | Do |
| --- | --- | --- |
| `environment.rate_limit` | The profile hit a rate or usage limit | Read-only levels move to the next profile in the pool automatically; otherwise see [Usage limit](#usage-limit) |
| `environment.preflight` | The Git, index-lock, or project preflight failed before the agent ran | Fix the environment. Never retried on another profile |
| `environment.sandbox-nested` | The dispatched CLI could not start its own sandbox because the orchestrator's shell is itself sandboxed (`operation not permitted` before the first event) | No profile change fixes it: run the dispatch from an unsandboxed shell, as `setup.md` describes |
| `environment` | Runtime, service, or repository state | Not automatically retryable; temporary service unavailability may be |
| `configuration` | A flag, profile, or file the dispatch needs is wrong | Fix it; see `setup.md` |
| `model-routing` | An observed model differs from the effective model | Stop. See [Model evidence](#model-evidence) |
| `timeout.stalled`, `timeout.wall`, `timeout` | No output for the stall ceiling, or the wall ceiling was reached; exit `124` | Read-only: retried on the next profile automatically. Background build: [Timed-out build](#timed-out-build) |
| `budget` | The rollout-token ceiling stopped the worker | [Budget stop](#budget-stop) |
| `verification`, `implementation`, `plan` | The work itself failed | Not retryable as-is: `systematic-debugging`, a follow-up round, or a plan revision |
| `unknown` | The evidence does not classify it | `dispatch-tail.sh --events FILE --lines 15`, then classify |

Every dispatch runs with **stdin closed** and under a watchdog. A foreground dispatch that produces
no output for 15 minutes, or runs longer than an hour, is terminated with exit `124` and
`failure_class=timeout.stalled` or `timeout.wall` and, for a read-only level, retried on the next
profile in the pool; change the ceilings with `--stall-timeout-seconds` and
`--wall-timeout-seconds`. You never need to wrap a dispatch in your own timeout or redirect.

Retries are bounded by the remaining read-only profile pool and may be further limited with
`--max-retries N`. Workspace-write and background dispatches never retry automatically after launch.
Stop and record the next action when preflight, routing, environment, verification, budget, or
repository safety fails.

## Preflight

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

The step 4 snippet passes `.agents/preflight.sh` to the build automatically when the file exists.
A failed preflight stops before the agent runs and is never sent through the read-only retry pool.
The preflight script must not repair the environment or modify application files. A preflight that
only checks that a directory exists proves nothing: have it run the build tool once
(`mvn -q -version`, `npm --version`, `go version`) under the same env file the build will get, so a
broken toolchain path fails here in a second instead of inside a build that spends its budget on it.

## Model evidence

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

## Dispatch files and token figures

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

**The build log summary.** When the build has ended, the last lines of `$RUN/build.log` are a
summary written for you: status and failure class, whether every step was reported complete,
tokens used, protected files that were restored, files that are new and untracked since launch,
the end of the build report, and — on failure — the last events in readable form. `tail -45` of it
is the whole diagnosis you need in the normal case.

## Build environment

If the project has a build environment bootstrap file, the step 4 snippet passes it with
`--env-file`. The standard committed path is `.agents/build-env.sh`; a machine-specific override
may use `.agents/build-env.local.sh` when the project gitignores it. Use only one per dispatch.
This hook is language-agnostic: it may set `JAVA_HOME`, activate a Node package manager, select a
Go toolchain, put dependency caches inside the workspace, or do nothing in projects that do not
need it. Prefer a workspace-local cache over granting the implementation sandbox write access to
user-level caches such as `~/.m2`.

Environment corrections are allowed during step 4 when the sandbox sees the wrong local toolchain.
Record the file used and the reason in the journal. Do not use an environment correction to change
a project runtime baseline, supported dependency line, or ADR; that is a scope or decision change.

**Network.** `workspace-write` denies network access by default, which stops any build that has to
resolve a dependency — and a build cannot ask for permission, because `-a never` is what keeps a
background dispatch from hanging on a prompt nobody will answer. `--network` sets the sandbox's
`network_access` for that one dispatch only; the read-only levels keep the default and the
profile's stored configuration is untouched. The sandbox still confines writes to the workspace:
network access widens what the build can reach, not what it can overwrite.

## Waiting without notifications

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

A stale or lost supervisor is an environment failure, not evidence that implementation is still
progressing. The sentinel remains the completion source of truth; the `.health` file is the
liveness source of truth while no sentinel exists.

## Budget stop

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
it. Do not dispatch a third time. A plan on the short path that stops with `steps_complete=no`
leaves the short path: run step 2 on it before the next dispatch.

## Timed-out build

For a **background build**, `timeout.stalled` and `timeout.wall` are **retryable only from a clean
baseline**. Never launch a second writer into the same partially modified tree. (A read-only
foreground dispatch that times out wrote nothing and is retried on the next profile automatically.)

Defaults are 30 minutes without observable progress and two hours total for one implementation
dispatch. These are per-job ceilings, not a limit on an overnight Mission Mandate; a mission may
run many healthy dispatches in sequence.

When the increment runs in an orchestrator-owned isolated worktree, persist the restart budget in
the run directory before recreating anything:

```bash
MAX_SELF_HEAL_RESTARTS=${MAX_SELF_HEAL_RESTARTS:-1}
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

## Plan gap

Implementation may correct a local, reversible plan defect when the correction is necessary to
satisfy the existing Goal and Included scope and does not change a requirement, ADR, runtime
baseline, excluded area, security boundary, cost commitment, or externally visible product behavior.
It must record the correction in its final report.

For a material change, Implementation stops with the smallest concrete Escalation decision. The
orchestrator updates the plan after that decision and re-dispatches. Do not escalate a missing file
path, ordinary refactor, local test adjustment, or equivalent implementation detail that can be
resolved safely from repository evidence.

When Implementation stops, classify the cause. For a Delegated implementation or environment
failure, apply the debugging and retry rules and re-dispatch rather than asking the user what to
do. Under an active project-driver mission, return Escalations to the outer orchestrator for
resolution and return Reserved actions as candidate gates; do not address either question directly
to the user. In a standalone run, report the smallest material decision.

## Usage limit

If the blocked level's own profile pool has an untried member, dispatch on that instead — that is
what a pool is for. Only once the whole pool is exhausted do the options below apply.

Before stopping, consider borrowing a profile from a different level's pool for this one blocked
call: dispatch it under that profile instead, and record the borrow and the reason in the journal's
Deviations. **Keep the blocked level's explicit model and rollout budget unchanged**: borrowing a
profile changes the payer, never the execution policy. Revert to the normal split on the next
dispatch — the borrow is a one-off, not a standing reassignment. This was needed in both directions
on a real project when one level's pool ran out mid-plan and the other level's pool still had
headroom.

If no profile anywhere has headroom, stop, write it in the journal, report to the user. `aimux
handoff <sessionId> --to <profile>` can continue the same session under another profile via a lossy
summary — re-check its grasp of scope and Definition of Done before trusting it unattended. Untested
end-to-end here; if it misbehaves, stop and report rather than improvising a fix mid-build.

## Design notes

Why the rules in `SKILL.md` are what they are. None of this is needed to run the workflow.

- **Why the build runs in the background.** A build routinely exceeds the foreground timeout, and
  a killed process leaves half the change on disk. `dispatch.sh --background` detaches the child
  with `nohup`; a log that remains empty and has no sentinel after the PID is gone is a wrapper
  failure, not a successful build.
- **Why you never add your own backgrounding** (a trailing `&`, an outer `nohup`, `disown`). A
  second layer can orphan the process past the point where anything is still waiting on its
  sentinel. On a real project one such orphan kept running roughly 40 minutes after its round was
  believed done and overwrote the `--log`/`--out` path of a later, already-reviewed round, which
  looked like a hostile concurrent writer until traced.
- **Why the supervisor is the process to track.** It launches the CLI as its child, samples
  observable progress once per second, writes a compact `.health` heartbeat, and guarantees that
  the worker either exits with a normal sentinel, or is terminated with exit `124` at the stall or
  wall ceiling. A worker hang can therefore not suppress completion forever.
- **Why `--protect`.** The supervisor snapshots the journal and the plan at launch and restores
  them if the build changed them, naming them in the build log. A build agent once marked its own
  verification and review complete in the journal while it was still implementing.
- **Why the planner revises, not you.** One rule written in from outside the code ("a continuation
  line always belongs to the most recently opened node") was too absolute and cost a full build
  round.
- **Why a family sweep before `TASK`.** A real project needed five build-and-reverify rounds to
  work through five sibling classes because each round only surfaced the next one.
- **Why step 4b exists.** Three projects reached "Done" on fixtures while the real input still
  failed, and "all tests green" has repeatedly coexisted with a product that mangled the first
  real document it met.
- **Why closeout replaces instead of appending.** Nine dated "Update" sections turned one
  project's architecture document into a log nobody could read as a description.
- **Why the levels are tool-independent.** Only `dispatch.sh` knows how a given CLI spells
  sandbox, approval, output, and network, and it keeps that in one adapter block. Which CLI runs a
  level comes from its aimux profile's `cli` field, resolved from `~/.aimux/config.yaml` at
  dispatch time — a project never edits this skill to change tools, it runs
  `aimux profile update <name> --cli <cli>`. `codex` is the only adapter implemented today; adding
  another (gemini, claude, opencode) is a one-function framework change to `dispatch.sh`.
- **Why cost separation.** The point is not fewer total tokens — it is keeping the orchestrator's
  session small and moving the expensive reading onto profiles it is not metered against. The full
  rationale is in the framework's `ai-usage-guide.md` § 5.
