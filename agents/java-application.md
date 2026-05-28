# AGENTS.md - Java Application v1.1

Guidance for agents working in Java applications. Apply the Core Rules to every Java project, then apply only the
optional profiles that match the project in front of you.

## How To Use This Guide

- Always follow **Core Rules**.
- Add **Maven** when the project uses Maven.
- Add **Gradle** when the project uses Gradle.
- Add **Lombok** when Lombok is already present or explicitly requested.
- Add **CLI** when the primary user interface is a command line.
- Add **REST Web** when the project exposes HTTP APIs.
- Add **Web Frontend** when the repository includes browser UI code.
- Add **Persistence** when the project uses a relational database, migrations, JPA, Hibernate, JDBC, or
  SQLite/PostgreSQL/MySQL.
- Add **Spring Boot Platform** when the project is a Spring Boot service, monolith, or service-oriented platform.
- Add **Packaging and Runtime** when the project produces a runnable artifact, library, container image, or
  distribution.
- Local project-specific instructions, `CLAUDE.md`, and local `AGENTS.md` files always take precedence when present.

## Core Rules

### Operating Principles

- Keep changes minimal and localized — no drive-by refactors outside the task scope.
- Preserve established public APIs and existing conventions.
- Do not introduce new dependencies unless the task explicitly requires them.
- Never commit secrets, tokens, credentials, or personal data.
- Keep the build green. Do not proceed if tests fail.

### Workflow

1. Read local project instructions before starting any task. If `CLAUDE.md` or `AGENTS.md` exists, read it.
2. In Clarity Framework projects, read project documentation in this order:
   - `docs/00-ai-context.md` — compressed overview of what the project is, its stack, and current status
   - `docs/03-sad.md` — architecture, component responsibilities, and key design decisions
   - `docs/02-kravdokumentation.md` — requirements context when the task touches functional behavior
   - `docs/04-datamodell-api.md` — data model and API contracts when the task touches persistence or APIs
3. Read relevant source code before proposing changes — never guess field names or method signatures.
4. Use TDD for non-trivial logic: write or update the failing test first, implement the smallest change, then refactor
   while keeping tests green.
5. Run tests after every completed step. Stop and fix before continuing.
6. Mark completed tasks in `TASKS.md` (if present) and continue to the next without waiting.
7. Define "done" as: compiles + all tests green + no regressions.

### Java Style

- Follow the project's formatter and style configuration first.
- Only then use **Google Java Style Guide**.
- Use UTF-8 source encoding.
- Use 4-space indentation for Java unless the project formatter says otherwise.
- Use blank lines to separate logical blocks.
- Keep line length consistent with the project; when no rule exists, prefer a practical maximum around 120 characters.
- Use the Java version configured by the build.
- On Java 21 or newer, use records, sealed types, pattern matching, and switch expressions where they improve clarity
  and match local style.
- Prefer explicit types unless local style already favors `var` and the initializer is obvious.
- Use descriptive names for classes, methods, fields, variables, and tests.
- Declare method parameters and local variables `final` where the project style favors it and it improves readability.
- Prefer immutability: records, final fields, constructor validation, and immutable collections where appropriate.
- Avoid mutating objects in for-each loops or Stream `forEach()` when a clearer immutable transformation is practical.
- Use constants or enums for magic values.
- Check emptiness and nullness before operating on collections, strings, and optional inputs.
- Use imports instead of fully qualified class names in method bodies.
- Use `Optional<T>` as a return type when useful; avoid it for fields and parameters unless local style differs.
- Prefer early returns and named boolean conditions over deeply nested logic.
- Avoid unnecessary `else` blocks after returning or throwing.
- Prefer direct null checks over `Objects.isNull()` and `Objects.nonNull()` for simple cases.
- Prefer non-null design; use `Objects.requireNonNull` at boundaries and constructors when it clarifies contracts.
- Prefer unchecked exceptions for validation and programming errors unless the API or domain needs checked exceptions.
- Fail fast with clear exception messages.
- Preserve exception causes when wrapping exceptions.
- Validate untrusted input at system boundaries.

### Logging and Security

- Use SLF4J parameterized logging when SLF4J is available.
- Use the project's logging framework with parameterized messages when it is not SLF4J.
- Never build log messages with string concatenation when parameterized logging is available.
- Choose levels deliberately: `debug` for diagnostics, `info` for meaningful lifecycle events, `warn` for recoverable
  problems, `error` for failures needing attention.
- Never log secrets, credentials, tokens, personal data, raw sensitive payloads, or large private data.
- Avoid `System.out` and `System.err` in reusable business logic.
- Keep user-facing messages clean and actionable.
- Use parameterized queries and framework-safe data access.
- Sanitize or redact user-controlled and sensitive values before logging or displaying them.

### Configuration

- Do not hardcode URLs, ports, credentials, local paths, feature flags, or environment-specific behavior in source code.
- Use the project's configuration mechanism: properties/YAML, environment variables, profiles, CLI options, or a secret
  manager.
- Keep local defaults safe and convenient without accidentally becoming production defaults.
- Document new configuration keys, defaults, allowed values, and whether they are required.
- Validate critical configuration at startup and fail fast with clear messages.
- Keep secrets out of committed config files; use ignored local files or secret-management mechanisms.

### Testing

- Prefer TDD for service logic, parsers, algorithms, validation rules, state transitions, bug fixes, and domain
  behavior.
- A practical TDD loop is: failing test, smallest implementation, green test, refactor.
- Writing tests after implementation is acceptable for thin wiring, simple CRUD endpoints, trivial DTO serialization,
  generated code, and configuration that has no meaningful behavior.
- Add regression tests for bug fixes.
- Cover validation, edge cases, parsing, serialization, persistence queries, error handling, and public behavior
  affected by the change.
- Use unit tests for pure logic and focused service behavior.
- Use integration tests for persistence, messaging, external adapters, application wiring, and full user workflows when
  risk warrants it.
- Use Mockito for Java unit-test mocks when the project uses or permits it.
- Mock network calls and external processes in unit tests; do not hit live services from unit tests.
- Use fixtures under the project's test resources for parser, file, rendering, and round-trip tests.
- Use temporary-directory test support such as JUnit `@TempDir` for tests that write files.
- Prefer AssertJ or the project's established fluent assertion style when it improves failure messages.
- Do not remove tests unless explicitly requested.
- Do not skip failing tests with `@Disabled`, `@Ignore`, assumptions, or swallowed exceptions without explicit approval.

### Documentation and Hygiene

- Update README, usage docs, API docs, or release notes when user-visible behavior changes.
- In Clarity Framework projects, update the relevant docs when their content changes:
  - `docs/02-kravdokumentation.md` — when requirements or acceptance criteria are affected
  - `docs/03-sad.md` — when architecture, components, or key design decisions change
  - `docs/04-datamodell-api.md` — when data model or API contracts change
  - `docs/06-testdokumentation.md` — when testing strategy or coverage targets change
  - `docs/08-andringshantering.md` — for change tracking and ADRs
  - `docs/00-ai-context.md` — when stack, status, or key context shifts significantly
- Add Javadoc for public types and public/protected methods that are newly added or materially changed.
- Document behavior, invariants, edge cases, and failure modes.
- Use `{@link TypeName}` when referencing existing Java types in Javadoc.
- Do not restate the method or class name in Javadoc; explain the contract.
- Do not add comments that merely restate syntax.
- Do not reformat unrelated files.
- Do not make drive-by refactors.
- Do not leave commented-out code behind.
- Keep generated files out of source control unless the project intentionally tracks them.

### Definition of Done

- Behavior is implemented and scoped to the request.
- The project compiles.
- Relevant tests pass with no known regressions.
- Backend, frontend, persistence, and integration checks have run when the change touches those surfaces.
- Public behavior, documentation, and configuration are aligned.
- Relevant Clarity Framework docs are updated when their content is affected.
- No unrelated dependency churn, formatting churn, or refactoring is included.
- Completion notes always include modified files.
- Completion notes always include commands executed.
- Completion notes always include test results, including run/failure/error/skipped counts when the test runner reports
  them.
- If tests or checks could not run locally, explain why and name the CI pipeline, job, or command that should run
  instead.

### Explicitly Forbidden

- Hardcoded secrets, credentials, personal data, private paths, or environment-specific values in source code.
- Logging sensitive data at any level.
- Adding dependencies without a task-driven reason.
- Changing established public APIs without explicit instruction.
- Skipping or suppressing failing tests without explicit approval.
- Swallowing exceptions in tests to hide failures.
- Committing real secrets, generated credentials, personal data, or production-only configuration.

## Optional Profile: Maven

Use this profile when the project has `pom.xml` or Maven Wrapper.

### Maven Commands

Prefer Maven Wrapper when present:

```bash
./mvnw -q test
./mvnw -q -Dtest=SpecificTest test
./mvnw -q clean test
./mvnw -q -DskipTests package
./mvnw -q verify
```

Without a wrapper, use `mvn` with the same goals.

Run formatting, license, static analysis, or coverage goals only when they are configured in the project or included in
normal verification.

### Maven Build Files

- Edit `pom.xml` minimally and preserve existing ordering/style.
- Keep versions in `<properties>` or `<dependencyManagement>` when the project uses them.
- Use correct scopes: `test`, `provided`, `runtime`, or compile as appropriate.
- Use `test` scope for test-only dependencies.
- Prefer stable, widely used libraries when a new dependency is genuinely needed.
- Preserve Surefire/Failsafe or unit/integration-test separation when present.
- Do not add repositories unless unavoidable; use HTTPS only.

## Optional Profile: Gradle

Use this profile when the project has `build.gradle`, `build.gradle.kts`, or Gradle Wrapper.

### Gradle Commands

Prefer Gradle Wrapper when present:

```bash
./gradlew test
./gradlew check
./gradlew build
./gradlew bootRun
./gradlew bootJar
```

Run only commands that exist in the project. Use `gradle` directly only when there is no wrapper.

### Gradle Build Files

- Edit `build.gradle` or `build.gradle.kts` minimally and preserve existing style.
- Keep dependency versions in the existing central location, such as version catalogs, platform/BOMs, or
  dependency-management blocks.
- Do not add plugins or repositories unless the task requires them.
- Keep test fixtures, integration-test source sets, and generated-source configuration aligned with existing
  conventions.
- Do not make the build depend on IDE-only behavior.

## Optional Profile: Lombok

Use this profile when Lombok is already present or explicitly requested.

- Follow existing Lombok conventions in the module.
- Prefer `@RequiredArgsConstructor` for constructor injection.
- Use `@Slf4j` for logging when Lombok is in use unless the project has a different established logger pattern.
- Prefer records, `@Value`, or final fields for immutable data.
- Use `@Builder` for complex construction; combine it with no-args/all-args constructors when deserialization frameworks
  require them.
- Consider `@Builder(setterPrefix = "with")` only when it matches existing project style.
- Use `@Builder.Default` for initialized collections.
- Avoid `@Data` on JPA entities and classes where generated equality, mutability, or `toString` exposure is unsafe.
- `@Getter` and `@Setter` are acceptable on mutable entities and POJOs when mutability is intentional.
- Use `@EqualsAndHashCode(onlyExplicitlyIncluded = true)` for entities when equality should be based on explicit
  identity fields.
- Exclude lazy collections, bidirectional relationships, self-referential fields, and sensitive fields from generated
  `toString`.
- Prefer granular Lombok annotations such as `@Getter` and `@Setter` when only part of `@Data` is needed.
- Avoid `@SneakyThrows`; handle or propagate exceptions explicitly.
- Keep annotation processor ordering compatible with Lombok and mapper processors.
- In Maven `annotationProcessorPaths`, put Lombok before MapStruct or any processor that depends on Lombok-generated
  members.

## Optional Profile: CLI

Use this profile when the primary interface is a command line.

### CLI Framework

- Prefer Picocli for non-trivial Java CLI applications.
- Use hand-written argument parsing only for tiny tools with one or two simple flags and no expected growth.
- Use Picocli when the CLI needs subcommands, typed options, validation, generated help, version output, exit codes,
  shell completion, or testable command dispatch.
- Keep command classes thin: parse input, call application/domain services, format output, and return an exit code.
- Do not hide business logic inside Picocli command classes.
- Add Picocli as a dependency only when the CLI surface justifies it; do not add it to libraries or services that only
  have incidental command-line entry points.

### CLI Behavior

- Preserve backward compatibility for flags, positional arguments, output formats, and exit codes.
- Add new flags with clear names, help text, defaults, and invalid-value tests.
- Fatal user errors should print a clean message, avoid stack traces by default, and exit non-zero.
- Recoverable per-item errors in batch operations should be reported and logged without aborting the whole batch unless
  correctness requires it.
- Keep business logic separate from terminal formatting where practical.
- Avoid hardcoded paths; use CLI options, config files, or environment-derived locations.

### CLI File I/O

- Use `Path` and `Files` APIs instead of string path manipulation.
- Use `@TempDir` in tests that write files.
- Avoid writing to the project tree or global `/tmp` from tests.
- Treat overwrites, deletes, and moves as risky operations requiring explicit user intent or a clear project convention.

### CLI Testing

- Use this testing split as a baseline:

| What | Method | Notes |
| --- | --- | --- |
| Domain logic, parsers, algorithms | Unit tests | Keep fast and deterministic |
| File I/O and temp-directory operations | Unit tests with `@TempDir` | Do not write to the project tree |
| Full command invocation | Integration tests | Assert exit code, stdout, and stderr |
| End-to-end round trips | Integration tests with fixtures | Cover real input/output formats |

- Unit test parsers, algorithms, command validation, output formatting, and file-I/O edge cases.
- Add integration tests for full command invocation and fixture-based round trips.
- Assert exit codes and stderr/stdout behavior for user-facing command changes.
- Write tests before implementation for non-trivial parsers, algorithms, engines, and command validation.
- Writing tests after implementation is acceptable for thin CLI wiring and trivial serialization, provided behavior is
  still covered before completion.

## Optional Profile: REST Web

Use this profile when the project exposes HTTP APIs.

### REST API

- Keep resource names stable and predictable.
- Use standard HTTP methods and status codes.
- Validate request input at the API boundary with standard validation.
- Return structured error responses; never expose stack traces to clients.
- Keep request/response DTOs separate from persistence entities.
- Prefer immutable DTOs, records, and value objects.
- Version or extend contracts carefully when existing clients may depend on them.
- Preserve pagination, sorting, filtering, and validation behavior unless explicitly changed.
- Keep OpenAPI or endpoint documentation aligned when contracts change.
- Prefer an OpenAPI endpoint for non-trivial REST APIs, especially when frontend clients, external consumers, generated
  clients, or integration tests depend on the contract.
- Keep OpenAPI descriptions focused on public contracts: request/response schemas, status codes, validation constraints,
  auth requirements, and error shapes.
- Do not expose internal implementation details, sensitive examples, or private infrastructure data through API
  documentation.

### API Error Handling

- Use a consistent structured error response format.
- In Spring applications, prefer a global `@ControllerAdvice` or equivalent established project mechanism.
- Never expose stack traces, class names, SQL errors, or internal implementation details to clients.
- Validation errors should be machine-readable and identify the invalid field or parameter when safe.
- Use status codes consistently: `400` for malformed requests, `401`/`403` for auth failures, `404` for missing
  resources, `409` for conflicts, and `422` when syntactically valid input fails domain validation.
- Log server-side failures with enough context to debug, but keep sensitive request data out of logs.

### Web Layer Testing

- Test controller mappings, validation, status codes, and error responses with the project's web test framework.
- Add integration tests for workflows spanning API and persistence when risk warrants it.
- Do not test framework infrastructure unless the project has custom configuration logic.

## Optional Profile: Persistence

Use this profile when the project uses a relational database, schema migrations, JPA, Hibernate, JDBC, or a file-backed
database such as SQLite.

### Database Choice

- Follow the database already chosen by the project.
- Do not swap database engines in tests when SQL dialect, locking, constraints, migrations, or query behavior matters.
- SQLite is acceptable for small local-first apps, desktop apps, CLIs, prototypes, and embedded deployments where
  single-writer constraints are understood.
- PostgreSQL or another server database is usually a better default for multi-user services, concurrent writes,
  operational monitoring, and production web platforms.
- Call out database-specific assumptions such as case sensitivity, timestamp precision, transaction isolation, locking,
  JSON support, and migration syntax.

### Migrations

- Prefer Flyway for schema migrations in Java/Spring applications unless the project already uses another migration
  tool.
- Schema changes must go through versioned migrations when migrations are present.
- Never use ad hoc `ALTER TABLE` or manual schema edits outside migrations for committed behavior.
- Migration versions must be strictly ordered and never reused.
- Destructive changes such as `DROP`, `TRUNCATE`, column removal, or data rewrite require explicit approval and a
  rollback/recovery plan.
- Keep migrations deterministic and environment-independent.

### JPA and Hibernate

- Use `jakarta.persistence` for modern Hibernate/Spring Boot projects.
- Keep entities focused on persistence state; keep API DTOs separate.
- Prefer lazy relationships by default and fetch explicitly for use cases that need related data.
- Avoid leaking entities directly through REST responses.
- Avoid `@Data` on entities.
- Keep `equals`, `hashCode`, and `toString` safe for proxies, lazy collections, bidirectional relationships, and
  self-references.
- Use converters for value types that do not have a native mapping.
- Keep transaction boundaries in services or use-case layers rather than controllers.

### Repository and Query Rules

- Use parameterized queries and framework-safe query APIs.
- Test custom queries, projections, pagination, sorting, and database constraints.
- Avoid business logic in repositories; repositories should express data access.
- Avoid N+1 query regressions when adding relationships or DTO projections.
- Prefer explicit indexes for query patterns introduced by new features.

### Persistence Tests

- Use the same database family as production when behavior depends on database dialect or migrations.
- For SQLite projects, test against SQLite rather than H2.
- For PostgreSQL/MySQL-style production behavior, prefer Testcontainers when the project supports it.
- Run migration validation in integration tests when schema changes are part of the task.
- Use `@TempDir` or equivalent isolation for file-backed database tests.

## Optional Profile: Dependency Policy

Use this profile when adding, removing, or upgrading dependencies.

- Prefer standard JDK, framework, or already-present project capabilities before adding libraries.
- Avoid small one-off dependencies for trivial utilities.
- Prefer actively maintained, widely used libraries with compatible licenses.
- Pin versions through the project's existing dependency-management mechanism.
- Remove unused dependencies when discovered as part of the task.
- Be cautious with dependencies that introduce reflection-heavy behavior, bytecode generation, native binaries,
  background threads, network calls, or global state.
- For runtime dependencies, consider artifact size, startup cost, security surface, and transitive dependencies.
- Explain why each new dependency is needed.

## Optional Profile: Web Frontend

Use this profile when the repository includes browser UI code.

### Development Run Model

Before starting any server or running any build command, determine which run model the project uses. If it is not
documented in `CLAUDE.md`, `AGENTS.md`, or `docs/03-sad.md`, ask before assuming.

**Embedded (most common):** The frontend is built as a static artifact and consumed by Maven or Gradle packaging.
The Java process serves everything — there is no separate frontend server in production or in normal development.

- Build the frontend with `npm run build` (or the project's equivalent); do not start a standalone dev server
  unless the project's instructions say to do so.
- For hot reload during development, use the frontend tool's dev mode (e.g., Vite, webpack-dev-server) configured
  to proxy API calls to the running Spring Boot process. Document the proxy target in the project's frontend config.
- Enable `spring-boot-devtools` on the Java side for automatic class reloading without a full JVM restart. With
  DevTools on the classpath, saving a Java file triggers a fast restart; static frontend assets served from
  `src/main/resources/static` reload in the browser via the embedded LiveReload server.
- Never infer that a `package.json` means the frontend should run as a separate server — read the project
  documentation first.

**Standalone:** The frontend is a separately deployed application with its own server and lifecycle.

- This model requires explicit documentation in `CLAUDE.md` or `docs/03-sad.md`, including how CORS is configured
  and which port each process uses.
- Start both processes only when the project documentation instructs it.

- Follow the existing framework, state management, routing, and styling patterns.
- Keep API access centralized where the project already has a client layer.
- Treat the API contract as the integration source of truth.
- Validate and handle loading, empty, error, and success states.
- Avoid hardcoded backend URLs; use existing configuration mechanisms.
- Do not store secrets in browser storage.
- Keep accessibility in mind for forms, navigation, buttons, dialogs, and dynamic content.
- Avoid unrelated visual redesigns when implementing behavior changes.
- Use the package manager and scripts already present, such as `npm test`, `npm run lint`, `npm run build`, or `npm run
  test:e2e`.
- Do not add frontend dependencies to Java build files.
- Use Playwright for browser-level and end-to-end tests when the project has web UI behavior to verify, unless an
  equivalent browser test framework is already established.
- Prefer Playwright's built-in locators (`getByRole`, `getByLabel`, `getByText`) over CSS selectors and XPath — they
  reflect how users and assistive technology perceive the page.
- Cover user-facing interactions, routing, form validation, API error states, loading states, and regression fixes with
  browser tests.
- Mock backend/network calls in frontend tests unless the test is explicitly a live integration test.

#### Accessibility Testing

- Use `@axe-core/playwright` to run axe against every major view and significant UI state as part of the Playwright
  suite.
- Scan at WCAG 2.1 Level AA as the baseline unless the project sets a different target.
- Treat every axe violation as a test failure; do not suppress violations without explicit approval and a documented
  reason.
- Use `exclude()` only for third-party embeds or known platform constraints that cannot be fixed in the project;
  document each exclusion.
- Axe covers structural and attribute-level issues; it does not replace manual keyboard navigation testing or screen
  reader testing.

## Optional Profile: Packaging and Runtime

Use this profile when the project produces a runnable JAR, library JAR, CLI distribution, Spring Boot artifact,
container image, or packaged release.

- Prefer clean, conventional JAR artifacts whenever practical.
- Keep libraries as plain JARs without application runtime behavior.
- For applications, prefer a runnable JAR or Spring Boot executable JAR before custom installers or complex packaging.
- Keep dev-only tools, test fixtures, generated debug files, and local config out of runtime artifacts.
- Verify resources are packaged correctly when adding files under `src/main/resources`.
- Keep startup behavior deterministic and fail fast on invalid configuration.
- For CLIs, verify main class, argument handling, exit codes, stdout/stderr behavior, and executable packaging.
- For Spring Boot apps, verify `bootJar` or the project's equivalent runnable artifact when runtime behavior changes.
- Avoid container images unless the project deploys that way; if used, keep images minimal and avoid baking secrets into
  layers.
- Document how to build and run the artifact when packaging behavior changes.

### IntelliJ IDEA

- IntelliJ IDEA is a preferred development environment, but the project must still build from the command line.
- Do not rely on IDE-only build steps, generated files, run configurations, or annotation-processing settings without
  reflecting them in Maven/Gradle.
- Keep IDE metadata out of source control unless the project intentionally shares it.
- If annotation processing is required, ensure Maven/Gradle configuration is sufficient for both IntelliJ and CI.

## Optional Profile: Spring Boot Platform

Use this profile when the project is a Spring Boot application or platform.

### Spring Style

- Use constructor injection.
- Keep business logic out of controllers, configuration classes, persistence adapters, and templates.
- Use `@ConfigurationProperties` for structured configuration.
- Avoid direct `System.getenv()` access in business logic.
- Keep transaction boundaries explicit and close to service/use-case operations.
- Use `jakarta.persistence` for modern Spring Boot/Hibernate projects.
- Avoid leaking persistence entities directly through public APIs.
- Avoid `@Data` on JPA entities.
- Keep entity equality, `toString`, and lazy relationships safe from recursion and accidental loading.
- Prefer explicit fetches over changing relationships to eager loading.
- Use Flyway or the project's established migration tool for schema changes.
- Keep Hibernate `ddl-auto` out of production schema management; prefer validation when migrations own the schema.

### Spring OpenAPI

- Prefer `springdoc-openapi` for OpenAPI support in Spring Boot applications unless the project already has another
  established OpenAPI tool.
- Expose OpenAPI JSON and Swagger UI only where they are useful for development, integration, or approved consumers.
- Restrict or disable Swagger UI in production when public interactive API exploration is not intended.
- Keep OpenAPI annotations close to the API boundary; avoid polluting domain models with web documentation concerns.
- Prefer generated schemas from request/response DTOs, with explicit annotations only where they clarify validation,
  examples, auth, or edge cases.
- Keep documented examples safe: no real tokens, secrets, personal data, internal URLs, or production identifiers.

### Persistence, Search, and Migrations

- Use migrations for schema changes when the project has a migration tool.
- Never make destructive migration changes without explicit approval.
- Test custom queries, projections, migrations, and search mappings.
- Do not silently replace production-like dependencies with incompatible in-memory substitutes when behavior matters.
- Use Testcontainers or real integration dependencies when the project already relies on them.

### Messaging and Background Work

- Treat message schemas and task states as internal contracts.
- Make handlers idempotent where practical.
- Validate payloads before processing.
- Add tests for retry, failure, and invalid-message behavior when touched.
- Avoid starting new background behavior without explicit product need and clear operational controls.

### Spring Security and Configuration

- Keep CORS, CSRF, authentication, and authorization configuration explicit.
- No hardcoded credentials, tokens, URLs, ports, or private infrastructure details.
- Keep environment-specific settings in profiles, deployment config, or ignored local files.
- Do not change defaults that affect production behavior without calling it out.

### Spring Boot Actuator

- Prefer Spring Boot Actuator for non-trivial services that need health, readiness, liveness, metrics, or operational
  diagnostics.
- Expose only the endpoints needed by the deployment environment.
- Keep sensitive Actuator endpoints disabled, authenticated, or network-restricted.
- Health/readiness endpoints should not leak secrets, credentials, connection strings, or detailed dependency internals.
- Use Actuator metrics and health checks for operational visibility instead of ad hoc diagnostic endpoints.
- Document any newly exposed Actuator endpoint and its intended audience.

### Spring Testing

- Use unit tests for services, validation, mapping with logic, and domain rules.
- Use integration tests for repositories, messaging, external service adapters, and application wiring.
- Use `*Test` for unit tests and `*IT` or the project's convention for integration tests.
- Maintain meaningful service-layer coverage when the project tracks coverage.
