---
name: planstyrt-bygge
description: Plan-driven workflow where an orchestrator dispatches planning, critique, build and diff verification to other CLIs or accounts, keeping its own context and token spend bounded. Use when a task is large enough that its scope needs approval before code is written.
---

# Plan-Driven Build (planstyrt-bygge)

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

Setup — profiles, sandbox and approval flags, permission allowlist — is in `uppsattning.md`.
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

If the plan sets a `Rapportbudget` other than the default, pass it to `--max-lines` instead.

You may **not** read: `git diff`, source files, the full build log, the prompt files, or a report
that exceeds its budget — truncate it and say you did. If you find yourself reading the codebase
"to be sure", the workflow has already failed; say so rather than continue.

## Gate profiles

The plan's `Grindprofil` field decides where you stop. Default is `interaktiv`.

| Profile | Stops at |
| --- | --- |
| `interaktiv` | Step 3 (scope), 6 (commit), 7 (merge), 8 (closeout) |
| `halvautomatisk` | Step 3 and 7. Commit happens automatically, closeout is proposed |
| `obevakad` | Step 7 only. Requires every Definition of Done condition to be command-checkable |

A profile never removes the merge gate. You never approve on the user's behalf.

## Prerequisites

Check, and if anything is missing: report it and stop.

- `command -v codex` and `AGENTS.md` in the project root.
- `git status --porcelain` is empty and you are on the right branch. Implementation writes straight
  into the working tree; if it is dirty you can no longer tell its changes from what was there.
  Report what is uncommitted and let the user decide — never commit, stash or reset for them.
- `aimux profile list` shows profiles for the levels. Without them cost is not separated, only
  context. `dispatch.sh` detects this and prints a `FALLBACK:` line — pass it on to the user and
  record it in the journal rather than letting it scroll past.

Templates: `plan-mall.md` and `kor-mall.md` in this skill's directory. Copy them, never edit them in
place. Do not look for `templates/` — that path exists in the framework repo, not in projects.

## Step 0 — Open the run journal

Set the identifiers once and reuse them:

```bash
ID=YYYY-MM-DD-short-name
SKILLDIR=.claude/skills/planstyrt-bygge
PLAN=docs/plans/$ID.md
JOURNAL=docs/plans/$ID.run.md
RUN=docs/plans/.runs/$ID
mkdir -p "$RUN" && cp "$SKILLDIR/kor-mall.md" "$JOURNAL"
```

Every dispatch goes through `$SKILLDIR/dispatch.sh`, which takes its instructions from
`$SKILLDIR/prompts/`. **Do not read the prompt files** — keeping roughly a thousand words of
instruction text out of your context is the point of them living in files. You fill their
placeholders with `--var` and never see the rest.

The script also sets sandbox and approval policy together, reports a fallback when an account
profile is missing instead of silently landing on the logged-in account, and prints the report's
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
"$SKILLDIR/dispatch.sh" --profile reasoning --mode read-only \
  --prompt-file "$SKILLDIR/prompts/1-plan.txt" \
  --var TASK="<one or two sentences: what should be true when this is done>" \
  --var DATE="$(date +%F)" \
  --out "$PLAN" --max-lines 200
```

`TASK` is the only thing you contribute here, so make it carry the intent — the plan is only as good
as this sentence. Build nothing in this step.

## Step 2 — Dispatch a critique of the plan

A fresh, stateless invocation reading the plan cold against the code. It runs under the `granskning`
profile — a different account from the one that drafted the plan, which removes the blind spot of a
level reviewing itself. If that profile does not exist, `--fallback reasoning` handles it and says
so on stdout: then it is a self-review that catches wrong paths and invented functions reliably but
shares whatever judgment blind spots the drafting level has. Record the fallback in the journal.

```bash
"$SKILLDIR/dispatch.sh" --profile granskning --fallback reasoning --mode read-only \
  --prompt-file "$SKILLDIR/prompts/2-kritik.txt" --var PLAN="$PLAN" \
  --out "$RUN/kritik.md" --max-lines 40
```

The command prints `budget=within budget (n/40)` or `OVER BUDGET`. If it is over, read the first 40
lines only and note the truncation in the journal.

## Step 3 — Revise, then stop

Write the objections you agree with into the plan yourself — a bounded edit, unlike reading source
docs or diffs. Briefly justify the ones you dismiss; silent dismissal hides that the review happened.

Show the user: the goal, `Ingår` / `Ingår inte`, all `BLOCKERANDE` questions, and what the critique
changed.

**Stop here** unless `Grindprofil` is `obevakad` and the scope was approved in advance. Approving
scope before code exists is the entire point. Blocking questions are answered by the user — not by
you, and not by Reasoning. On go-ahead, set `Status: Godkänd` — not before; the field records a
decision, not an expectation.

## Step 4 — Dispatch the build

Commit the plan and journal first, so it is visible which version was built. Record the commit SHA
in the journal — step 5 diffs against it.

Run in the background with a sentinel, never in the foreground: a build routinely exceeds the
foreground timeout and a killed process leaves half the change on disk.

```bash
"$SKILLDIR/dispatch.sh" --profile implementation --mode workspace-write --background \
  --prompt-file "$SKILLDIR/prompts/4-bygge.txt" --var PLAN="$PLAN" \
  --log "$RUN/bygge.log"
```

The command returns immediately and prints the PID and the sentinel path. Write both in the journal.

Poll the sentinel, not the log: `test -f "$RUN/bygge.exit" && cat "$RUN/bygge.exit"`. Read
`tail -30 "$RUN/bygge.log"` only when the exit code is non-zero. Tailing a running build is the
unbounded read this workflow exists to avoid.

Because the sentinel is a file, a build survives you: if your session hits a usage limit while it
runs, the build finishes anyway and whoever resumes reads the exit code.

### If a dispatched call hits a usage limit mid-run

Stop, write it in the journal, report to the user. `aimux handoff <sessionId> --to <profile>` can
continue the same session under another account via a lossy summary — re-check its grasp of scope
and Definition of Done before trusting it unattended. Untested end-to-end here; if it misbehaves,
stop and report rather than improvising a fix mid-build.

## Step 5 — Dispatch verification against the plan

Do not read the diff yourself.

```bash
"$SKILLDIR/dispatch.sh" --profile reasoning --mode read-only \
  --prompt-file "$SKILLDIR/prompts/5-verifiering.txt" \
  --var PLAN="$PLAN" --var SHA="<approval SHA from the journal>" \
  --out "$RUN/verifiering.md"
```

Report it to the user: what is done, what is not, what was built outside `Ingår`. You may spot-check
a single hunk for a high-risk change or a report that looks wrong — a judgment call, not the
default.

**Do not finish the build yourself if Implementation stopped.** Report why and let the user decide.
Taking over is the silent failure that makes the whole workflow pointless.

## Step 6 — Commit

Never leave the build uncommitted — a dirty tree blocks the next round and erases the boundary
between this round's changes and the next.

Under `interaktiv`, propose the commit and wait. Under `halvautomatisk` and `obevakad`, commit and
report. If the project follows Clarity Framework commit discipline, affected `docs/` files go in the
same commit. If more rounds are needed, the plan and journal stay until everything is built.

## Step 7 — Gate before merge

The build is committed, not approved. Ask outright whether it may be merged, using the step 5 report
to make the question answerable: which conditions are met, which are not, what you are unsure about.
This gate holds in every profile. Never approve on the user's behalf.

If the gate fails, the plan stays and the flow returns to step 4 with what remains.

## Step 8 — Close out

After merge, go through the plan's **Vid avslut** section with the user. The answers drive real
changes: if an architectural decision belongs in `docs/03-sad.md`, write it there now. "Nothing" is
a valid answer to every question, but do not skip a question because the answer seems obvious —
this is the last point where the lesson still exists.

Then delete the plan and its journal in their own commit, and remove `$RUN`. `plan-mall.md` and
`kor-mall.md` stay in the skill directory — they are templates, not artifacts.

## Resuming an interrupted run

If you are picking up a run you did not start — a new session, or another CLI taking over at a usage
limit — read `docs/plans/*.run.md` and nothing else. It tells you the last completed step, whether a
build is still running, and where the reports are. Continue from the next step. Do not re-dispatch a
step the journal records as done, and do not reconstruct context by reading code.

## Notes

- Three agents work on one task. The point is not fewer total tokens — it is keeping your session
  small and moving the expensive reading onto accounts you are not metered against. For a change the
  user can review in five minutes this is not worth it; say so instead of running it.
- To swap tools, only `dispatch.sh` and `prompts/` change. The levels, plan, journal, budget and
  gates are tool-independent. `docs/00-ai-context.md` records which CLI and profile fills each level.
- The rationale behind all of this — why cost separation and not just context isolation, why the
  gates sit where they do — is in the framework's `ai-usage-guide.md` § 5. It is not needed to run
  the workflow, which is why it is not here.
