# AGENTS.md - Vanilla Web SPA v1.1

Guidance for agents working in small single-page web applications without a framework or build step.

## Core Principles

- Keep the application simple and dependency-free unless the task explicitly requires otherwise.
- Preserve the no-build workflow when that is an established project constraint.
- Prefer plain HTML, CSS, and JavaScript over introducing tooling.
- Deliver the task's full scope. A skeleton or partial implementation offered with "let me know if you want me to
  continue" is an incomplete delivery, not a small one.
- Stay inside the task's scope; do not split files or reorganize structure unless requested.
- Never persist API keys, tokens, secrets, or sensitive user data in unsafe storage.
- User-facing behavior changes should be covered by browser-level tests.

## Workflow

1. Read local project instructions before starting any task. If `CLAUDE.md` or `AGENTS.md` exists, read it.
2. In Clarity Framework projects, always read `docs/00-ai-context.md` first — it is short, and it routes you to
   whatever else matters. If a plan in `docs/plans/` governs this task, read that too: its scope section is
   authoritative, so do not re-plan, and if the plan is wrong or incomplete, stop and report rather than
   improvising. Read the remaining documents only when the task touches their subject:
   - `docs/09-grafisk-profil.md` — before touching any visual value: design tokens, colour palette, typography,
     spacing, and motion. If this file does not exist, do not hardcode visual values — raise the gap instead.
   - `docs/03-sad.md` — when the change adds or moves a component, crosses a module boundary, or you are unsure
     where the change belongs
   - `docs/04-datamodell-api.md` — when the task touches network behavior or data structures

   Do not read a document speculatively. Reading everything is slow and crowds out the code you actually need.
3. If the project has a backend component, confirm the run model before starting anything: is the frontend served
   by the backend process, or does it run as a separate server? If the project documentation does not make this
   clear, ask before assuming. Never start a separate frontend server solely because a backend exists.
4. Identify whether the change affects markup, styling, state, rendering, network behavior, storage, or user
   interaction.
5. Add or update tests for user-visible behavior.
6. Implement the task in full, within its stated scope.
7. Run targeted browser tests when behavior changes.
8. Report whether the task is done. If it is not, say what remains and why. Do not list changed files — the diff
   already shows them. Summarize by affected area only when the change spans several components.

## When You Are a Dispatched Agent

Some tasks reach you as a work order from an orchestrator rather than from a person typing at you.
You are in that situation when a plan under `docs/plans/` governs the task, or when your instruction
says the scope is authoritative.

- The plan's scope section decides what gets built. Do not re-plan, and build nothing that is not
  listed under `Ingår`.
- If the plan turns out wrong or incomplete, stop and report it. You do not know why the plan looks
  the way it does, and improvising past it produces work nobody approved.
- Do not invoke another CLI as a subprocess, and ignore any orchestration skill file you find in the
  repo (for example under `.claude/skills/`). You are the level that builds; following it spawns
  nested agents.
- Keep your report inside the line budget you were given, and put the outcome in it. The orchestrator
  reads your report instead of the diff, so what you leave out is invisible — and what you write past
  the budget costs the context the whole arrangement exists to save.
- Do not commit unless told to. Commits and gates belong to the orchestrator.

## File Structure

- Keep the existing no-build structure intact.
- If the app is intentionally contained in one HTML file, keep HTML, CSS, and JavaScript there.
- Do not add bundlers, transpilers, CDNs, package managers, or external assets without explicit approval.
- Keep inline SVG icons or local assets consistent with existing patterns.

## JavaScript

- Use vanilla JavaScript only unless the project already uses a library.
- Keep state in the existing state model.
- Centralize rendering and state updates according to the current pattern.
- Avoid hidden global mutations outside the established state flow.
- Keep async control flow explicit and handle cancellation or stale responses where relevant.
- Validate and normalize external data before rendering.
- Avoid stop sequences, protocol assumptions, or provider-specific shortcuts unless the existing integration requires
  them.

## HTML and Accessibility

- Use semantic elements where possible.
- Associate labels with form controls.
- Keep buttons as buttons, links as links, and interactive controls keyboard-accessible.
- Preserve focus behavior for dialogs, sidebars, menus, and dynamic panels.
- Use ARIA only where native semantics are insufficient.
- Ensure loading, empty, success, and error states are visible and understandable.

### Automated Accessibility Testing

- Use `@axe-core/playwright` to run axe against every major view and significant UI state.
- Scan at WCAG 2.1 Level AA as the baseline unless the project sets a different target.
- Run axe scans as part of the Playwright test suite, not as a separate pipeline, so failures
  block the same CI gate as other browser tests.
- Scope scans to the relevant component or region when testing a partial view; use a full-page
  scan for new pages and major layout changes.
- Treat every axe violation as a test failure. Do not suppress violations without explicit approval
  and a documented reason.
- Use `exclude()` only for third-party embeds or known platform limitations that cannot be fixed
  in the project; document each exclusion.
- Axe catches structural and attribute-level issues; it does not replace manual keyboard navigation
  testing, screen reader testing, or color-contrast review in context.

## CSS

- Use design token values (CSS custom properties generated from `docs/09-grafisk-profil.md`) for all colours,
  typography, spacing, radii, shadows, and animation durations. Never hardcode these values in stylesheets.
- Use existing CSS variables and naming conventions.
- Keep layouts stable as content changes.
- Do not introduce broad visual redesigns for narrow behavior tasks.
- Keep responsive behavior working on mobile and desktop.
- Avoid CSS that depends on fragile DOM depth unless already established.

## Network and Storage

- Mock network requests in tests.
- Keep provider-specific request/response handling isolated.
- Handle streaming, partial responses, malformed data, and request failures gracefully.
- Do not persist API keys or secrets in `localStorage`, `sessionStorage`, IndexedDB, or cookies.
- Version or migrate stored state when changing persistent data shape.
- Keep storage keys documented when they are part of app behavior.

## Testing

- Use Playwright for browser-level tests unless the project has an established alternative.
- Prefer Playwright's built-in locators (`getByRole`, `getByLabel`, `getByText`) over CSS selectors
  and XPath — they reflect how users and assistive technology perceive the page, and break less often.
- Test user-visible behavior: navigation, form submission, loading states, error states, and user
  interactions. Do not test implementation details.
- Add regression tests for fixed bugs.
- Mock all external network calls with `page.route()` except explicit live-backend tests.
- Keep live-backend tests opt-in and out of normal CI unless the project decides otherwise.
- Run only tests relevant to the changed surface for CSS-only changes unless layout behavior is risky.

## Security

- Escape or safely render untrusted content.
- Avoid `innerHTML` for untrusted data unless sanitized.
- Do not expose stack traces, secrets, or raw provider errors directly to users.
- Keep external links, downloads, and file handling explicit and user-initiated.

## Documentation and Hygiene

- In Clarity Framework projects, update the relevant docs when their content changes:
  - `docs/04-datamodell-api.md` — when API contracts or data structures change
  - `docs/06-testdokumentation.md` — when testing strategy or coverage changes
  - `docs/08-andringshantering.md` — for change tracking
  - `docs/00-ai-context.md` — when stack or project status shifts significantly

## Definition of Done

- The app still works without a build step.
- User-facing behavior is tested or the verification gap is explained.
- No unnecessary dependencies or external assets were introduced.
- Storage, network, accessibility, and error states remain coherent.
- Relevant Clarity Framework docs are updated when their content is affected.
