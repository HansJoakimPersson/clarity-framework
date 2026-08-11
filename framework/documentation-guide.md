# The Clarity Framework Documentation Guide

## Clarity Framework v2.0.5

Documentation should make decisions easier, not create bureaucracy. Use the smallest coherent set of
documents that lets the people and agents working on the product make safe, consistent decisions.

## 1. Core principles

1. **Just enough documentation.** Every document must earn its maintenance cost.
2. **Documentation as code.** Keep documents in Git, review them with changes, and keep them close to
   the implementation they describe.
3. **Clarity over completeness.** A clear partial document is more useful than an unclear complete one.

Documents are living contracts. Update them when reality changes; do not preserve a known falsehood
because it was once written down.

## 2. Choose the smallest useful set

| Project | Required | Add when relevant |
| --- | --- | --- |
| Personal or hobby | Vision & Scope, README | Visual Profile before UI work; AI Context when agents are used |
| Launch-bound side project | Vision & Scope, Requirements, SAD, Test Documentation, README | Data/API, Deployment, Runbook, Visual Profile, Change Management |
| Small team | Vision & Scope, Requirements, SAD, Test Documentation, Change Management | Data/API, Deployment, Runbook, Visual Profile |
| Larger team | Vision & Scope, Requirements, SAD, Test Documentation, Change Management | Data/API, Deployment, Runbook, Visual Profile, stricter release controls |

Do not add a document because a template exists. Add it when the project has the corresponding risk,
decision, interface, or operational responsibility.

## 3. Document hierarchy and lifecycle

```text
00 AI Context (optional, continuously updated)
        ↕
01 Vision & Scope (approved before detailed work)
        ↓
02 Requirements (functional requirements and NFRs)
        ↓
03 SAD (architecture based on the NFRs)
        ↓
04 Data Model & API (contract-first interfaces)
        ↓
05 Deployment View (infrastructure and delivery)
        ↓
06 Test Documentation (strategy and evidence)
        ↓
07 Runbook (operation and recovery)
        ↓
08 Change Management (releases, ADRs, and technical debt)
        ↘
09 Visual Profile (required when the product has a visual UI)
```

The order is a default, not a bureaucratic gate. A small project may keep later documents short, but
it must not hide decisions that affect users, operations, security, or other contributors.

## 4. Vision & Scope

Vision & Scope answers why the product exists, who it serves, which problem it solves, and what is
explicitly outside the product. It is the first document to approve.

Include:

- product vision and problem statement;
- target users and stakeholders;
- measurable goals and success criteria;
- in-scope and out-of-scope capabilities;
- assumptions, external dependencies, risks, and constraints;
- approval by the product and technical owners.

Do not turn it into a solution design. The document defines the problem and boundaries; the SAD
defines the architecture.

## 5. Requirements

Requirements Documentation captures what the system must do and under which conditions. Define NFRs
before detailed functional requirements because NFRs shape the architecture.

Record measurable targets for performance, availability, scalability, maintainability, security,
portability, and any domain-specific quality. Use user stories for ordinary behavior:

```text
As a [role], I want [function], so that [business value].
```

Every story needs a unique ID, priority, and acceptance criteria. Use Given/When/Then for behavior
that benefits from explicit conditions. Use a Use Case when several actors, systems, or failure
paths make a story too small to describe the flow.

Maintain traceability from requirements to architecture and tests. Priorities are decisions, not
technical facts; record the business owner of those decisions.

## 6. System Architecture Document (SAD)

The SAD describes the system at the level required for a new contributor to understand the whole and
make local decisions that fit it. It is not a catalogue of every class or function.

Cover:

- context and external systems;
- containers or major components and their responsibilities;
- data flows and important boundaries;
- deployment-relevant topology;
- quality attributes and the tactics that satisfy them;
- key decisions and rejected alternatives;
- security, observability, and failure behavior.

Connect each important NFR to an architectural tactic. Update the SAD when a decision changes a
boundary, dependency, data flow, security property, or operational responsibility.

## 7. Data Model & API Contract

Use contract-first design for persistent data and external interfaces. Describe the domain model,
physical schema, migrations, authentication, endpoints, request/response examples, errors, and
compatibility/versioning strategy.

Keep the versioned OpenAPI file as the canonical HTTP contract when the project exposes an API.
Schema and migration files belong in Git. Define the contract before implementation and review
breaking changes explicitly.

## 8. Deployment View

The Deployment View explains how the product is built, configured, delivered, observed, rolled back,
and secured in each environment. Document the environment matrix, infrastructure diagram, containers,
configuration and secrets, CI/CD workflows, release strategy, health checks, monitoring, and rollback.

Never commit secrets. Use environment variables or a secrets manager, document required names and
ownership, and keep production access narrower than development access.

Every production release must be traceable to one version and commit across the Git tag, release,
artifact, and deployment. Deployments must be safe to retry and must have a documented rollback path.

## 9. Test Documentation

Test Documentation defines how the project earns confidence. It should describe the test pyramid,
unit/integration/end-to-end responsibilities, test data, environments, coverage expectations, and
the Definition of Done.

For every UI change, include rendered visual evidence from the running product. State the device or
browser, viewport, date, changed journey, and inspected states. Check responsive layout, typography,
spacing, overflow, focus, keyboard navigation, contrast, loading, empty, error, success, and disabled
states as relevant. Automated tests, snapshots, and accessibility scans support but do not replace
human inspection of the rendered experience.

Tests should cover negative, boundary, and recovery paths where behavior, security, validation, or
operations are affected. A skipped test needs a reason, owner, and follow-up condition.

## 10. Runbook

The Runbook is for the person operating the product under pressure. Include prerequisites, deployment,
configuration, health checks, logs and dashboards, routine maintenance, backups, restore procedures,
incident response, rollback, and escalation.

Write commands that can be executed, not vague advice. State expected output, required permissions,
and the point at which the operator must stop and escalate. Test the restore path; an undocumented
backup is not a recovery plan.

## 11. Change Management and technical debt

Record releases, superseded decisions, incidents, and deliberate technical debt. Link each item to
the relevant issue, story, ADR, commit, release, or post-mortem.

Use ADRs for decisions that affect architecture, interfaces, security, operations, or future change
cost. Do not delete superseded ADRs; mark them superseded and preserve the reasoning.

## 12. Visual Profile & Design Tokens

The Visual Profile is required for a visual interface. It documents brand foundations, color,
typography, spacing, radii, shadows, motion, iconography, accessibility targets, and token ownership.
Store design tokens in the project's chosen DTCG-compatible source file and treat it as the source of
truth. Generated platform files must not be edited manually.

Before UI implementation, approve the visual profile. After every meaningful UI change, inspect the
running product at supported viewport sizes and states, attach screenshots or equivalent evidence,
and have a human review visual differences. A successful build is not visual validation.

## 13. AI-assisted work

Agents are governed contributors, not decision owners. Use `00-ai-context.md` as the compact starting
point, keep durable state in project files, and use the four-level runtime contract when work is
split across agents:

1. Orchestrator
2. Reasoning
3. Review (optional)
4. Implementation

The plan-driven workflow uses explicit scope, report budgets, account separation, a committed run
journal, and human gates for scope, merge, release, and plan deletion. See `ai-usage-guide.md` and
`skills/plan-driven-build/` for the executable procedure.

## 14. Definition of Done checklist

- Vision and scope are approved.
- Requirements and NFRs are measurable and traceable.
- Architecture reflects the requirements and approved decisions.
- Data/API contracts are versioned and compatible.
- Deployment, secrets, health checks, and rollback are documented.
- Automated tests and relevant negative paths pass.
- UI changes include rendered visual and accessibility evidence.
- Operational and change-management documents are updated when affected.
- No unexplained placeholders or stale decisions remain in the changed scope.

---

*Clarity Framework v2.0.5 – Documentation Guide*
