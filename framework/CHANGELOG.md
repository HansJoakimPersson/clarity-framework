# CHANGELOG

## Clarity Framework

All significant framework changes are recorded here. Releases follow
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/).

## [3.3.0] – Unreleased

### Fixed

- `setup.md` § "Implementation and the network" used `--account implementation` as its example,
  contradicting § 1's own rule against naming or using a subscription after the level it fills. Now
  reads `--account "$ACCT_IMPLEMENTATION"`, matching `SKILL.md`. The § 4 setup-verification example
  had the same problem with a literal `reasoning` account name; replaced with a placeholder.

### Added

- `dispatch.sh --account` now accepts a comma-separated, priority-ordered pool of aimux accounts
  instead of a single name. Resolved once per dispatch: `read-only` dispatches retry the next
  account in the pool automatically when one fails (side-effect-free, safe to retry);
  `workspace-write` dispatches pick the first account whose profile exists and never retry after
  launch, because a failed build cannot be safely resumed on a different account without knowing
  what it already wrote. Rate-limit detection is unverified — a retry currently fires on any
  non-zero codex exit, which may also retry a genuine task failure. Flagged in the script's own
  header comment.
- `dispatch.sh --model NAME`, passed straight through to codex independent of which account in a
  pool ends up running the dispatch. Lets a pool of otherwise-interchangeable accounts share one
  capability tier instead of requiring each account to carry its own `aimux profile update -m`
  config. The exact codex flag is unverified against the installed CLI version — check
  `codex exec --help` first, per the skill's existing setup convention for unverified flags.
- `tests/dispatch-test.sh`: coverage for pool retry on `read-only` failure, no retry on
  `workspace-write` failure, the logged-in-account fallback message, and `--model` pass-through.

### Changed

- Review no longer requires a different aimux account from Reasoning. What separates them is a
  different prompt file (`prompts/2-review.txt` vs `prompts/1-plan.txt`), not a different
  subscription — the earlier requirement conflated judgment independence with billing separation
  for no real benefit. `SKILL.md`, `setup.md`, and `templates/00-ai-context.md`'s runtime contract
  table updated accordingly; the table also gained a Model column, independent of the account pool
  column.

## [3.2.2] – Unreleased

### Fixed

- `plan-driven-build` now tells the orchestrator how to handle an Implementation stop caused by an
  internally inconsistent plan. It must propose the smallest concrete scope correction, stop for
  approval, patch the plan and journal after approval, and then re-dispatch instead of handing the
  diagnosis back to the user as an open-ended choice.

## [3.2.1] – Unreleased

### Fixed

- `dispatch.sh --background` now starts the build child through `nohup` and writes a
  `DISPATCH child started` marker to the log. Some CLI harnesses can clean up ordinary background
  children when the short-lived wrapper command exits; the symptom is a vanished PID, empty log, and
  no sentinel. The marker makes that failure distinguishable from a build that started and failed.

## [3.2.0] – 2026-08-13

### Added

- `plan-driven-build` now supports an explicit `dispatch.sh --env-file FILE` hook for project-owned
  build environment bootstrap. The dispatcher stays language-agnostic: Java, Node, Go, and other
  toolchains belong in the project's env file, not in the workflow infrastructure.
- Step 4 documents the standard build-env paths, `.agents/build-env.sh` for portable committed
  bootstrap and `.agents/build-env.local.sh` for gitignored machine-specific overrides. The run
  journal now records which env file was used and any environment corrections made during the build.
- `clarity-bootstrap` adds `.agents/build-env.local.sh` to `.gitignore` when `plan-driven-build` is
  selected, matching the new local override convention.
- The build-env guidance now covers workspace-local dependency caches, including Maven
  `maven.repo.local` under `.m2/repository`, so dependency resolution can write inside the sandbox
  without granting access to user-level caches such as `~/.m2`.

### Changed

- Levels are bound to aimux accounts through the project's runtime contract instead of by name.
  `setup.md` previously told projects to create accounts called `reasoning`, `implementation`, and
  `review`, which contradicted the framework's own doctrine that an aimux account selects which
  subscription pays and is not a persona. An account is a subscription; naming one after a level
  collapses the two and makes that subscription unusable for any other level.

  The `Agent / account` column in `templates/00-ai-context.md` is now the mapping. Step 0 of
  `plan-driven-build` reads it into `ACCT_REASONING` / `ACCT_IMPLEMENTATION` / `ACCT_REVIEW`, and
  the dispatch commands pass those variables. Any account may fill any level, one account may fill
  several, and a project may hold any number of subscriptions — changing which one pays for a level
  is an edit to that table and nothing else. `dispatch.sh` is unchanged; it already took
  `--account NAME` generically.

- Step 0 verifies each mapped account's directory exists and prints `ok` or `MISSING` per level,
  replacing a prerequisite that asked the reader to eyeball `aimux profile list`. A level whose
  account is missing runs on the logged-in account with cost unseparated — previously visible only
  as a `FALLBACK:` line per dispatch, which is easy to scroll past and gives no signal until a usage
  report weeks later shows every session attributed to one account.

- The run journal records the account that actually paid for each step, rather than a level name
  that says nothing about which subscription was billed.

- `setup.md` states that spreading load across subscriptions is a change to the mapping between
  runs, not a rotation within one: rotating per dispatch starts every dispatch on a cold prompt
  cache and can land the review on the subscription that drafted the plan.

- `docs/00-ai-context.md` now treats the build environment as part of the AI runtime contract, so a
  project can state both the toolchain bootstrap path and the build-level guard that fails when the
  wrong runtime is active.
- The Java AGENTS starter now calls out build-level Java version enforcement, such as Maven Enforcer,
  as the source of truth when a project has a fixed Java baseline.

## [3.1.0] – Unreleased

### Changed

- The default gate profile is `semi-automatic` instead of `interactive`. A gate belongs where a
  decision is the user's and hard to walk back — scope, before any code exists, and merge, before
  the work reaches the shared branch. A commit inside a round is reversible and touches nobody else,
  so stopping there bought a confirmation rather than a decision. `interactive` stays available for
  unfamiliar or risky work. `templates/plan.md` and its copy state the reasoning.
- `dispatch.sh` takes `--account` rather than `--profile`, and reports `account=` and
  "no aimux account 'implementation'" rather than "no aimux profile". `--profile` is kept as a
  deprecated alias, so existing invocations and the regression test still pass. An aimux account
  selects which subscription pays; naming it a profile suggested a missing behavioral persona and
  collided with both the Codex profile and the plan's gate profile.

### Fixed

- The build dispatch had no waiting mechanism. Step 4 said to poll the sentinel but never said when,
  how often, or that the orchestrator must block — so it announced it was watching, ended its turn,
  and the run stalled until the user asked about it. Step 4 now carries a bounded blocking wait that
  distinguishes three outcomes: sentinel written, process still alive, and process gone without a
  sentinel. The last case is a killed build leaving a partial tree; without the `kill -0` check it
  was indistinguishable from a slow build, so waiting on it never ended.
- The build dispatch could not resolve dependencies. `workspace-write` denies network access by
  default, and `-a never` — which is what stops a background dispatch from hanging on a prompt
  nobody answers — leaves the build no way to ask for it, so any download failed the run. Step 4
  now passes a new `dispatch.sh --network` flag that sets `sandbox_workspace_write.network_access`
  for that single dispatch. The read-only levels keep the default, the account's stored
  configuration is untouched, and the sandbox still confines writes to the workspace. `--network`
  is rejected for any mode other than `workspace-write`.

## [3.0.1] – Unreleased

### Fixed

- `clarity-bootstrap` left a project without version control on first run. The Git decision sat in
  the guardrails, before the questions and before the step 4 approval gate, and produced only a
  report — so the user was asked about documents, starters, and skills but never about Git, and
  learned only at step 6 that `.gitignore` handling, `git check-ignore` verification, and the
  bootstrap commit had all been skipped, leaving the documents unversioned in a framework whose
  second core principle is *documentation as code*.

  Initialization is now a question in step 1, part of the proposal in step 4 with its consequences
  stated, and the first action of step 5, so files land inside the bootstrap commit instead of
  arriving as untracked clutter. Step 6's Git-dependent checks are unconditional again, with a
  single explicit closing note reserved for the one path that still lacks a repository — the user
  declining the recommendation.

  Detection distinguishes three states and compares the toplevel with `-ef` rather than by string,
  so a symlinked repository root is not misread. A directory already inside another repository is
  never initialized again, which would nest one repository in another.

## [3.0.0] – Unreleased

### Breaking changes

- `CLAUDE.md` contains exactly `@AGENTS.md` and nothing else. It is a pointer that lets Claude Code
  load what Codex reads directly; it is no longer the home for project-specific instructions.
- Everything project-specific lives in `docs/`, routed to the document that governs it. `README.md`
  carries the routing table: architecture to `03-sad.md` with ADRs in `08-change-management.md`,
  behavior to `02-requirements.md`, data and interfaces to `04-data-model-api.md`, delivery to
  `05-deployment-view.md`, test rules to `06-test-documentation.md`, operations to `07-runbook.md`,
  visual rules to `09-visual-profile.md`, and everything else to `00-ai-context.md`.
- Precedence changed. It was: session instruction, `CLAUDE.md`, `AGENTS.md`, skill, `docs/`. It is
  now: session instruction, `docs/`, `AGENTS.md`, skill. `CLAUDE.md` is absent because it holds no
  rules.

**Migration.** A project with content in `CLAUDE.md` below the import must move it into the `docs/`
document that governs each rule, then reduce `CLAUDE.md` to the single line. `framework-update`
detects the content, proposes a destination per rule, and reduces the file only after that migration
is approved — it never silently discards a project's rules.

### Added

- A `Project conventions` section in `templates/00-ai-context.md` as the home for agent-facing rules
  that no numbered document covers, kept short and pointing decisions at ADRs.
- An `Ownership` section in `README.md` stating what each of the three files holds, and the same
  division in `framework/documentation-guide.md` §13.

### Changed

- `agents/README.md`, all eight stack starters, `skills/README.md`, both skills, `templates/plan.md`
  with its `plan-driven-build/plan-template.md` copy, and all four dispatch prompts now point at
  `docs/` instead of `CLAUDE.md` for project-specific rules.
- `clarity-bootstrap` and `framework-update` treat project content found in `CLAUDE.md` as
  project-owned: it must be migrated to `docs/` with approval before the file is reduced.

## [2.2.0] – 2026-08-12

### Added

- A sizing rule for plans: one plan is one mergeable increment — the smallest change that can merge
  on its own without leaving the product broken or half-migrated, usually a single user story. The
  rule, its size test, and its lower bound are stated in `templates/plan.md`, its
  `skills/plan-driven-build/plan-template.md` copy, and `framework/ai-usage-guide.md` §9.
  `prompts/1-plan.txt` now instructs the planning level to plan only the first increment when the
  task spans more, and to list the rest under `Excluded` rather than compressing scope by making
  steps vaguer. A milestone is delivered by a sequence of plans; it lives in the story map's release
  slices and in Change Management, not in a plan.

### Fixed

- `skills/plan-driven-build/SKILL.md` step 2 dispatched `--profile granskning`, but `setup.md`
  creates the account as `review`. The review level therefore never found its profile and always
  fell back to `reasoning`, silently defeating the account separation the step exists for.
- `skills/plan-driven-build/SKILL.md` referred to a plan field named `Rapportbudget`; the template
  emits `Report budget`.
- Remaining Swedish placeholders in the `templates/00-ai-context.md` technology-stack table
  (`t.ex.` and `Databas`), missed by the v2.1.0 language sweep.

## [2.1.0] – Unreleased

### Added

- User stories are documented as the unit of product work rather than only a requirement format.
  `templates/02-requirements.md` gains a role table with stable role IDs, an INVEST quality bar with
  behavior-based splitting guidance, a story lifecycle, a Definition of Ready, an epic overview, and
  per-story status, size, and dependency fields.
- Visual requirements views: a Mermaid story-lifecycle state diagram, a Mermaid journey diagram for
  the story-map backbone, a release-slice story-map table, and a Mermaid traceability chain from a
  Vision & Scope goal through epic, story, acceptance criterion, and test case to the release.
- `templates/02-user-stories.md` for projects whose backlog outgrows the requirements document.
  Adopt it past roughly 20 active stories or more than one backlog owner; the roles, quality bar,
  lifecycle, story map, epic overview, priorities, and traceability stay in `02-requirements.md`.
- `templates/plan.md` and its `skills/plan-driven-build/plan-template.md` copy gain a `Delivers`
  field naming the story IDs a plan implements, a requirements row in “Context to read first”, a
  Definition of Done condition citing acceptance criteria by ID, and a closeout question that writes
  story status and traceability back before the plan is deleted. Plans cite story IDs and never copy
  acceptance criteria, because the plan is transient and the requirements document is authoritative.
- Role IDs in `templates/01-vision-scope.md` §3 so that stories name a role defined in scope.

### Fixed

- `skills/plan-driven-build/SKILL.md` looked for a plan field named `Grindprofil` with the profile
  values `interaktiv`, `halvautomatisk`, and `obevakad`, none of which the plan template has emitted
  since v2.0.0. The gate-profile table, the scope gate, and the commit gate now match the template's
  `Gate profile` field and its `interactive` / `semi-automatic` / `unattended` values.
- Swedish text left after the v2.0.0 translation: `Versionshistorik`, `Prioritet`, `Krav`,
  `Kort storytitel`, and `Komponent i SAD` in `templates/02-requirements.md`, and the performance
  NFR row in `templates/00-ai-context.md`.

## [2.0.5] – 2026-08-11

### Changed

- Restored detailed test-documentation guidance, including the test pyramid, traceability matrix,
  visual UX verification records, test data, execution evidence, and exception handling.
- Restored detailed runbook guidance, including operational ownership, lifecycle commands, release
  procedures, backup and restore, troubleshooting, incident response, and smoke tests.

## [2.0.4] – Unreleased

### Changed

- Restored the detailed deployment-view guidance, including infrastructure topology, service
  configuration, secrets, CI/CD stages, release traceability, observability, backups, recovery,
  rollback, and production UX verification.

## [2.0.3] – Unreleased

### Changed

- Restored the detailed data-model and API-contract guidance, including domain relationships,
  physical schema examples, migration strategy, endpoint examples, error registry, and security
  and compatibility rules.

## [2.0.2] – Unreleased

### Changed

- Expanded the README repository tree with descriptions for framework documents, templates, agent
  starters, skills, scripts, tests, and workflow support files.
- Restored the detailed architecture-template guidance, including context, component, data-flow,
  technology-choice, ADR, quality-attribute, and technical-debt sections.

## [2.0.1] – Unreleased

### Changed

- Replaced the AI runtime-model section in `AGENTS.md` with the normative release strategy.

## [2.0.0] – Unreleased

### Breaking changes

- All framework content and file names use English.
- The four-level runtime contract—Orchestrator, Reasoning, Review, and Implementation—is the only
  AI operating model. The former three-step model is removed; no migration mapping is required.
- `aimux` is documented as a multiplexer for separate subscriptions or accounts within one LLM
  provider. It does not create agent personas.
- `docs/.clarity-version` is no longer required. Updates read version markers already present in
  project documents.
- The optional `skills/clarity-bootstrap/agents/openai.yaml` metadata file is removed.
- Swedish framework file names are replaced with English names, including `framework-update`,
  `plan-driven-build`, `requirements`, `data-model-api`, `test-documentation`, `change-management`,
  and `visual-profile`.

### Added

- Required visual UX verification for UI changes, including rendered states, target viewports,
  responsive behavior, accessibility checks, screenshots, and human review.
- English run journals, plan templates, setup documentation, dispatch prompts, and project starters.
- Explicit account separation guidance for agent workflows.

## [1.5.1] – 2026-08-11

### Fixed

- Framework updates allow unrelated dirty source, build, test, and application-configuration paths.
- Update commits use an explicit path list and `git commit --only`.
- Dispatches use stable sentinels, bounded reports, and explicit approval policies.

## [1.5.0] – 2026-08-11

### Added

- `clarity-bootstrap` for need-driven project setup.
- Generic and stack-specific agent starters.
- Plan-driven build regression tests and bounded dispatch reporting.
- The Visual Profile and DTCG design-token guidance for projects with a UI.

### Changed

- Framework-owned files are replaced wholesale; project-owned documents preserve their content.
- Skills are installed identically for Codex and Claude Code.
- API contracts, deployment views, test documentation, runbooks, and change management are linked
  through a consistent numbered document set.

## [1.4.0] – 2026-08-10

### Added

- The plan-driven multi-agent workflow with planning, review, implementation, verification, human
  approval gates, run journals, and bounded orchestrator context.
- Dispatch scripts for sandbox, approval, account selection, background execution, and sentinels.

## [1.3.0] – 2026-08-09

### Added

- Deployment View guidance for environments, CI/CD, release traceability, health checks, monitoring,
  and rollback.
- Test Documentation guidance for unit, integration, end-to-end, and accessibility testing.
- Runbook guidance for deployment, operations, backup, restore, and incident response.

## [1.2.0] – 2026-08-08

### Added

- Data Model & API Contract template with contract-first OpenAPI guidance.
- Requirements template with NFRs, user stories, use cases, MoSCoW priorities, and traceability.
- System Architecture Document template with component, data-flow, quality-attribute, and ADR sections.

## [1.1.0] – 2026-08-07

### Added

- Vision & Scope template.
- AI Context Document template.
- Documentation guide and project instruction template.

## [1.0.0] – 2026-08-06

### Added

- Initial Clarity Framework release with the core principles: just enough documentation,
  documentation as code, and clarity over completeness.
