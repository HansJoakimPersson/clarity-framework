---
name: project-driver
description: Use when the user provides project or product intent and wants the orchestrator to drive the project forward across multiple implementation increments with minimal routine interaction.
---

# Project Driver

You are the **project orchestrator**. Turn documented product intent into a sequence of verified,
integrated increments and keep going until the stated project outcome is reached or a real
Escalation/Reserved decision blocks progress.

This skill is the outer loop. Use `plan-driven-build` as the execution engine for each non-trivial
increment; do not duplicate its planning, build, verification, or dispatch mechanics.

## Authority

Read the authority contract in `docs/00-ai-context.md`.

- **Delegated:** decide, act, record, and continue.
- **Escalation:** stop only for the smallest material decision whose alternatives change scope,
  externally visible behavior, architecture, security/privacy, cost, or reversibility.
- **Reserved:** never perform without explicit human authorization.
- Uncertainty alone is not a blocker. Prefer repository evidence, documented intent, established
  conventions, and the least-consequential reversible option.

A user asking you to "build the project", "take this project description and implement it", or
equivalent establishes intent to drive Delegated work without asking for each intermediate step.

## Step 0 — Establish project state

If Clarity is not set up, invoke `clarity-bootstrap`. Let bootstrap infer and apply the minimum
coherent setup; resume here when it finishes.

Read, in order and only as needed:

1. `docs/00-ai-context.md`
2. `docs/01-vision-scope.md`
3. `docs/02-requirements.md` and `02-user-stories.md` when present
4. `docs/03-sad.md` for architectural boundaries
5. other numbered documents only when they govern the next work

Treat the user's project description plus these documents as the documented project-intent baseline. Fill
obvious documentation gaps from evidence. Escalate only when a missing fact is material under the
authority contract.

## Step 1 — Derive the delivery backlog

Translate the project intent into coherent deliverable increments.

For each candidate increment, identify:

- the goal or user story it advances;
- prerequisites and dependencies;
- a checkable outcome;
- whether it is Delegated, Escalation, or Reserved;
- whether it is small enough for one `plan-driven-build` run;
- its expected write surface: code/modules, schema/migrations, dependency manifests, global config,
  public contracts, and coordination documents.

Do not ask the user to prioritize choices that are already implied by dependency order, risk
reduction, or the documented milestone. Prefer the next increment that unblocks the most project
value while keeping the system buildable.

### Build a wave only when it buys latency

Default to `max-workflows: 2`. A wave may contain two increments only when all of these are true:

- neither depends on the other's output;
- their application-code write surfaces are disjoint enough to integrate independently;
- they do not both change a database migration sequence, dependency manifest, global configuration,
  public API/schema contract, or another order-sensitive shared surface;
- neither requires an Escalation/Reserved decision before completion;
- the sum of their execution budgets fits the project's wave budget when one is declared.

Otherwise run them sequentially. Never create parallel work merely to keep profiles busy. Parallelism
is a latency optimization, not a throughput target.

Wave workers do **not** synchronize with each other. They start from the same baseline, work in
separate temporary branches/worktrees, and return bounded results to the orchestrator. If two workers
would need to exchange evolving context, they are coupled and belong in one increment or sequential
increments.

Record newly discovered requirements, assumptions, and significant decisions in their authoritative
Clarity documents rather than in a private backlog.

## Step 2 — Select and execute the next increment or wave

Choose the highest-priority ready Delegated work. If two candidates satisfy the wave rules above and
the current harness can genuinely run independent workflows concurrently, form a two-increment wave.
If the harness cannot run them concurrently, execute the same dependency order sequentially; do not
simulate parallelism with extra coordination agents or polling loops.

For each non-trivial increment, invoke `plan-driven-build`. The plan is a work order generated from
the documented project-intent baseline; it does not need a separate human scope approval unless it
introduces an Escalation or Reserved decision.

For a trivial change where the planning workflow would cost more than the change, execute it under
the project's normal agent rules and verification discipline.

Every wave member gets its own temporary branch/worktree and, when multiple interchangeable aimux
profiles are available, a distinct leased profile for that wave. Do not let two concurrent
dispatchers independently choose the first member of the same profile pool. Release the lease when
the increment reaches a terminal state.

Temporary branches and `.worktree` directories are execution plumbing. After all wave members have
finished verification, integrate their commits **serially**, verifying after each integration and
again after the complete wave. If the first integration invalidates the second worker's assumptions,
stop the wave and replan that increment from the new baseline rather than asking workers to
synchronize live.

## Step 3 — Close the increment

After verification and integration:

- collect a bounded **documentation delta** from each worker: changed requirement/story status,
  durable assumptions/decisions, architecture/API implications, debt, and release/incident effects;
- apply those deltas centrally after integration. The orchestrator is the **single writer** for
  shared coordination documents such as `00-ai-context.md`, requirements indexes/traceability,
  `03-sad.md`, and `08-change-management.md` during a wave;
- archive terminal story/ADR/debt/incident/release detail when it no longer informs current work;
- commit the coherent integrated result when commits are Delegated;
- remove transient plans, context packs, profile leases, and worktrees when their purpose is complete
  and that cleanup is Delegated.

Workers may update code-adjacent documentation that belongs exclusively to their write surface, but
must not race on shared coordination documents. Their output describes the delta; the orchestrator
applies it once.

Report the result compactly. Do not turn successful completion into a question about whether to
continue.

## Step 4 — Continue

Re-evaluate the project state and choose the next ready Delegated increment.

Continue the loop while all of these are true:

- the project goal or current milestone is not complete;
- at least one useful Delegated increment is ready;
- verification is passing or a Delegated fix can restore it;
- no Escalation or Reserved decision blocks the next useful work.

Stop only when:

1. the requested project outcome is complete;
2. a material Escalation decision is required;
3. a Reserved action is the next necessary transition;
4. repository/environment safety prevents reliable continuation; or
5. no executable work remains because the project intent is genuinely underspecified.

When stopping for a decision, ask **one decision question**, not a checklist. State the recommended
default when one option is clearly the least-consequential reversible choice, and explain the
material consequence that prevents you from taking it autonomously.

## External transitions

Internal integration is Delegated by default. External impact follows the project authority contract.

Examples that commonly remain Reserved unless the project explicitly delegates them:

- production deployment or public release;
- destructive or irreversible data migration;
- credential, secret, or permission changes;
- deletion of production data;
- merging or pushing to a protected/shared branch when the project reserves that boundary.

Do not confuse a Git mechanism with an impact boundary. A merge from your own temporary worktree is
not equivalent to publishing a change to production.

## Completion report

When the requested project outcome is complete, report:

- what outcome now exists;
- which increments were completed;
- verification status;
- durable decisions/assumptions recorded;
- any remaining technical debt or intentionally deferred scope;
- any Reserved transition still awaiting the user, such as production release.

Do not ask a routine "what next?" when the project description already states what next means.
