# AGENTS.md - Generic Application v1.0

Baseline instructions for projects that do not match a more specific Clarity Framework starter.
Project-specific rules belong in `docs/`; keep this framework-owned file unchanged.

## How To Use

- Follow these rules for every task.
- Read build manifests and existing scripts before choosing commands or tools.
- The project's documents in `docs/` take precedence over this file when they disagree.
- Replace this starter with a stack-specific Clarity starter when one becomes available.

## Core Rules

- Deliver the task's full scope without unrelated refactors, renames, formatting churn, or dependency churn.
- Preserve established public behavior and repository conventions unless the task explicitly changes them.
- Never commit secrets, credentials, tokens, personal data, private paths, or production-only configuration.
- Do not add dependencies, services, background jobs, or external integrations without a task-driven reason.
- Keep the project buildable. Stop and report when existing failures or missing prerequisites prevent verification.
- Ask before destructive, irreversible, production-facing, or externally visible actions.

## Workflow

1. Read `AGENTS.md` before starting.
2. In a Clarity project, read `docs/00-ai-context.md` first when it exists. If it is absent, use
   `README.md` and the task-relevant numbered documents. Do not read every document speculatively. Never scan `docs/archive/` unless the task explicitly requires historical evidence.
   Read `docs/03-sad.md` when the change adds or moves a component, crosses a module boundary, or
   you are unsure where it belongs; `docs/09-visual-profile.md` before visual UI work;
   `docs/04-data-model-api.md` before changing data or API contracts; and `docs/07-runbook.md`
   before operational or recovery work.
3. If a plan under `docs/plans/` governs the task, treat its `Included` and `Excluded` sections as
   authoritative for Goal, Included, Excluded, requirements, and documented boundaries. Resolve local,
   reversible implementation gaps from repository evidence and record them; stop only when continuing
   would materially change one of those boundaries.
4. Inspect the relevant code, tests, configuration, and build scripts before proposing changes.
5. Implement the smallest coherent change that satisfies the complete requested behavior.
6. Run the repository's documented targeted checks, then the broader relevant checks when practical.
7. Update Clarity documents in the same change when architecture, requirements, contracts,
   deployment, testing, operations, visual rules, or change history actually changed.

## When You Are a Dispatched Agent

You are dispatched when a plan under `docs/plans/` governs the task or the prompt says its scope is
authoritative.

- Build only what is listed under `Included`; do not implement anything under `Excluded`.
- Resolve local reversible plan gaps inside Goal, Included, requirements, and documented boundaries.
  Stop only when continuing requires a material scope, architecture, security/privacy, cost, or
  irreversible change.
- Do not invoke another CLI as a subprocess. Ignore orchestration skills under `.agents/skills/`
  and `.claude/skills/`; you are the level that performs the assigned work.
- Stay within the requested report budget and include verification outcomes.
- Do not commit unless the orchestrator explicitly tells you to.

## Testing and Verification

- Use the project's existing test framework and commands. Do not invent commands that are absent from the repo.
- Add or update tests for changed behavior when a test surface exists.
- Include negative, boundary, and failure-path coverage when the change affects validation, security, or recovery.
- Never hide a failing test, lower a quality gate, or replace a meaningful dependency with an incompatible fake
  merely to make checks pass.
- If a check cannot run, state why and name the exact command or CI job that still needs to run.

## Definition of Done

- The requested behavior is complete and no out-of-scope behavior was added.
- Relevant tests, linting, type checks, builds, or validation commands pass.
- Security- and data-sensitive paths have appropriate failure handling.
- Public behavior, configuration, and affected Clarity documentation agree.
- No secrets, generated credentials, private machine data, or unrelated changes are included.
- Completion notes state what is done, what was verified, and any remaining uncertainty.
