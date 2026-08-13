---
name: plan-driven-build
description: Plan-driven workflow where an orchestrator dispatches planning, critique, build and diff verification to other CLIs or accounts, keeping its own context and token spend bounded. Use when a task is large enough that its scope needs approval before code is written.
---

# Plan-Driven Build (plan-driven-build)

You are the **orchestrator**. You sequence the flow, hold the approval gates, and dispatch the
thinking and building elsewhere. You write no production code and you never read the codebase or the
full diff — you read bounded distillates produced by agents that did that reading for you.

| Level | Does | Must not |
| --- | --- | --- |
| **Orchestrator** (you) | Sequences, holds gates, writes the run journal | Read code or diffs, write production code |
| **Reasoning** | Drafts the plan (step 1), verifies the diff against it (step 5) | Approve its own work, decide scope |
| **Implementation** | Builds an approved plan (step 4) | Re-plan — stops and reports instead |

Reasoning and Implementation must run under **a different CLI or account than you**. That is the
point of the workflow: not context isolation, but moving token spend off the metered interactive
session. A Claude subagent shares your account and does not achieve this.

Setup — accounts, sandbox and approval flags, permission allowlist — is in `setup.md`.
Read it only if a prerequisite check fails.

## The budget (the hard rule)

Everything below exists to keep **your** context small. Per round you may read:

| Artifact | Ceiling |
| --- | --- |
| `docs/00-ai-context.md` | 1 page, once |
| The plan | Once, after step 1 |
| Critique report | 40 lines |
| Build log | `tail -30`, only on failure |
| Verification report | One line per Definition of Done condition + 10 lines of deviations |
| Run journal | ~30 lines, on resume |

If the plan sets a `Report budget` other than the default, pass it to `--max-lines` instead.

You may **not** read: `git diff`, source files, the full build log, the prompt files, or a report
that exceeds its budget — truncate it and say you did. If you find yourself reading the codebase
"to be sure", the workflow has already failed; say so rather than continue.

## Gate profiles

The plan's `Gate profile` field decides where you stop. Default is `semi-automatic`.

| Profile | Stops at |
| --- | --- |
| `semi-automatic` *(default)* | Step 3 (scope) and 7 (merge). Commit happens automatically, closeout is proposed |
| `interactive` | Step 3, 6 (commit), 7, and 8 (closeout) |
| `unattended` | Step 7 only. Requires every Definition of Done condition to be command-checkable |

A gate exists where a decision is the user's and hard to walk back: **scope**, before any code
exists, and **merge**, before the work reaches the shared branch. Everything between those two is
execution against a scope the user already approved. A commit inside a round is reversible and
touches nobody else, so stopping there buys a confirmation rather than a decision — it interrupts
the user without giving them anything they could not still change at the merge gate.

Choose `interactive` when the extra stop earns something concrete: unfamiliar territory, a risky
migration, or a first run in a new project where you want to see the shape of a commit before it
lands. Choose by risk, not by nerves.

A profile never removes the merge gate. You never approve on the user's behalf.

## Prerequisites

Check, and if anything is missing: report it and stop.

- `command -v codex` and `AGENTS.md` in the project root.
- This skill exists at `.agents/skills/plan-driven-build/` or `.claude/skills/plan-driven-build/`.
  Install it in both locations when both Codex and Claude Code are used. The copies must be identical.
- `git status --porcelain` is empty and you are on the right branch. Implementation writes straight
  into the working tree; if it is dirty you can no longer tell its changes from what was there.
  Report what is uncommitted and let the user decide — never commit, stash or reset for them.
- `docs/00-ai-context.md` names an aimux account for each level, and `aimux profile list` shows
  those accounts. **Account names are subscriptions, not roles** — whatever the project calls its
  subscriptions is what goes in both places, and the same account may fill several levels. Step 0
  verifies the mapping; without it cost is not separated, only context. `dispatch.sh` also prints a
  `FALLBACK:` line per dispatch — pass it on to the user and record it in the journal rather than
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
mkdir -p "$RUN" && cp "$SKILLDIR/journal-template.md" "$JOURNAL"
```

Then bind each level to an account. **The account names are the project's own aimux subscriptions**
— read them from the runtime contract in `docs/00-ai-context.md` and set them here. They are not
role names, and the skill has no defaults to fall back on:

```bash
ACCT_REASONING=<account from docs/00-ai-context.md>
ACCT_IMPLEMENTATION=<account from docs/00-ai-context.md>
ACCT_REVIEW=<account from docs/00-ai-context.md, or the reasoning account>

for a in "$ACCT_REASONING" "$ACCT_IMPLEMENTATION" "$ACCT_REVIEW"; do
  [ -d "$HOME/.aimux/profiles/$a" ] && printf 'ok       %s\n' "$a" || printf 'MISSING  %s\n' "$a"
done
```

Any `MISSING` line means that level will run on the logged-in account and its cost will not be
separated. Report it before dispatching rather than discovering it in the usage report weeks later.
Which subscription fills which level is the project's decision — one account may fill several
levels, and any account may fill any level.

Every dispatch goes through `$SKILLDIR/dispatch.sh`, which takes its instructions from
`$SKILLDIR/prompts/`. **Do not read the prompt files** — keeping roughly a thousand words of
instruction text out of your context is the point of them living in files. You fill their
placeholders with `--var` and never see the rest.

The script also sets sandbox and approval policy together, reports a fallback when an aimux account
is missing instead of silently landing on the logged-in account, and prints the report's
line count against its budget so you know whether a report fits before opening it. Calling `codex`
directly loses all four.

The journal is committed; `docs/plans/.runs/` is local scratch and belongs in `.gitignore`.

**Update the journal after every step, before the next dispatch.** It is the only place the flow's
state exists — your context is not state, it disappears at a usage limit or a session boundary. A
correctly kept journal means any CLI, including another one under another account, can answer
"where are we?" by reading ~30 lines and continue from there.

## Step 1 — Dispatch the plan

Do not read the project's documents or code beyond what you need to state the task. Let Reasoning
read what it needs — that is the context you are not paying for twice.

```bash
"$SKILLDIR/dispatch.sh" --account "$ACCT_REASONING" --mode read-only \
  --prompt-file "$SKILLDIR/prompts/1-plan.txt" \
  --var TASK="<one or two sentences: what should be true when this is done>" \
  --var PLAN_TEMPLATE="$SKILLDIR/plan-template.md" \
  --var DATE="$(date +%F)" \
  --out "$PLAN" --max-lines 200
```

`TASK` is the only thing you contribute here, so make it carry the intent — the plan is only as good
as this sentence. Build nothing in this step.

## Step 2 — Dispatch a critique of the plan

A fresh, stateless invocation reading the plan cold against the code. It runs under the account the
contract binds to Review — a different subscription from the one that drafted the plan, which
removes the blind spot of a level reviewing itself. If that account does not exist, the fallback to
the Reasoning account handles it and says
so on stdout: then it is a self-review that catches wrong paths and invented functions reliably but
shares whatever judgment blind spots the drafting level has. Record the fallback in the journal.

```bash
"$SKILLDIR/dispatch.sh" --account "$ACCT_REVIEW" --fallback "$ACCT_REASONING" --mode read-only \
  --prompt-file "$SKILLDIR/prompts/2-review.txt" --var PLAN="$PLAN" \
  --out "$RUN/review.md" --max-lines 40
```

The command prints `budget=within budget (n/40)` or `OVER BUDGET`. If it is over, read the first 40
lines only and note the truncation in the journal.

## Step 3 — Revise, then stop

Write the objections you agree with into the plan yourself — a bounded edit, unlike reading source
docs or diffs. Briefly justify the ones you dismiss; silent dismissal hides that the review happened.

Show the user: the goal, `Included` / `Excluded`, all `BLOCKING` questions, and what the review
changed.

**Stop here** unless `Gate profile` is `unattended` and the scope was approved in advance. Approving
scope before code exists is the entire point. Blocking questions are answered by the user — not by
you, and not by Reasoning. On go-ahead, set `Status: Approved` — not before; the field records a
decision, not an expectation.

## Step 4 — Dispatch the build

Commit the plan and journal first, so it is visible which version was built. Record the commit SHA
in the journal — step 5 diffs against it.

Run in the background with a sentinel, never in the foreground: a build routinely exceeds the
foreground timeout and a killed process leaves half the change on disk.
`dispatch.sh --background` detaches the child with `nohup`; a log that remains empty and has no
sentinel after the PID is gone is still a wrapper failure, not a successful build.

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
read-only levels keep the default and the account's stored configuration is untouched.

```bash
build_env_args=
[ -f .agents/build-env.sh ] && build_env_args='--env-file .agents/build-env.sh'
[ -f .agents/build-env.local.sh ] && build_env_args='--env-file .agents/build-env.local.sh'

"$SKILLDIR/dispatch.sh" --account "$ACCT_IMPLEMENTATION" --mode workspace-write --background --network \
  $build_env_args \
  --prompt-file "$SKILLDIR/prompts/4-build.txt" --var PLAN="$PLAN" \
  --log "$RUN/build.log"
```

The sandbox still confines writes to the workspace. Network access widens what the build can reach,
not what it can overwrite, which is why it is granted per dispatch rather than stored on the
account.

The command returns immediately and prints the PID and the sentinel path. Write both in the journal.

Poll the sentinel, not the log. Read `tail -30 "$RUN/build.log"` only when the exit code is
non-zero. Tailing a running build is the unbounded read this workflow exists to avoid.

Because the sentinel is a file, a build survives you: if your session hits a usage limit while it
runs, the build finishes anyway and whoever resumes reads the exit code.

### Wait for the build — do not end your turn

The dispatch returns immediately; the build does not. Waiting is your job, not the user's. Run the
wait as one bounded blocking call and let it return on its own:

```bash
BUILD_PID=<pid printed by the dispatch>
deadline=$(( $(date +%s) + 3600 ))
while [ ! -f "$RUN/build.exit" ] && [ "$(date +%s)" -lt "$deadline" ]; do sleep 20; done

if [ -f "$RUN/build.exit" ]; then
  printf 'BUILD finished exit=%s\n' "$(cat "$RUN/build.exit")"
elif kill -0 "$BUILD_PID" 2>/dev/null; then
  printf 'BUILD still running after 60 min, pid %s alive\n' "$BUILD_PID"
else
  printf 'BUILD process gone, no sentinel written\n'
fi
```

Three outcomes, three different actions. A sentinel means go to step 5. Still alive means report the
elapsed time and wait again — a long build is not a stuck build. **Gone with no sentinel means the
process was killed** before it could write an exit code: say so and stop, because the working tree
now holds a partial build that no exit code describes. Without the `kill -0` check that case is
indistinguishable from a slow build, and waiting on it is waiting forever.

**Never end your turn with a dispatch in flight.** "I will report back when it finishes" is not a
mechanism — nothing wakes you up, so the run stalls until the user thinks to ask, which is precisely
the interruption this workflow exists to spare them. If your runtime genuinely cannot block for the
wait, do not pretend to watch: say you are stopping, and give the user the exact sentinel command to
run so they can restart you with the answer.

### If Implementation stops because the plan is wrong

Implementation owns execution, not diagnosis of scope. When it stops because the approved plan is
internally inconsistent, omits a file authorization needed by another step, cites a missing document,
or forbids the only bounded change that satisfies the plan, do not hand the problem back as an open
choice.

Classify it as a scope correction. Propose the smallest concrete plan edit that resolves the
contradiction, explain why it changes scope, and stop for scope approval. After approval, patch the
plan yourself, update the journal with the approved correction, and re-dispatch Implementation.

Keep the correction narrow. It may authorize the minimum file, query, command, or document handling
needed to make the existing plan coherent. It may not change a requirement, ADR, runtime baseline,
excluded area, or product behavior without presenting that as a blocking scope question. If partial
work already exists, state whether it falls inside the corrected scope; do not revert or bless it
silently.

### If a dispatched call hits a usage limit mid-run

Stop, write it in the journal, report to the user. `aimux handoff <sessionId> --to <account>` can
continue the same session under another account via a lossy summary — re-check its grasp of scope
and Definition of Done before trusting it unattended. Untested end-to-end here; if it misbehaves,
stop and report rather than improvising a fix mid-build.

## Step 5 — Dispatch verification against the plan

Do not read the diff yourself.

```bash
"$SKILLDIR/dispatch.sh" --account "$ACCT_REASONING" --mode read-only \
  --prompt-file "$SKILLDIR/prompts/5-verification.txt" \
  --var PLAN="$PLAN" --var SHA="<approval SHA from the journal>" \
  --var BUILD_LOG="$RUN/build.log" \
  --out "$RUN/verification.md"
```

Report it to the user: what is done, what is not, and what was built outside `Included`. You may spot-check
a single hunk for a high-risk change or a report that looks wrong — a judgment call, not the
default.

**Do not finish the build yourself if Implementation stopped.** Report why and let the user decide.
Taking over is the silent failure that makes the whole workflow pointless.

## Step 6 — Commit

Never leave the build uncommitted — a dirty tree blocks the next round and erases the boundary
between this round's changes and the next.

Under `interactive`, propose the commit and wait. Under `semi-automatic` and `unattended`, commit and
report. If the project follows Clarity Framework commit discipline, affected `docs/` files go in the
same commit. If more rounds are needed, the plan and journal stay until everything is built.

## Step 7 — Gate before merge

The build is committed, not approved. Ask outright whether it may be merged, using the step 5 report
to make the question answerable: which conditions are met, which are not, what you are unsure about.
This gate holds in every profile. Never approve on the user's behalf.

If the gate fails, the plan stays and the flow returns to step 4 with what remains.

If the gate passes, the merge is a separate, explicit transition: the user performs it through the
project's normal workflow, or explicitly authorizes an agent to do it. Record the merge commit in
the journal and verify that it contains the build commit. For a direct-to-main workflow, record that
no merge was required. Do not enter step 8 until one of those states is recorded.

## Step 8 — Close out

After the merge transition recorded in step 7, go through the plan's **Vid avslut** section with
the user. The answers drive real changes: if an architectural decision belongs in
`docs/03-sad.md`, write it there now. "Nothing" is
a valid answer to every question, but do not skip a question because the answer seems obvious —
this is the last point where the lesson still exists.

Then delete the plan and its journal in their own commit, and remove `$RUN`. `plan-template.md` and
`journal-template.md` stay in the skill directory — they are templates, not artifacts.

## Resuming an interrupted run

If you are picking up a run you did not start — a new session, or another CLI taking over at a usage
limit — read `docs/plans/*.run.md` and nothing else. It tells you the last completed step, whether a
build is still running, and where the reports are. Continue from the next step. Do not re-dispatch a
step the journal records as done, and do not reconstruct context by reading code.

## Notes

- The four runtime levels may be assigned to one or more agents. The point is not fewer total tokens — it is keeping your session
  small and moving the expensive reading onto accounts you are not metered against. For a change the
  user can review in five minutes this is not worth it; say so instead of running it.
- To swap tools, only `dispatch.sh` and `prompts/` change. The levels, plan, journal, budget and
  gates are tool-independent. `docs/00-ai-context.md` records which CLI and account fills each level.
- The rationale behind all of this — why cost separation and not just context isolation, why the
  gates sit where they do — is in the framework's `ai-usage-guide.md` § 5. It is not needed to run
  the workflow, which is why it is not here.
- This file is the shared procedure for both orchestrators. Claude Code discovers the copy under
  `.claude/skills/` and invokes `/plan-driven-build`; Codex discovers the copy under `.agents/skills/`
  and invokes `$plan-driven-build` or selects it through `/skills`. No separate custom-prompt frontend
  is needed. The journal is how a run continues when the first orchestrator hits a usage limit.
