# AGENTS.md - Hugo Static Site v1.0

Guidance for agents working in static websites built with Hugo.

## Core Rules

- Deliver the task's full scope. A skeleton or partial implementation offered with "let me know if you want me to
  continue" is an incomplete delivery, not a small one.
- Stay inside the task's scope — no restructuring of `content/`, no theme swaps, and no redesigns beyond what the
  task requires.
- **Never edit a theme in place.** Override it from the project's own `layouts/`, which wins over the theme's copy
  of the same path. A theme is replaced wholesale when it is updated, so an edit inside it is silently reverted.
- Know which directory you are in: `assets/` is processed by Hugo Pipes, `static/` is copied verbatim to the site
  root. Putting a file in the wrong one is the most common cause of a missing or unprocessed asset.
- Never render untrusted or user-supplied content through `safeHTML`, `safeJS`, `safeCSS`, or `safeURL`. Those
  functions disable Hugo's escaping; they are for content you control.
- Keep the site buildable at every commit. `hugo` must succeed with no errors and no new warnings.
- Never commit secrets, tokens, or analytics keys to `hugo.toml`, front matter, or committed environment files.

## Workflow

1. Read `AGENTS.md` before starting any task.
2. In Clarity Framework projects, read `docs/00-ai-context.md` first when it exists — it is short, and it routes you
   to whatever else matters. If it is absent, continue from `README.md` and the task-relevant numbered documents; AI
   Context is optional. If a plan in `docs/plans/` governs this task, read that too: its scope section is
   authoritative, so do not re-plan, and if the plan is wrong or incomplete, stop and report rather than improvising.
   Read the remaining documents only when the task touches their subject:
   - `docs/09-visual-profile.md` — before touching any visual value: design tokens, colour palette, typography,
     spacing, and motion. If this file does not exist, do not hardcode visual values — raise the gap instead.
   - `docs/03-sad.md` — when the change adds a content type, a taxonomy, a build step, or an integration
   - `docs/05-deployment-view.md` — when the change touches the build command, `baseURL`, or how the site is published

   Do not read a document speculatively. Reading everything is slow and crowds out the templates you actually need.
3. Establish the theme model before editing any template: are layouts owned by the project, provided by a Hugo
   Module, or vendored as a Git submodule? Check `hugo.toml` for a `module.imports` or `theme` setting and look for
   `themes/`. The answer decides where your edit belongs; see the optional profiles below.
4. Identify whether the change affects content, front matter, templates, assets, configuration, or the build.
5. Add or update tests for user-visible behavior.
6. Implement the task in full, within its stated scope.
7. Build and run the relevant tests before reporting.
8. Report whether the task is done. If it is not, say what remains and why. Do not list changed files — the diff
   already shows them.

## When You Are a Dispatched Agent

Some tasks reach you as a work order from an orchestrator rather than from a person typing at you.
You are in that situation when a plan under `docs/plans/` governs the task, or when your instruction
says the scope is authoritative.

- The plan's scope section decides what gets built. Do not re-plan, and build nothing that is not
  listed under `Included`.
- If the plan turns out wrong or incomplete, stop and report it. You do not know why the plan looks
  the way it does, and improvising past it produces work nobody approved.
- Do not invoke another CLI as a subprocess, and ignore any orchestration skill file you find in the
  repo (for example under `.agents/skills/` or `.claude/skills/`). You are the level that builds; following it spawns
  nested agents.
- Keep your report inside the line budget you were given, and put the outcome in it. The orchestrator
  reads your report instead of the diff, so what you leave out is invisible — and what you write past
  the budget costs the context the whole arrangement exists to save.
- Do not commit unless told to. Commits and gates belong to the orchestrator.

## Content and Front Matter

- Put content under `content/`, using the section structure the site already has. Do not invent a parallel structure.
- Know the two bundle types: a **leaf bundle** is a directory with `index.md` and owns its page resources; a
  **branch bundle** is a directory with `_index.md` and lists its children. Choosing the wrong one is why a section
  page renders empty or a listing disappears.
- Keep page resources — images, downloads, attachments — inside the page's leaf bundle rather than in `static/`,
  so they move with the content and can be processed.
- Use the front matter fields the site's archetypes and templates actually read. Adding a field no template consumes
  is dead weight; removing one a template reads breaks the build or the page silently.
- Update `archetypes/` when a content type gains a required front matter field, so new content starts correct.
- Set `draft: true` for unfinished content. Drafts, future-dated, and expired pages are excluded from a production
  build — never publish by flipping a date.
- Keep body content in Markdown. Reach for a shortcode when a construct repeats or needs markup Markdown cannot
  express; do not paste raw HTML into content files.

## Templating

- Hugo resolves the most specific template first. Prefer adding a specific template over adding conditionals to a
  general one.
- Extract repeated markup into `layouts/partials/`. Extract repeated *content* constructs into
  `layouts/shortcodes/`. Partials serve templates; shortcodes serve authors.
- Pass an explicit context to partials rather than relying on `.` meaning what you assume. Use `partialCached` for
  partials whose output does not vary per page, and only then.
- Guard optional values with `with` or a default. A missing front matter field must not produce an empty element or
  a build error on one page out of two hundred.
- Read configuration through `.Site.Params` instead of hardcoding site-wide values in templates.
- Keep templates free of business logic that belongs in content or configuration.

## Assets and Styling

Baseline is Hugo Pipes, Hugo's built-in pipeline. See the optional profiles for Tailwind and for the plain-CSS case.

- Process assets from `assets/` with `resources.Get`, then `minify` and `fingerprint` for production output. Emit
  the result with `.RelPermalink`.
- Use `static/` only for files that must reach the site root untouched: `robots.txt`, `favicon.ico`, verification
  files.
- Use design token values from `docs/09-visual-profile.md` for all colours, typography, spacing, radii, shadows, and
  animation durations. Never hardcode these values in stylesheets or templates.
- Process images through Hugo's image functions (`Resize`, `Fit`, `Fill`) rather than committing pre-scaled copies.
  Generated derivatives land in `resources/_gen`; follow the project's existing decision on whether that directory is
  committed, and do not change it as a side effect.
- SCSS and image processing require the **extended** Hugo build. If the project uses either, the required Hugo
  version and edition belong in the project's build environment file — see Build and Configuration.

## Build and Configuration

- Configuration lives in `hugo.toml` or under `config/_default/`. When a project uses the `config/` directory,
  environment overrides go in `config/production/`; do not collapse them back into a single file.
- `baseURL` must be correct for the environment being built. A wrong `baseURL` produces a site that looks fine
  locally and ships broken canonical URLs, feeds, and absolute links. Pass `--baseURL` in CI rather than editing
  the committed value.
- Build production output with `hugo --gc --minify`. Treat warnings as defects, not noise.
- Pin the Hugo version and edition the project requires. In a Clarity Framework project that uses the plan-driven
  workflow, that belongs in `.agents/build-env.sh`, so a sandboxed build sees the same toolchain a developer does.
- Do not add a Node toolchain, bundler, or CSS framework to a site that does not already have one without explicit
  approval. Hugo Pipes covers most needs without them. When a task genuinely requires a third-party library, follow
  the Third-Party Assets and Dependencies profile.

## Development Run Model

- Run the site with `hugo server`. Add `-D` to include drafts while working on unpublished content.
- `hugo server` rebuilds on change and serves from memory; it does not write `public/`. Do not run a production
  build to preview an ordinary change.
- Never start a second static server alongside `hugo server`. If the project documentation does not make the run
  model clear, ask before assuming.
- Delete `public/` and `resources/_gen` only when diagnosing a stale-output problem, and say that you did.

## Testing

- Use Playwright against a running `hugo server` for browser-level tests unless the project has an established
  alternative.
- Prefer Playwright's built-in locators (`getByRole`, `getByLabel`, `getByText`) over CSS selectors and XPath — they
  reflect how users and assistive technology perceive the page, and break less often.
- Test user-visible behavior: navigation, section listings, pagination, search, forms, and any interactive
  component. Do not assert on generated class names or DOM depth.
- Cover the rendered result of a template change on at least one real page of each affected type, not only the page
  you had open.
- Add regression tests for fixed bugs.
- A successful build is not verification. `hugo` exits zero for a page that renders an empty section, a broken
  layout, or an unset front matter field.

### Automated Accessibility Testing

- Use `@axe-core/playwright` to run axe against every major page type and significant UI state.
- Scan at WCAG 2.2 Level AA as the baseline unless the project documents a different compatibility target.
- Run axe scans as part of the Playwright suite, not as a separate pipeline, so failures block the same CI gate as
  other browser tests.
- Treat every axe violation as a test failure. Do not suppress violations without explicit approval and a documented
  reason.
- Use `exclude()` only for third-party embeds or platform limitations that cannot be fixed in the project; document
  each exclusion.
- Axe catches structural and attribute-level issues; it does not replace keyboard navigation testing, screen reader
  testing, or colour-contrast review in context.

## Documentation and Hygiene

- Update README, content authoring notes, or release notes when authoring workflow or user-visible behavior changes.
- In Clarity Framework projects, update the relevant docs when their content changes:
  - `docs/03-sad.md` — when content types, taxonomies, or the build pipeline change; new ADRs are written here, in §6
  - `docs/05-deployment-view.md` — when the build command, `baseURL`, or publishing target changes
  - `docs/06-test-documentation.md` — when testing strategy or coverage changes
  - `docs/09-visual-profile.md` — when design tokens or visual rules change
  - `docs/08-change-management.md` — for releases, technical debt, incidents, and the index of superseded ADRs
  - `docs/00-ai-context.md` — when stack, status, or key context shifts significantly
- Keep `public/` out of source control. Follow the project's existing decision on `resources/_gen`.
- Do not reformat unrelated content files, and do not leave commented-out template blocks behind.

## Definition of Done

- `hugo --gc --minify` succeeds with no errors and no new warnings.
- The changed page types render correctly on a real page of each type, including listing pages.
- No theme file was edited in place; overrides live in the project's own `layouts/`.
- Design tokens are used for visual values; nothing visual is hardcoded.
- Playwright and axe checks pass for affected pages, or the verification gap is explained.
- Any new third-party dependency has a stated reason and an ADR, and is self-hosted unless a CDN was explicitly
  approved.
- Relevant Clarity Framework docs are updated when their content is affected.
- Completion notes state whether the task is done and what was verified. Do not list changed files — the diff
  already shows them.

## Optional Profile: Hugo Modules

A module may provide a whole theme or a single component — partials, shortcodes, assets, or content. The override
rule is the same either way; what differs is how much of the site it accounts for.

- Modules are declared under `module.imports` and resolved into Hugo's module cache. The cache is **not** an
  editable source directory. Override any template by creating the same path under the project's `layouts/`, and
  any asset by creating the same path under `assets/`.
- A component module is not a smaller theme. It contributes files at specific paths, so a project template that
  happens to use the same path silently replaces it. Check what a module actually mounts before overriding.
- `module.mounts` remaps a module's directories into the site. Changing a mount changes where every file from that
  module lands — treat it as an architectural change, not configuration tidying, and record it in `docs/03-sad.md`.
- Update with `hugo mod get -u` and verify the site still builds. A module update is its own change, never part of
  an unrelated task.
- Run `hugo mod tidy` after adding or removing an import, and commit `go.mod` and `go.sum` together. A `go.sum`
  left behind makes the next build unreproducible.
- Do not vendor with `hugo mod vendor` unless the project has already chosen to. Vendoring changes where the build
  reads from, so switching it on or off is a decision, not a convenience.
- Adding a module is adding a dependency. Apply the profile below.

## Optional Profile: Third-Party Assets and Dependencies

Use this profile when a task calls for a JavaScript library, a CSS library, a font, or a Hugo Module. Which
dependency a project uses is the project's decision, recorded as an ADR in `docs/03-sad.md` §6 and listed among the
technology choices in §5. What follows is how to arrive at that decision and how to bring the dependency in.

- Prefer what Hugo and the platform already provide. Most of what a static site needs — asset processing, image
  derivatives, syntax highlighting, feeds, search indexes — exists without a dependency. Reach for a library when
  the task genuinely needs behavior the platform lacks, not to save a few lines.
- Prefer no JavaScript at all where the platform has an equivalent. `<details>`, `<dialog>`, CSS scroll-snap, and
  the native form controls remove whole categories of dependency. A static site that ships a framework to toggle a
  menu has bought a runtime it did not need.
- State why the dependency is needed, what it replaces, and what it costs in bytes on the page. A dependency with
  no stated reason is one nobody can remove later.
- Prefer actively maintained libraries with a compatible licence. Record the licence when it is anything other than
  permissive.

There are three ways to bring an asset in. They are not equivalent, and the choice belongs in the ADR:

| Route | Use when | Costs |
| --- | --- | --- |
| `js.Build` from `assets/` | The project already has, or accepts, npm for fetching packages | esbuild is built into Hugo, so bundling itself needs no extra toolchain; npm adds a lockfile and an update burden |
| Vendored into `assets/` | One small library, rarely updated | No toolchain, but updates and security patches are manual and easy to forget — record the version and origin next to the file |
| CDN `<script>` or `<link>` | Rarely the right answer for a site you control | See below |

- **A CDN reference sends every visitor's IP address to a third party** before any consent has been obtained. For a
  site serving EU visitors that is a data-protection question, not a performance one, and it is the reason
  self-hosting fonts and scripts is the default. Do not add a CDN reference without explicit approval, and record
  the decision.
- If a CDN reference is approved, add Subresource Integrity (`integrity` plus `crossorigin`). Without it the site
  executes whatever that host serves tomorrow.
- Self-hosted assets go through Hugo Pipes so they are fingerprinted and cached correctly. A vendored file dropped
  into `static/` gets neither.
- Load a library only on the pages that use it. A dependency needed by one page does not belong in the site-wide
  bundle or in `baseof.html`.
- Remove a dependency when the task that motivated it removes its last use. Note the removal in
  `docs/08-change-management.md` if it changes what the site ships.

## Optional Profile: Theme as Git Submodule

- The theme lives under `themes/<name>/` as a Git submodule and is referenced by the `theme` setting.
- The submodule is a checkout of someone else's repository. Never commit changes inside it; override from the
  project's `layouts/` and `assets/` instead.
- A fresh clone has an empty `themes/<name>/`. Run `git submodule update --init --recursive` before reporting that
  the build is broken.
- Update by moving the submodule to a new commit deliberately, in its own change, with the new pointer committed.

## Optional Profile: Tailwind CSS

- Use Tailwind when the site is large enough that ad-hoc CSS has stopped being consistent. A small site does not
  need it, and adding it is a decision worth an ADR.
- Generate Tailwind's theme from the design tokens in `docs/09-visual-profile.md`. Tokens are the source of truth;
  the Tailwind configuration is derived from them, never a second, competing definition.
- Do not hardcode arbitrary values (`w-[473px]`, `text-[#3a2f1b]`) when a token-backed utility exists. An arbitrary
  value is a token that was not defined.
- Keep the content/template globs current so classes used in new template paths are not purged from the build.
- Extract a component class only when a markup pattern repeats and the utility list has become unreadable.

## Optional Profile: Plain CSS in `static/`

- Appropriate for a small site: no pipeline, no fingerprinting, stylesheet served exactly as committed.
- Define design tokens as CSS custom properties in one file, derived from `docs/09-visual-profile.md`, and reference
  them everywhere else.
- Accept the trade-off knowingly: no minification and no cache-busting fingerprint, so a stylesheet change may be
  served stale to returning visitors.
- Move to `assets/` and Hugo Pipes when the site outgrows this — that is a change worth recording, not a silent
  migration.

## Optional Profile: Multilingual

- Declare languages in the configuration, and keep translations as parallel content files or per-language content
  directories following the project's existing pattern.
- Put user-facing strings in `i18n/` and read them with `i18n`. A string hardcoded in a template cannot be
  translated.
- Link between translations with `.Translations`; never construct language URLs by string concatenation.
- Verify that a new page type renders in every configured language before reporting the task done.

## Optional Profile: Deployment

- Record the publishing target and its build command in `docs/05-deployment-view.md`.
- Pass the environment's `baseURL` at build time rather than committing an environment-specific value.
- Pin the Hugo version and edition in the build configuration. A CI runner defaulting to a different version or to
  the non-extended edition is a common and confusing build failure.
- Build once and publish that output. Do not rebuild per environment when the artifact is meant to be promoted.
