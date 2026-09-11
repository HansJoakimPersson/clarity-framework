# Clarity Framework

> A methodology-agnostic documentation framework for software development. It scales from a
> personal side project to a team of 20. AI agents are a first-class execution layer governed by
> documented decisions, verification gates, and human accountability.

**Version:** 4.0.0 · [CHANGELOG](./framework/CHANGELOG.md)

## Three core principles

- **Just enough documentation** – every document must add value, not bureaucracy.
- **Documentation as code** – version documents in Git, review them with changes, and keep them near implementation.
- **Clarity over completeness** – a clear partial document is better than an unclear complete one.

## Repository structure

```text
clarity-framework/
│
├── framework/
│   ├── documentation-guide.md       # Main guide for all document types and lifecycle rules
│   ├── ai-usage-guide.md            # Governed AI-agent workflow, runtime contract, and safeguards
│   ├── PROJECT-INSTRUCTIONS.md      # Custom-instruction template for chat-based projects
│   └── CHANGELOG.md                 # Framework version history and release notes
│
├── templates/
│   ├── 00-ai-context.md             # Compact project context for new AI sessions
│   ├── 01-vision-scope.md           # Product vision, users, goals, boundaries, and risks
│   ├── 02-requirements.md           # NFRs, roles, story map, use cases, and traceability
│   ├── 02-user-stories.md           # Story backlog, split out when it outgrows 02-requirements
│   ├── 03-sad.md                    # System architecture, components, boundaries, and ADRs
│   ├── 04-data-model-api.md         # Domain model, schema, API, security, and compatibility
│   ├── 05-deployment-view.md        # Environments, infrastructure, CI/CD, monitoring, and rollback
│   ├── 06-test-documentation.md     # Test strategy, acceptance evidence, and visual UX verification
│   ├── 07-runbook.md                # Deployment, operations, recovery, and incident response
│   ├── 08-change-management.md      # Releases, superseded decisions, incidents, and technical debt
│   ├── 09-visual-profile.md         # Brand, design tokens, accessibility, and visual verification
│   └── plan.md                      # Transient work order for plan-driven implementation
│
├── agents/                         # Stack-specific AGENTS.md starters
│   ├── README.md                   # Starter selection and integration guidance
│   ├── generic.md                  # Neutral fallback when no stack starter matches
│   ├── java-application.md         # Java and Spring Boot projects
│   ├── ios-springboot.md           # Spring Boot backend with native Swift iOS/iPadOS app
│   ├── electron-desktop.md         # Electron desktop applications
│   ├── macos-swift.md              # Native Swift macOS applications
│   ├── r-shiny.md                  # R/Shiny applications and Plumber APIs
│   ├── vanilla-web-spa.md          # Build-step-free HTML/CSS/JavaScript web applications
│   ├── hugo-static-site.md         # Static websites built with Hugo
│   └── shell-dotfiles.md           # Shell scripts, aliases, and dotfiles
│
├── skills/
│   ├── README.md                   # Skill catalog, ownership, installation, and precedence
│   ├── clarity-bootstrap/           # Need-driven setup of a new or unmanaged project
│   │   └── SKILL.md
│   ├── framework-update/            # Upgrade framework-owned files without losing project content
│   │   ├── SKILL.md
│   │   ├── scripts/                 # Update-scope and commit-rendering helpers
│   │   └── tests/                   # Regression tests for update safety
│   └── plan-driven-build/           # Approval-gated planning, review, build, and verification
│       ├── SKILL.md                 # Orchestrator procedure
│       ├── prompts/                 # Instructions for dispatched agents
│       ├── dispatch.sh              # Bounded dispatch with sandbox, approval, and aimux-profile selection
│       ├── tests/                   # Dispatch regression tests
│       ├── plan-template.md         # Copy of templates/plan.md
│       ├── journal-template.md      # Cross-session workflow state
│       ├── setup.md                 # One-time profile, sandbox, and permissions setup
│       └── settings.example.json    # Claude Code permissions example
│
├── AGENTS.md                       # How an agent works in this repository
├── CLAUDE.md                       # Exactly one line: @AGENTS.md
└── README.md                       # This file
```

## Project structure

```text
my-project/
├── docs/
│   ├── 00-ai-context.md
│   ├── 01-vision-scope.md
│   ├── 02-requirements.md
│   └── plans/
├── .agents/skills/                 # Codex copies of selected Clarity skills
├── .claude/skills/                 # Claude Code copies of selected Clarity skills
├── AGENTS.md                       # Unedited framework-owned stack starter
├── CLAUDE.md                       # Exactly one line: @AGENTS.md
└── …
```

Framework-owned files are replaced wholesale during updates. Project-owned documents preserve their
content while their structure is lifted to the current template.

## Ownership

Every path has exactly one owner, and nothing crosses between them. This table is normative:
`framework-update` reads it to decide what it may replace.

| Path | Owner | Contains |
| --- | --- | --- |
| `CLAUDE.md` | Framework | The single line `@AGENTS.md`, and nothing else — ever |
| `AGENTS.md` | Framework | How an agent works in this stack; replaced wholesale on update |
| `.agents/skills/<name>/`, `.claude/skills/<name>/` | Framework, **per name** | Copies of Clarity skills, replaced wholesale. Ownership is name-scoped: only the names on the `skills:` line of `docs/00-ai-context.md` are Clarity's. A skill with any other name is project- or third-party-owned and is never touched |
| `docs/` | Project | Everything about this project: decisions, conventions, and deviations |

**Skill ownership is name-scoped, never wildcard-scoped.** An update replaces the two directories
belonging to each managed name and nothing else — not `.claude/` broadly, not every skill it finds.
That is what makes it safe to keep your own skills beside Clarity's.

**`CLAUDE.md` is a pointer, not a rulebook.** It exists only so Claude Code loads the same
instructions Codex reads directly. It never holds project-specific instructions.

**Everything project-specific lives in `docs/`,** routed to the document that governs it:

| Project-specific content | Document |
| --- | --- |
| Architecture, boundaries, technology choices | `docs/03-sad.md`, where ADRs are written; `docs/08-change-management.md` records which ones were superseded |
| Behavior, acceptance criteria, priorities | `docs/02-requirements.md` |
| Data models and interface contracts | `docs/04-data-model-api.md` |
| Build, environments, delivery | `docs/05-deployment-view.md` |
| Test conventions and Definition of Done | `docs/06-test-documentation.md` |
| Commands, operations, recovery | `docs/07-runbook.md` |
| Visual rules and design tokens | `docs/09-visual-profile.md` |
| Agent orientation, runtime contract, boundaries, and anything without a numbered home | `docs/00-ai-context.md` |

A project never edits a framework-owned file to record its own rules. A convention worth enforcing
is worth documenting where the framework already governs it — that keeps it reviewed, versioned, and
visible to every contributor rather than buried in a side file.

There is no required `docs/.clarity-version` file. The update skill reads version markers already
present in project documents, especially `docs/00-ai-context.md`, and compares them with the stable
release tag.

## Getting started

### New project

From the project root:

```bash
mkdir -p .agents/skills/clarity-bootstrap .claude/skills/clarity-bootstrap
curl -fsSL https://raw.githubusercontent.com/HansJoakimPersson/clarity-framework/main/skills/clarity-bootstrap/SKILL.md \
  -o .agents/skills/clarity-bootstrap/SKILL.md
cp .agents/skills/clarity-bootstrap/SKILL.md .claude/skills/clarity-bootstrap/SKILL.md
```

Then invoke `$clarity-bootstrap` in Codex or `/clarity-bootstrap` in Claude Code. The skill inspects
the project, proposes the smallest coherent document set, and stops for approval before writing —
this command only places the skill; it fetches from `main` since the skill itself always fetches the
latest **stable tagged** release when it runs.

Manual setup:

1. Create `/docs` in the project repository.
2. Copy the relevant templates from `/templates/` into `/docs/`.
3. Start with `01-vision-scope.md`.
4. Add `09-visual-profile.md` before visual UI implementation.
5. Add `00-ai-context.md` when an AI agent will work on the project.

### Existing project

Copy `skills/framework-update/` to both runtime skill roots and invoke `$framework-update` or
`/framework-update`. It fetches the latest stable release, preserves completed project content,
updates framework-owned files, reports required document changes, and proposes a dedicated commit.

### Plan-driven work

When a task is large enough to need scope approval, install `skills/plan-driven-build/` in both
runtime roots. It uses the four-level runtime contract, separate aimux profiles where
available, bounded reports, a committed run journal, and human gates for scope, merge, release, and
plan deletion.

It requires a second AI CLI, because the orchestrator dispatches the work instead of doing it.
`codex` is the dispatch adapter implemented today; which CLI runs each level comes from its aimux
profile, so a project never edits the skill to change tools.

## Documentation flow

```text
00-ai-context          ← Updated continuously; pasted into a new AI session.
      ↕
01-vision-scope        ← Start here; approve before all other documents.
        ↓
02-requirements        ← Define NFRs before functional requirements.
02-user-stories        ← Optional; split the backlog out when it outgrows 02-requirements.
        ↓
03-sad                 ← Architecture grounded in the NFRs.
        ↓
04-data-model-api      ← Contract-first, before implementation.
        ↓
05-deployment-view     ← CI/CD and infrastructure.
        ↓
06-test-documentation  ← In parallel with implementation.
07-runbook             ← Created for the first staging deployment.
08-change-management   ← Maintained throughout the product lifecycle.
09-visual-profile      ← Approved before visual UI implementation when a UI exists.
```

## Visual UX verification

Every meaningful UI change must be inspected in the running product at supported viewport sizes and
interaction states. Record the device/browser, viewport, date, journey, reviewer, and screenshots or
equivalent rendered evidence. Automated browser tests and accessibility scans support but do not
replace human visual inspection.

---

*Clarity Framework v4.0.0*
