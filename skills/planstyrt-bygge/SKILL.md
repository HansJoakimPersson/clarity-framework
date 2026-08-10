---
name: planstyrt-bygge
description: Plan-driven workflow where Claude Code writes a plan following Clarity Framework's plan template, has Codex CLI review it against the code, and after approval lets Codex build it. Use when a task is large enough that its scope needs approval before code is written.
---

# Plan-Driven Build (planstyrt-bygge)

You plan and review. **Codex builds.** You write no production code in this workflow.

## Prerequisites

Check before you start. If anything is missing: report it and stop, don't improvise past it.

- `codex` is on PATH (`command -v codex`)
- `AGENTS.md` exists in the project root
- The repo is clean (`git status --porcelain` empty) and you're on the right branch
- Optional: `aimux` on PATH (`command -v aimux`) — if installed and configured with more than
  one profile, it can continue a session under another CLI/account when a subscription or usage
  limit is hit mid-build. See Step 4. Its absence is not a blocker.

A clean repo isn't a formality: Codex writes directly into the working tree, and if it's dirty
when the build starts, you can no longer tell what Codex did from what was already there. If it's
dirty — report what's uncommitted and let the user decide. Never commit, stash, or reset on the
user's behalf without asking.

The plan template lives in this skill as `plan-mall.md` and travels with it when the skill is
copied. Don't look for `templates/plan.md` — that path exists in the framework repo, not in
projects that use the framework.

## Step 1 – Write the plan

Read `docs/00-ai-context.md`, and from there only what the task actually touches.

Copy `plan-mall.md` from this skill directory to `docs/plans/YYYY-MM-DD-short-name.md` and fill in
the copy. Use today's actual date. Never edit the template in place — then there's no template left
for the next plan.

The plan must be buildable by an agent that did not take part in the conversation and cannot ask
the user. That imposes requirements:

- **Scope** — `Ingår` (In scope) and `Ingår inte` (Out of scope) must be concrete behaviors or
  surfaces, not themes. `Ingår inte` is the field that prevents drift; never skip it.
- **Steps** — actual file paths and a runnable `Verifiering:` (Verification:) command per step.
- **Open questions** — if something is unclear enough that the build would guess wrong, mark it
  `BLOCKERANDE` (BLOCKING). Don't assume on the user's behalf.
- **Definition of Done** — checkable conditions, not judgment calls.

Build nothing in this step.

## Step 2 – Have Codex review the plan

Run read-only so Codex can't change the plan it's reviewing:

```bash
codex exec -s read-only -o /tmp/codex-plangranskning.md "Read AGENTS.md and docs/plans/<plan-file>. Review the plan against the code — build nothing and change no files. Do the file paths hold up? Do the functions and modules the plan assumes exist? Do the verification commands run as written? Are the steps enough to build without guessing? Is anything under 'In scope' already there? Answer with concrete objections and proposed plan changes, not a verdict."
```

Read `/tmp/codex-plangranskning.md`.

## Step 3 – Revise and stop

Write the objections you agree with into the plan. Briefly justify the ones you dismiss — silent
dismissal hides the fact that the review happened.

Set `Status: Godkänd` (Approved).

Show the user: the goal, `Ingår` / `Ingår inte`, all `BLOCKERANDE` questions, and what the review
changed.

**Stop here.** Approving the scope before code is written is the entire point of this workflow.
Do not proceed without a go-ahead. Blocking questions are answered by the user, not by you.

## Step 4 – Have Codex build

After the go-ahead: commit the plan first, so it's possible to see which version was built.

Run the build **in the background**. A build routinely exceeds the foreground timeout, and a
killed Codex process leaves half the change on disk.

```bash
codex exec -s workspace-write "Read AGENTS.md and docs/plans/<plan-file>, in that order. Build the plan. The scope section is authoritative — do not re-plan, and build nothing that isn't listed under 'In scope'. If the plan turns out wrong or incomplete: stop and report, don't improvise further. Run verification after each step."
```

### If the build hits a subscription/usage limit mid-run

Codex or Claude may hit a rate, token, or subscription limit before the build finishes. Default
behavior is unchanged: stop and report to the user, as in Step 5.

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

## Step 5 – Review the diff against the plan

Read `git diff` and compare it to the plan's Definition of Done, one condition at a time.

Report what's done and what isn't. Point out anything Codex built that falls outside `Ingår`.

**Don't finish the build yourself if Codex stopped.** Report why it stopped and let the user
decide. Taking over is the silent failure that makes the whole workflow pointless — the user paid
for the orchestration without getting it.

## Step 6 — Commit the result

Never leave the build uncommitted. A dirty working tree blocks the next run of this workflow, and
then it's no longer possible to distinguish this round's changes from the next round's.

Propose a commit and wait for approval — don't commit on your own unless the project says
otherwise. If the project follows Clarity Framework's commit discipline, affected `docs/` files
must be in the same commit.

If more rounds are needed to finish, the plan stays in the repo until everything is built.

## Step 7 — Gate before merge

The build is committed, not approved. Ask outright whether the change may be merged, and make the
question answerable: state which Definition of Done conditions are met, which aren't, and what
you're unsure about. Never approve on the user's behalf.

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

- `-s workspace-write` lets Codex change files without asking the user. You see the result only
  once it's done. That's the right tradeoff when the plan is reviewed and the scope is narrow, the
  wrong tradeoff when the plan is vague — then it's better to let the user run Codex themselves.
- The workflow costs two models on the same task plus your review. For a change the user can
  review in five minutes, it isn't worth it. Say so instead of running the workflow.
- To use a different build agent, only the command in Step 2 and Step 4 changes. The roles, the
  plan, and the stop point are tool-independent.
