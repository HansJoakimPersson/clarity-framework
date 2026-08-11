# CHANGELOG

## Clarity Framework

All significant framework changes are recorded here. Releases follow
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/).

## [2.0.5] – Unreleased

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
