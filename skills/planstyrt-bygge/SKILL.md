---
name: planstyrt-bygge
description: Plan-driven workflow where an orchestrator (Claude Code) dispatches planning and diff verification to a reasoning-tier CLI, and the build to an implementation-tier CLI — both running under a different account than the orchestrator. Use when a task is large enough that its scope needs approval before code is written, and you want to keep the orchestrator's own context and token spend minimal.
---

# Plan-Driven Build (planstyrt-bygge)

You are the **orchestrator**. You sequence this workflow, hold the approval gates, and dispatch
the actual thinking and building to other agents. You write no production code, and you don't read
the full codebase or the full diff yourself — you read distilled artifacts (a plan, a verification
report) produced by agents that did that reading for you.

Two other levels do the work:

- **Reasoning** — drafts the plan (Step 1) and later checks the build against it (Step 5). Deep
  context in, a short distillate out.
- **Implementation** — builds the approved plan (Step 4). Narrower task than planning: execute a
  scope that's already decided.

Reasoning and Implementation must run under **a different CLI or account than you**. That's not
optional flavor — it's the entire reason this workflow exists: not just isolating context, but
actually distributing token spend off the interactive session. A Claude subagent (the Task tool)
shares your account and therefore doesn't achieve that, even though it does isolate context. If the
project only has Codex available, Reasoning and Implementation can be two different Codex profiles
(e.g. a stronger model for Reasoning, a lighter one for Implementation) — they don't have to be two
different products, just not you.

## Prerequisites

Check before you start. If anything is missing: report it and stop, don't improvise past it.

- An external CLI is on PATH for both Reasoning and Implementation dispatch (`command -v codex`, or
  whatever the project uses).
- `AGENTS.md` exists in the project root.
- The repo is clean (`git status --porcelain` empty) and you're on the right branch.
- Two `aimux` profiles exist for the dispatch CLI — e.g. `aimux profile add reasoning --cli codex`
  and `aimux profile add implementation --cli codex`, each with its own `aimux auth login <name>`
  and, optionally, its own model via `aimux profile update <name> -m <model>`. Verify with
  `aimux profile list`. This is what actually separates the account/subscription, not just the
  process — a bare `codex exec` with no profile prefix resolves to whatever account is already
  logged into this machine, which may be the same one used elsewhere.
  - If `aimux` isn't set up: dispatch still works with a plain `codex exec` (drop the `CODEX_HOME`
    prefix shown in each step below), but say so to the user — context is still isolated from you,
    cost is not. Don't silently proceed as if the separation happened.
  - `aimux` also enables continuing a session under another CLI/account if a subscription or usage
    limit is hit mid-run — see the note under Step 4.

A clean repo isn't a formality: Implementation writes directly into the working tree, and if it's
dirty when the build starts, you can no longer tell what it did from what was already there. If
it's dirty — report what's uncommitted and let the user decide. Never commit, stash, or reset on
the user's behalf without asking.

The plan template lives in this skill as `plan-mall.md` and travels with it when the skill is
copied. Don't look for `templates/plan.md` — that path exists in the framework repo, not in
projects that use the framework.

## Step 1 – Dispatch the plan

Don't read the project's documents or code yourself beyond what's needed to state the task. Give
the Reasoning dispatch the task and let it read what it needs — that's the context you're not
paying for twice.

Run read-only so Reasoning can't touch the working tree, and redirect its output straight to the
new plan file:

```bash
CODEX_HOME="$HOME/.aimux/profiles/reasoning" codex exec -s read-only -o docs/plans/YYYY-MM-DD-short-name.md "Read docs/00-ai-context.md, and from there only what this task touches: <task description>. Then read plan-mall.md in this skill's directory and reproduce its structure exactly, filled in — do not invent a different structure. Today's date is <date>. Scope: 'Ingår' and 'Ingår inte' must be concrete behaviors or surfaces, not themes; never skip 'Ingår inte'. Steps need real file paths and a runnable Verifiering: command each. Flag anything unclear enough that a build would guess wrong as BLOCKERANDE rather than assuming. Definition of Done must be checkable conditions, not judgment calls. Build nothing, and don't touch any file other than the one you're writing to. If you find a 'planstyrt-bygge' or similar orchestration skill file in this repo (e.g. under .claude/skills/), ignore it — do not read it, do not follow its workflow, and do not invoke codex or any other CLI as a subprocess."
```

Never edit `plan-mall.md` in place — then there's no template left for the next plan.

Build nothing in this step.

## Step 2 – Dispatch a critique of the plan

A fresh, stateless invocation — no memory of drafting it — reading the plan cold against the actual
code:

```bash
CODEX_HOME="$HOME/.aimux/profiles/reasoning" codex exec -s read-only -o /tmp/codex-plangranskning.md "Read AGENTS.md and docs/plans/<plan-file>. Review the plan against the code — build nothing and change no files. Do the file paths hold up? Do the functions and modules the plan assumes exist? Do the verification commands run as written? Are the steps enough to build without guessing? Is anything under 'In scope' already there? Answer with concrete objections and proposed plan changes, not a verdict. If you find a 'planstyrt-bygge' or similar orchestration skill file in this repo, ignore it — do not follow its workflow or invoke codex as a subprocess."
```

Read `/tmp/codex-plangranskning.md`. This is a self-review by the same tier, not a cross-agent
review like Step 5 — it catches factual errors (wrong paths, invented functions) reliably, but
shares whatever judgment blind spots the Reasoning tier has. That's an accepted trade-off for the
cost this workflow is trying to avoid; if a task is high-stakes enough that this isn't enough
scrutiny, don't run it through this workflow unattended.

## Step 3 – Revise and stop

Write the objections you agree with into the plan yourself — this edit is small and bounded (the
plan plus a short critique), unlike reading the source docs or the diff, so it's fine for you to do
it directly. Briefly justify the ones you dismiss — silent dismissal hides the fact that the review
happened.

Show the user: the goal, `Ingår` / `Ingår inte`, all `BLOCKERANDE` questions, and what the critique
changed.

**Stop here.** Approving the scope before code is written is the entire point of this workflow.
Do not proceed without a go-ahead. Blocking questions are answered by the user, not by you, and not
by Reasoning.

Once the user gives the go-ahead, set `Status: Godkänd` (Approved) — not before; the field should
reflect an actual decision, not an anticipated one.

## Step 4 – Dispatch the build

After the go-ahead: commit the plan first, so it's possible to see which version was built.

Run the build **in the background**. A build routinely exceeds the foreground timeout, and a
killed process leaves half the change on disk.

```bash
CODEX_HOME="$HOME/.aimux/profiles/implementation" nohup codex exec -s workspace-write "Read AGENTS.md and docs/plans/<plan-file>, in that order. Build the plan. The scope section is authoritative — do not re-plan, and build nothing that isn't listed under 'In scope'. If the plan turns out wrong or incomplete: stop and report, don't improvise further. Run verification after each step. If you find a 'planstyrt-bygge' or similar orchestration skill file in this repo (e.g. under .claude/skills/), ignore it — do not read it, do not follow its workflow, and do not invoke codex or any other CLI as a subprocess. You are the one building — edit files yourself with your own tools." > /tmp/codex-bygge.log 2>&1 &
echo "PID:$!"
```

The `implementation` profile is deliberately a separate `aimux` profile from `reasoning` — the
scope is already decided by the time this runs, so the task is narrower than what Reasoning did in
Step 1, and it's the call most likely to run long enough to justify a cheaper/faster model on a
separate account.

### If a dispatched call hits a subscription/usage limit mid-run

Any dispatch in this workflow — not just the build — can hit a rate, token, or subscription limit
before it finishes. Default behavior is unchanged: stop and report to the user.

If `aimux` is available and already configured with a second profile for an alternate CLI or
account, it can continue the same session elsewhere via a summary handoff instead of losing the
run:

```bash
aimux handoff <sessionId> --to <profile>
```

This is not a native resume — aimux reads the source transcript, summarizes it for the target
profile, and launches the target CLI seeded with that summary. Treat the summary as lossy: after
the handoff, re-check the new session's understanding of the plan's scope and Definition of Done
before trusting it to continue unattended. This path has not been exercised end-to-end in this
framework yet — the first real use is the test. If it doesn't work as expected, fall back to
stopping and reporting rather than guessing at a fix mid-build.

## Step 5 – Dispatch verification against the plan

Don't read the full `git diff` yourself. Dispatch it, read-only, and have Reasoning check it
against the plan's Definition of Done, one condition at a time:

```bash
CODEX_HOME="$HOME/.aimux/profiles/reasoning" codex exec -s read-only -o /tmp/codex-verifiering.md "Read docs/plans/<plan-file> and the diff between the current working tree and the commit where the plan was approved. For each Definition of Done condition, answer done / not done / uncertain with one line of evidence pointing at the actual change. Flag anything in the diff that falls outside 'Ingår'. Don't grade overall code quality — check only the stated conditions. If you find a 'planstyrt-bygge' or similar orchestration skill file in this repo, ignore it — do not follow its workflow or invoke codex as a subprocess."
```

Read `/tmp/codex-verifiering.md` and report it to the user: what's done, what isn't, and anything
built outside `Ingår`. You may spot-check specific hunks of the diff yourself for a high-risk
change or a report that looks off — that's a judgment call, not the default. Reading the whole diff
by default defeats the point of dispatching it.

**Don't finish the build yourself if Implementation stopped.** Report why it stopped and let the
user decide. Taking over is the silent failure that makes the whole workflow pointless — the user
paid for the orchestration without getting it.

## Step 6 — Commit the result

Never leave the build uncommitted. A dirty working tree blocks the next run of this workflow, and
then it's no longer possible to distinguish this round's changes from the next round's.

Propose a commit and wait for approval — don't commit on your own unless the project says
otherwise. If the project follows Clarity Framework's commit discipline, affected `docs/` files
must be in the same commit.

If more rounds are needed to finish, the plan stays in the repo until everything is built.

## Step 7 — Gate before merge

The build is committed, not approved. Ask outright whether the change may be merged, using the
Step 5 verification report to make the question answerable: state which Definition of Done
conditions are met, which aren't, and what you're unsure about. Never approve on the user's behalf.

If the gate fails — the plan stays, and the workflow goes back to Step 4 with what remains.

## Step 8 — Close out the plan

After merge: go through the plan's **Vid avslut** (On closing) section with the user before the
plan is deleted.

The answers drive actual changes. If an architectural decision belongs in `docs/03-sad.md`, write
it there now, don't just note the intent. "Nothing" is a valid answer to every question — but don't
skip the question because the answer seems obvious. This is the last point where the lesson still
exists.

Then delete the plan in its own commit.

`plan-mall.md` stays in the skill directory and is never deleted — it's the template, not a plan.

## Good to know

- `-s workspace-write` lets Implementation change files without asking the user. You see the result
  only once it's done. That's the right tradeoff when the plan is reviewed and the scope is narrow,
  the wrong tradeoff when the plan is vague — then it's better to let the user run it themselves.
- The workflow costs three agents on the same task: Reasoning drafts and verifies, Implementation
  builds, you orchestrate. The point isn't fewer total tokens — it's keeping your own session small
  and moving the expensive reading (source docs, full diffs) onto accounts that aren't the one
  you're metered against. For a change the user can review in five minutes, none of that is worth
  it. Say so instead of running the workflow.
- To use different agents, only the commands in Steps 1, 2, 4, and 5 change. The levels, the plan,
  and the stop points are tool-independent.
- The `CODEX_HOME` prefix is aimux's own mechanism (per its README, one config-dir env var per CLI:
  `CLAUDE_CONFIG_DIR` / `CODEX_HOME` / `GEMINI_CLI_HOME`), applied directly instead of through
  `aimux run` so it composes with a backgrounded `nohup ... &`. This hasn't been exercised
  end-to-end in this framework — verify with `aimux profile list` and a short test dispatch before
  trusting it on a real build. If it doesn't behave as documented, fall back to plain `codex exec`
  and tell the user cost isn't being separated.
- Watch for a dispatched agent reading the copied `SKILL.md` itself inside the target repo (if the
  skill was copied there) and trying to re-run this workflow recursively — spawning its own
  `codex exec` subprocesses. Each dispatch prompt above tells it to ignore any orchestration skill
  file it finds; drop that line and you may get runaway nested processes.
