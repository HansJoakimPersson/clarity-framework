# AGENTS.md - R/Shiny Application v1.0

Guidance for agents working in R and Shiny projects. Apply the Core Rules to every R/Shiny project, then apply only the
optional profiles that match the project in front of you.

## How To Use This Guide

- Always follow **Core Rules**.
- Add **renv** when the project uses renv for package management.
- Add **Tidyverse** when the project uses tidyverse packages for data manipulation.
- Add **Persistence** when the project connects to a relational database via DBI, RSQLite, RPostgres, or similar.
- Add **Plumber** when the project exposes a REST API via the plumber package.
- Add **Deployment** when the project deploys to shinyapps.io, Posit Connect, Shiny Server, or Docker.
- Local project-specific instructions, `CLAUDE.md`, and local `AGENTS.md` files always take precedence when present.

## Core Rules

### Operating Principles

- Keep changes minimal and localized — no drive-by refactors outside the task scope.
- Preserve established public APIs and existing conventions.
- Do not introduce new packages unless the task explicitly requires them.
- Never commit secrets, tokens, credentials, or personal data.
- Keep the app runnable. Do not proceed if `shiny::runApp()` fails or tests break.

### Workflow

1. Read local project instructions before starting any task. If `CLAUDE.md` or `AGENTS.md` exists, read it.
2. In Clarity Framework projects, read project documentation in this order:
   - `docs/00-ai-context.md` — compressed overview of what the project is, its stack, and current status
   - `docs/03-sad.md` — architecture, component responsibilities, and key design decisions
   - `docs/02-kravdokumentation.md` — requirements context when the task touches functional behavior
   - `docs/04-datamodell-api.md` — data model and API contracts when the task touches persistence or APIs
3. Read relevant source code before proposing changes — never guess reactive variable names, module IDs, or function signatures.
4. For non-trivial logic: write or update the failing test first with testthat, implement the smallest change, then refactor
   while keeping tests green.
5. Run tests after every completed step. Stop and fix before continuing.
6. Mark completed tasks in `TASKS.md` (if present) and continue to the next without waiting.
7. Define "done" as: app launches without errors + all tests green + no regressions.

### Hot Reload During Development

- Enable `options(shiny.autoreload = TRUE)` before calling `shiny::runApp()` to activate file watching. Shiny
  will monitor R source files and automatically reload the app in the browser when a file changes — no manual
  restart or port juggling required.
- Set this option in a dev-only `.Rprofile` or pass it interactively; never set it in `app.R` or `global.R`
  where it would affect production or test runs.
- `shiny.autoreload` watches files in the app directory. If the project splits logic across subdirectories,
  verify that the watcher covers those paths or set `options(shiny.autoreload.pattern = ...)` accordingly.
- For `golem`- or `rhino`-based projects, follow the framework's own dev-reload mechanism instead.

### R Style

- Follow the project's style configuration first (`.lintr`, `.styler.R`, or project-level conventions).
- Otherwise follow the [tidyverse style guide](https://style.tidyverse.org/).
- Use UTF-8 source encoding.
- Use 2-space indentation.
- Use `snake_case` for variables, functions, and file names.
- Use `PascalCase` for R6 classes.
- Keep line length to 80 characters unless the project has a different limit.
- Use the `<-` assignment operator, not `=`, except inside function arguments.
- Prefer explicit `package::function()` calls for non-tidyverse packages in scripts, or document imports clearly with
  `@importFrom` in package projects.
- Avoid `T` and `F` as abbreviations for `TRUE` and `FALSE`.
- Use named arguments when calling functions with more than two parameters, or when argument order is not obvious.
- Avoid side effects in pure functions; use reactive context for Shiny-specific side effects.
- Prefer early returns and named logical conditions over deeply nested `if`/`else` blocks.
- Use `stopifnot()` or `rlang::abort()` for programmatic assertions; use `shiny::validate()` and `shiny::need()` for
  user-facing input validation in Shiny.

### Shiny Architecture

- Prefer a modular structure using `shiny::moduleServer()` and `shiny::NS()` for all non-trivial apps.
- Keep UI definitions and server logic separated, either as `ui.R` / `server.R` or as clearly separated sections in
  `app.R`.
- Keep server functions thin: validate input, call business/domain functions, render outputs. Do not embed data
  manipulation or business logic inside `renderPlot()`, `renderTable()`, or similar render functions.
- Isolate reactive state — do not read reactives outside reactive contexts.
- Use `reactive()` for derived values and `observe()` / `observeEvent()` for side effects.
- Prefer `bindEvent()` over `eventReactive()` and `observeEvent()` for new code when the project's R version supports
  it (R ≥ 4.1, Shiny ≥ 1.6).
- Avoid `<<-` for shared state; use `reactiveVal()` or `reactiveValues()` explicitly.
- Do not hardcode UI labels or messages in server logic; keep them in UI definitions or a central constants file.
- Use `req()` to guard reactive expressions and outputs against `NULL` or invalid inputs.
- Prefer `shiny::validate()` with `shiny::need()` for user-facing error messages in outputs.

### Logging and Security

- Use the `logger` package or the project's established logging mechanism with structured, parameterized log entries.
- Choose levels deliberately: `DEBUG` for diagnostics, `INFO` for meaningful lifecycle events, `WARN` for recoverable
  problems, `ERROR` for failures requiring attention.
- Never log secrets, credentials, tokens, personal data, raw sensitive payloads, or large private data.
- Avoid `print()` and `cat()` in production app code; use the logging framework.
- Validate and sanitize user-controlled inputs at reactive boundaries.
- Avoid passing unsanitized user input directly to `system()`, `eval()`, or SQL string interpolation.
- Use parameterized queries (`DBI::dbGetQuery()` with `params`) for all database access.
- Never expose internal error messages, stack traces, or file paths directly to the Shiny UI.

### Configuration

- Do not hardcode URLs, ports, credentials, database connection strings, local paths, or environment-specific behavior
  in source code.
- Use environment variables (via `Sys.getenv()`) or a `.env`-style file loaded with the `dotenv` package for local
  development secrets.
- Keep `.env`, `.Renviron`, and credential files out of version control; document required variables in a
  `.env.example` or README section.
- Validate critical configuration at startup with clear error messages.
- Use Shiny's `options()` or a dedicated config file (e.g., `config` package) for app-level settings.

### Testing

- Use `testthat` for unit tests of business logic, data transformations, validation helpers, and utility functions.
- Use `shinytest2` for Shiny-level integration tests that verify reactive behavior, module interactions, and UI flows.
- A practical TDD loop is: failing test, smallest implementation, green test, refactor.
- Add regression tests for bug fixes.
- Cover input validation, edge cases, data transformations, reactive behavior, and error handling.
- Mock external API calls and database connections in unit tests; do not hit live services from automated tests.
- Use `withr` for temporary environment changes and file system isolation in tests.
- Do not remove tests unless explicitly requested.
- Do not skip failing tests with `skip()` or `skip_on_*()` without explicit approval.

#### Accessibility Testing

Shiny apps render as HTML in a real browser, so three complementary layers of accessibility work apply:

**Build-time: `a11yShiny`**

- Prefer `a11yShiny` wrappers over their base Shiny equivalents for action buttons, text inputs, select inputs,
  fluid page layouts, DT tables, and ggplot2 charts — they enforce ARIA attributes and WCAG 2.1 AA structural
  requirements at construction time.
- Treat `a11yShiny` as a building norm, not a substitute for scanning. Components built with it still need to be
  verified in context.

**Development inspection: `shinya11y`**

- Use `shinya11y` (via `use_tota11y()` in the UI) during active development to surface accessibility issues as a
  visual overlay in the running app.
- Remove or gate `shinya11y` behind a dev-only flag before deployment; it is not intended for production.
- `shinya11y` requires human review — it is not suitable as an automated CI gate.

**Automated scanning: axe-core via `shinytest2`**

- There is no first-class axe-core R package for Shiny. Automated WCAG scanning is done by injecting the
  axe-core JavaScript library into the app's Chromium session through `shinytest2`'s `get_chromote_session()`
  interface.
- Run axe against every major view and significant UI state as part of the `shinytest2` suite.
- Scan at WCAG 2.1 Level AA as the baseline unless the project sets a different target.
- Treat every axe violation as a test failure. Do not suppress violations without explicit approval and a
  documented reason.
- Exclude only third-party embeds or platform constraints that cannot be fixed in the project; document each
  exclusion.
- Automated axe scanning catches structural and attribute-level issues (missing labels, poor contrast, invalid
  ARIA). It does not replace manual keyboard navigation testing or screen reader testing.

### Documentation and Hygiene

- Update README, usage docs, or release notes when user-visible behavior changes.
- In Clarity Framework projects, update the relevant docs when their content changes:
  - `docs/02-kravdokumentation.md` — when requirements or acceptance criteria are affected
  - `docs/03-sad.md` — when architecture, modules, or key design decisions change
  - `docs/04-datamodell-api.md` — when data model or API contracts change
  - `docs/06-testdokumentation.md` — when testing strategy or coverage targets change
  - `docs/08-andringshantering.md` — for change tracking and ADRs
  - `docs/00-ai-context.md` — when stack, status, or key context shifts significantly
- Add roxygen2 documentation for exported functions and public modules that are newly added or materially changed.
- Document parameters, return values, reactive inputs/outputs, and side effects.
- Do not add comments that merely restate syntax.
- Do not reformat unrelated files.
- Do not make drive-by refactors.
- Do not leave commented-out code behind.
- Keep generated files (e.g., `.Rhistory`, `rsconnect/`) out of source control unless the project intentionally tracks
  them.

### Definition of Done

- Behavior is implemented and scoped to the request.
- The app launches without errors (`shiny::runApp()` succeeds).
- Relevant tests pass with no known regressions.
- UI, server, module, persistence, and integration checks have run when the change touches those surfaces.
- Public behavior, documentation, and configuration are aligned.
- Relevant Clarity Framework docs are updated when their content is affected.
- No unrelated dependency churn, formatting churn, or refactoring is included.
- Completion notes always include modified files.
- Completion notes always include commands executed.
- Completion notes always include test results, including counts of passed/failed/skipped when the test runner reports
  them.
- If tests or checks could not run locally, explain why and name the CI pipeline, job, or command that should run
  instead.

### Explicitly Forbidden

- Hardcoded secrets, credentials, personal data, private paths, or environment-specific values in source code.
- Logging sensitive data at any level.
- Adding packages without a task-driven reason.
- Passing unsanitized user input to `eval()`, `system()`, or SQL string interpolation.
- Skipping or suppressing failing tests without explicit approval.
- Committing real secrets, generated credentials, personal data, or production-only configuration.

## Optional Profile: renv

Use this profile when the project has an `renv.lock` file or `renv/` directory.

### renv Commands

```r
renv::restore()      # Restore packages from lockfile
renv::install()      # Install new packages into the project library
renv::snapshot()     # Update renv.lock after adding packages
renv::status()       # Check for drift between lockfile and installed packages
```

### renv Rules

- Always run `renv::snapshot()` after adding or updating packages, and commit the updated `renv.lock`.
- Do not manually edit `renv.lock`.
- Do not commit the `renv/library/` directory; it is machine-specific.
- Keep `renv/activate.R` and `.Rprofile` committed so collaborators and CI bootstrap renv automatically.
- Pin versions through `renv.lock`; do not rely on `install.packages()` without a subsequent snapshot.
- Add new packages to the project library with `renv::install("pkg")`, not `install.packages("pkg")`.

## Optional Profile: Tidyverse

Use this profile when the project uses tidyverse packages (`dplyr`, `tidyr`, `ggplot2`, `purrr`, etc.).

- Follow tidy data principles: each variable is a column, each observation is a row, each observational unit is a table.
- Prefer `dplyr` verbs (`filter()`, `mutate()`, `summarise()`, `select()`, `arrange()`, `group_by()`) over base R
  equivalents for data manipulation.
- Use the `|>` native pipe (R ≥ 4.1) or `%>%` consistently with the project; do not mix both.
- Keep pipe chains readable: one verb per line, aligned with the first pipe.
- Prefer `tidyr::pivot_longer()` and `tidyr::pivot_wider()` over deprecated `gather()`/`spread()`.
- Use `purrr::map_*()` variants for type-safe iteration over lists and vectors.
- Avoid modifying data frames in place; produce new data frames from transformation chains.
- Keep plotting code in separate functions or files from data transformation logic.
- Use `ggplot2` for visualizations; follow the project's theme and scale conventions.
- Prefer `forcats` for factor manipulation over base R `factor()` gymnastics.
- Use `lubridate` for date/time operations when the project already includes it.

## Optional Profile: Persistence

Use this profile when the project connects to a relational database.

### Database Choice

- Follow the database already chosen by the project.
- SQLite (via `RSQLite`) is acceptable for local-first apps, prototypes, and single-user deployments.
- PostgreSQL (via `RPostgres`) or another server database is preferable for multi-user deployments and concurrent
  writes.
- Call out database-specific assumptions such as case sensitivity, timestamp handling, transaction isolation, and SQL
  dialect differences.

### Query Rules

- Always use parameterized queries via `DBI::dbGetQuery(conn, sql, params = list(...))` or `DBI::dbExecute()`.
- Never construct SQL strings by pasting user-controlled values.
- Use `pool::dbPool()` for connection pooling in Shiny apps; never hold a single long-lived `DBI` connection across
  reactive sessions.
- Close connections or release pool connections appropriately using `on.exit()` or `pool::poolReturn()`.
- Keep SQL queries in named functions or separate files; do not embed multi-line SQL inside render functions.
- Test custom queries, edge cases, and NULL-handling.

### Migrations

- Prefer `DBI`-driven versioned migration scripts or the `dbmate` tool for schema changes.
- Never use ad hoc schema changes outside migration scripts for committed behavior.
- Destructive changes (`DROP`, column removal, data rewrites) require explicit approval and a rollback plan.

## Optional Profile: Plumber

Use this profile when the project exposes a REST API via the `plumber` package.

- Keep resource paths stable and predictable.
- Use standard HTTP methods and status codes.
- Validate and sanitize request input at the API boundary with explicit type checks and `stop()` or `rlang::abort()`.
- Return structured JSON error responses; never expose stack traces, R session state, or internal paths to clients.
- Keep plumber endpoint functions thin: parse input, call domain functions, return structured results.
- Do not embed business logic inside plumber annotations or endpoint functions.
- Document endpoints with plumber's `@param`, `@response`, and `@tag` annotations.
- Test endpoints with `httr2` or `testthat` + `plumber` test harness; do not rely solely on manual `curl` checks.

## Optional Profile: Deployment

Use this profile when the project deploys to shinyapps.io, Posit Connect, Shiny Server, or Docker.

### shinyapps.io and Posit Connect

- Use `rsconnect::deployApp()` for deployments; do not commit `rsconnect/` metadata to version control unless the
  project intentionally does so.
- Set secrets and environment variables through the platform's environment variable UI; never bake them into app code or
  `app.R`.
- Verify that `renv.lock` is current and committed before deploying; the platform uses it to restore packages.
- Test the app locally with `shiny::runApp()` before deploying.

### Docker

- Use a minimal base image such as `rocker/shiny` or `rocker/r-ver`.
- Restore packages from `renv.lock` during the Docker build step; do not copy the local `renv/library/`.
- Keep secrets out of the image; use Docker secrets, environment variables, or a secrets manager at runtime.
- Expose only the Shiny port (default `3838`) and keep the image minimal.
- Document the build and run commands in the README or a `Makefile`.

### General Deployment Rules

- Never deploy with `options(shiny.error = browser)` or debug settings active.
- Set `options(shiny.sanitize.errors = TRUE)` in production to prevent raw R errors from reaching the browser.
- Keep dev-only packages, test fixtures, and debug files out of the deployed artifact.
- Verify the app loads and responds correctly after each deployment.
