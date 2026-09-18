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
| **Orchestrator** (you) | Sequences, holds gates, writes the run journal | Read code or diffs, write production code |
| **Reasoning** | Drafts the plan (step 1), verifies the diff against it (step 5) | Change documented project intent or cross an authority boundary |
| **Implementation** | Builds an approved plan (step 4) | Change Goal/Included/Excluded, requirements, or architectural boundaries; may resolve local reversible plan gaps |

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
| Build log | `tail -30`, only on failure |
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

## Execution safety contract

Every dispatch has a bounded execution contract. The lifecycle is:

```text
preflight -> planning -> implementation -> verification -> review -> finalization
```

Use the phase that matches the dispatch and record its status in the journal. The shared failure
classes are `environment`, `environment.rate_limit`, `environment.preflight`, `configuration`,
`model-routing`, `timeout`, `budget`, `verification`, `implementation`, `plan`, and `unknown`; a failure is retryable only when the dispatch evidence says it is. Rate limits,
temporary service unavailability, and timeouts may be retryable. Runtime, repository, model-routing,
verification, and plan failures are not automatically retryable.

`dispatch.sh` runs a Git and index-lock preflight for every invocation. Add a project-owned,
read-only check when a runtime or service is required:

```bash
"$SKILLDIR/dispatch.sh" --profile "$PROFILE_REASONING" --mode read-only \
  --preflight .agents/preflight.sh --job-id "$ID-plan" \
  --prompt-file "$SKILLDIR/prompts/1-plan.txt" \
  --var TASK="<outcome>" --var PLAN_TEMPLATE="$SKILLDIR/plan-template.md" \
  --var DATE="$(date +%F)" --out "$PLAN" --max-lines 200
```

A failed preflight stops before the agent runs and is never sent through the read-only retry pool.
The preflight script must not repair the environment or modify application files.

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
is written automatically beside `--out` or `--log` unless `--ledger` overrides that path. It records
the job, phase, profile, requested and effective model, reasoning effort, rollout-budget ceiling,
attempt count, retryability, failure class, model policy, and token usage. Codex dispatches collect
native JSONL `turn.completed.usage` fields (input, cached input, cache-write input, output, reasoning
output); environment `CF_*` values remain a fallback for other runtimes. The ledger also records
exit status. If the
runtime exports `CF_INPUT_TOKENS`, `CF_OUTPUT_TOKENS`, or `CF_TOTAL_TOKENS`, those values are copied;
otherwise the ledger records `unavailable`. Raw output remains a debugging artifact, not the primary
run record.

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
`docs/00-ai-context.md`. A gate exists only for an unresolved Escalation or Reserved transition.

| Profile | Behavior |
| --- | --- |
| `semi-automatic` *(default)* | Execute Delegated work end-to-end; surface meaningful assumptions in the report; stop only for Escalation/Reserved decisions |
| `interactive` | Also pause before committing or externally integrating when the extra inspection has been explicitly chosen for this plan |
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
- `git status --porcelain` is empty and you are on the right branch. Implementation writes straight
  into the working tree; if it is dirty you can no longer tell its changes from what was there.
  Report what is uncommitted and let the user decide — never commit, stash or reset for them. The
  user may explicitly confirm the dirty paths belong to other in-flight work (for example a
  concurrent agent on the same tree) and authorize proceeding around them; treat that as a decision
  you record, not a default you assume, and log the excluded paths and the user's confirmation under
  the journal's Deviations.
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
PLAN=docs/plans/$ID.md
JOURNAL=docs/plans/$ID.run.md
RUN=docs/plans/.runs/$ID
CONTEXT_PACK=$RUN/context.md
MAX_CONTEXT_PACK_BYTES=65536
MAX_CONTEXT_FILE_BYTES=24576
mkdir -p "$RUN" && cp "$SKILLDIR/journal-template.md" "$JOURNAL"
```

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
    grep -qE "^  $p:[[:space:]]*$" "$aimux_config" && { printf 'ok       %s\n' "$p"; found=1; }
  done
  [ "$found" -eq 1 ] || printf 'MISSING  %s\n' "$pool"
done
```

A `MISSING` line means every profile in that pool is absent from `~/.aimux/config.yaml`, so the
dispatch will fail unless the pool ends in a `cli:NAME` fallback entry — fix the pool in
`docs/00-ai-context.md`, or run `aimux profile add <name> --cli <cli>`. `dispatch.sh` re-checks
this per dispatch, but catch it here before the run starts. Which subscriptions fill which level,
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
model_args=''
[ -n "${MODEL_REASONING:-}" ] && model_args="--model $MODEL_REASONING"
[ -n "${REASONING_EFFORT_REASONING:-}" ] && model_args="$model_args --reasoning-effort $REASONING_EFFORT_REASONING"

"$SKILLDIR/dispatch.sh" --profile "$PROFILE_REASONING" $model_args --mode read-only \
  --phase planning \
  --prompt-file "$SKILLDIR/prompts/1-plan.txt" \
  --var TASK="<one or two sentences: what should be true when this is done>" \
  --var PLAN_TEMPLATE="$SKILLDIR/plan-template.md" \
  --var DATE="$(date +%F)" \
  --out "$PLAN" --max-lines 200
```

`TASK` is the only thing you contribute here, so make it carry the intent — the plan is only as good
as this sentence. Build nothing in this step.

Immediately compile the plan's document references into the bounded context pack:

```bash
"$SKILLDIR/context-pack.sh" --plan "$PLAN" --out "$CONTEXT_PACK" \
  --max-bytes "$MAX_CONTEXT_PACK_BYTES" \
  --max-file-bytes "$MAX_CONTEXT_FILE_BYTES"
```

A pack failure is a planning defect, not permission to raise the ceiling. Narrow an oversized
whole-file reference to an exact heading, remove irrelevant context, or split the increment. Record
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
model_args=''
[ -n "${MODEL_REASONING:-}" ] && model_args="--model $MODEL_REASONING"
[ -n "${REASONING_EFFORT_REASONING:-}" ] && model_args="$model_args --reasoning-effort $REASONING_EFFORT_REASONING"

"$SKILLDIR/dispatch.sh" --profile "$PROFILE_REVIEW,$PROFILE_REASONING" $model_args --mode read-only \
  --phase review \
  --prompt-file "$SKILLDIR/prompts/2-review.txt" \
  --var PLAN="$PLAN" --var CONTEXT_PACK="$CONTEXT_PACK" \
  --out "$RUN/review.md" --max-lines 40
```

The command prints `budget=within budget (n/40)` or `OVER BUDGET`. If it is over, read the first 40
lines only and note the truncation in the journal.

## Step 3 — Revise and classify decisions

Write the objections you agree with into the plan yourself — a bounded edit, unlike reading source
docs or diffs. Briefly justify the ones you dismiss; silent dismissal hides that the review happened.

Before presenting it, scan the plan itself once more: placeholders ("TBD", "handle appropriately",
a step with no file path or verification command), tasks that contradict each other or the stated
`Excluded` list, and requirements a reader could take two ways. This is a bounded read of the plan
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
build_env_args=
[ -f .agents/build-env.sh ] && build_env_args='--env-file .agents/build-env.sh'
[ -f .agents/build-env.local.sh ] && build_env_args='--env-file .agents/build-env.local.sh'

test -n "${MODEL_IMPLEMENTATION:-}" || { printf '%s\n' 'MODEL_IMPLEMENTATION is required' >&2; exit 2; }
test -n "${MAX_ROLLOUT_TOKENS_IMPLEMENTATION:-}" || { printf '%s\n' 'MAX_ROLLOUT_TOKENS_IMPLEMENTATION is required' >&2; exit 2; }

model_args="--model $MODEL_IMPLEMENTATION --max-rollout-tokens $MAX_ROLLOUT_TOKENS_IMPLEMENTATION"
[ -n "${REASONING_EFFORT_IMPLEMENTATION:-}" ] && model_args="$model_args --reasoning-effort $REASONING_EFFORT_IMPLEMENTATION"

"$SKILLDIR/dispatch.sh" --profile "$PROFILE_IMPLEMENTATION" $model_args --mode workspace-write --background --network \
  --phase implementation \
  $build_env_args \
  --prompt-file "$SKILLDIR/prompts/4-build.txt" \
  --var PLAN="$PLAN" --var CONTEXT_PACK="$CONTEXT_PACK" \
  --log "$RUN/build.log"
```

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

The command returns immediately and prints the PID and the sentinel path. Write both in the journal.

The sentinel is the completion source of truth. Read `tail -30 "$RUN/build.log"` only when the
exit code is non-zero. Tailing a running build is the unbounded read this workflow exists to avoid.

Because the sentinel is a file, a build survives you: if your session hits a usage limit while it
runs, the build finishes anyway and whoever resumes reads the exit code.

### Wait for the build

If the harness provides task notifications for background processes, record the PID and sentinel,
yield control, and resume only when the task notification arrives. Do not call `ScheduleWakeup`, add
an arbitrary delay, or create a second polling loop solely to check a dispatch that the harness is
already tracking. A task notification is a wake-up signal, not proof that the build passed; always
read the sentinel after resuming.

If the harness does not provide task notifications, waiting is the orchestrator's job. Run one
bounded sentinel wait as a fallback:

```bash
BUILD_PID=<pid printed by the dispatch>
LOG_SIZE_BEFORE=$(wc -c < "$RUN/build.log" 2>/dev/null || printf 0)
deadline=$(( $(date +%s) + 3600 ))
while [ ! -f "$RUN/build.exit" ] && [ "$(date +%s)" -lt "$deadline" ]; do sleep 20; done

if [ -f "$RUN/build.exit" ]; then
  printf 'BUILD finished exit=%s\n' "$(cat "$RUN/build.exit")"
elif kill -0 "$BUILD_PID" 2>/dev/null; then
  LOG_SIZE_AFTER=$(wc -c < "$RUN/build.log" 2>/dev/null || printf 0)
  if [ "$LOG_SIZE_AFTER" = "$LOG_SIZE_BEFORE" ]; then
    printf 'BUILD still running after 60 min, pid %s alive, but build.log has not grown — possible stall\n' "$BUILD_PID"
  else
    printf 'BUILD still running after 60 min, pid %s alive, log growing\n' "$BUILD_PID"
  fi
else
  printf 'BUILD process gone, no sentinel written\n'
fi
```

Three outcomes, three different actions. A sentinel means go to step 5. Still alive means report the
elapsed time and wait again — a long build is not a stuck build. **Gone with no sentinel means the
process was killed** before it could write an exit code: say so and stop, because the working tree
now holds a partial build that no exit code describes. Without the `kill -0` check that case is
indistinguishable from a slow build, and waiting on it is waiting forever.

`kill -0` only proves the process exists, not that it is doing anything — a hung installer or a
stuck network call holds a live PID indefinitely. Compare `build.log`'s size across the wait window;
if it has not grown, treat the still-alive report as a likely stall (observed silently hanging three
separate times on a real project) and say so instead of quietly starting another 60-minute wait.

If the build or verification fails, apply `systematic-debugging` before proposing a code fix when
that skill is installed. Pass it the bounded failure report and reproduction command; record its
root cause and retryability result in the journal.

If the runtime has neither task notifications nor a bounded wait mechanism, do not claim to be
watching the build. Record the exact sentinel command and stop at that handoff. Never use an
arbitrary wake-up delay as a substitute for either mechanism.

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

## Step 5 — Dispatch verification against the plan

Do not read the diff yourself.

Before reporting the result, apply `verification-before-completion` when it is installed. It owns
the evidence check for each Definition of Done condition; this workflow owns dispatching the
verification agent and deciding which gate comes next.

```bash
model_args=''
[ -n "${MODEL_REASONING:-}" ] && model_args="--model $MODEL_REASONING"
[ -n "${REASONING_EFFORT_REASONING:-}" ] && model_args="$model_args --reasoning-effort $REASONING_EFFORT_REASONING"

"$SKILLDIR/dispatch.sh" --profile "$PROFILE_REASONING" $model_args --mode read-only \
  --phase verification \
  --prompt-file "$SKILLDIR/prompts/5-verification.txt" \
  --var PLAN="$PLAN" --var CONTEXT_PACK="$CONTEXT_PACK" \
  --var SHA="<baseline SHA from the journal>" \
  --var BUILD_LOG="$RUN/build.log" \
  --out "$RUN/verification.md"
```

Report it to the user: what is done, what is not, and what was built outside `Included`. You may spot-check
a single hunk for a high-risk change or a report that looks wrong — a judgment call, not the
default.

If Implementation stops, classify the cause. For a Delegated implementation or environment failure,
apply the debugging/retry rules and re-dispatch rather than asking the user what to do. For an
Escalation or Reserved decision, report that decision and stop. The orchestrator still does not take
over production coding itself.

## Step 6 — Commit and integrate internally

Never leave the build as an ambiguous dirty tree. Commit verified Delegated work automatically
unless `interactive` explicitly selected a commit pause. If the work ran in an orchestrator-created
temporary branch or `.worktree`, integrate it back into the task's owning branch, verify the
resulting commit contains the work, and remove the temporary worktree/branch when safe. This is
internal execution plumbing, not a human decision.

Do not merge unrelated concurrent work or overwrite a dirty target branch. That is a repository
safety failure, not permission to guess.

## Step 7 — Impact gate

Determine the next transition from the project's authority contract.

- If it is Delegated (for example local integration, an allowed push to the task branch, or continued
  work on the next increment), perform it and continue.
- If it is Escalation or Reserved (for example a material scope/architecture change, production
  publication, destructive migration, or a project-reserved shared-branch push), present only that
  decision and stop.
- If no further transition is needed, continue directly to closeout.

There is no universal merge gate.

If an external code review is requested, use `requesting-code-review` to prepare the review package.
When findings return, use `receiving-code-review` to disposition each finding before entering a fix
round. The internal plan review in step 2 remains part of this workflow and does not replace an
external code review.

## Step 8 — Close out

After the transition recorded in step 7, answer the plan's **At closeout** section from the run
evidence and project documents. Write durable results immediately: architectural decisions to
`docs/03-sad.md`, status/traceability to requirements, and durable change records where applicable.
Escalate only when a closeout item itself crosses the authority boundary; do not turn bookkeeping
into a user questionnaire.

Use `finishing-a-development-branch` when it is installed. Give it the final verification result,
changed-path summary, open findings, branch state, authority contract, and release requirement. It
performs Delegated integration/cleanup and returns only any remaining Escalation/Reserved transition.

Then delete the plan and its journal in their own commit, and remove `$RUN` when that cleanup is
Delegated by the project. If plan deletion is explicitly Reserved, leave the artifacts and report
that single pending transition. `plan-template.md` and
`journal-template.md` stay in the skill directory — they are templates, not artifacts.

## Resuming an interrupted run

If you are picking up a run you did not start — a new session, or another CLI taking over at a usage
limit — read `docs/plans/*.run.md` and nothing else. It tells you the last completed step, whether a
build is still running, and where the reports are. Continue from the next step. Do not re-dispatch a
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
