# AGENTS.md - Java Application v1.3

Guidance for Java applications, including Spring Boot, CLI tools, REST services, persistence,
browser frontends, packaging, and MCP servers. Project-specific rules belong in `docs/`; keep this
framework-owned file unchanged.

## How To Use

- Apply **Core Rules** to every Java task.
- Apply only the profiles that match the repository: Maven, Gradle, Lombok, CLI, REST, Persistence,
  Dependency Policy, Web Frontend, Packaging, Spring Boot, MCP Server.
- Project documents in `docs/` override this starter when they disagree.
- In Clarity projects, `docs/00-ai-context.md` routes you to the exact current context. Never scan
  `docs/archive/` unless the task explicitly requires historical evidence.

## Core Rules

### Operating principles

- Deliver the complete requested behavior; do not offer a partial skeleton.
- Stay inside scope. Avoid unrelated refactors, renames, formatting churn, or dependency churn.
- Do not introduce new dependencies unless the task explicitly requires them.
- Preserve public behavior and repository conventions unless the task explicitly changes them.
- Keep the project compilable and tests meaningful at each coherent step; do not proceed on a red
  build.
- Prefer standard Java/JDK/framework facilities over custom infrastructure.
- Never commit credentials, tokens, personal data, private paths, production secrets, or generated
  secret material.
- Do not weaken security, validation, tests, or quality gates to make a change pass.
- Ask only at an Escalation/Reserved boundary. Resolve local reversible implementation details from
  repository evidence and documented intent.

### Workflow

1. Use the runtime-injected instructions; do not reread `AGENTS.md` merely because a prompt names it.
2. Read `docs/00-ai-context.md` when present, then only task-relevant hot/warm sections. For a
   dispatched Clarity run, use its frozen context pack instead of scanning `docs/`. Read the
   remaining documents only when the task touches their subject, never speculatively:
   - `docs/03-sad.md` — the change adds or moves a component, crosses a module boundary, or the
     destination is unclear
   - `docs/02-requirements.md` — the task touches functional behavior
   - `docs/04-data-model-api.md` — the task touches persistence, data structures, or API contracts
3. Inspect build files, relevant source, tests, and configuration before editing — never guess field
   names or method signatures.
4. Identify the affected boundary: domain, persistence, API, UI, integration, packaging, operations.
5. For non-trivial logic, write or update a failing test first when the repository supports it.
6. Implement the smallest coherent change and run targeted checks before broader checks.
7. Update authoritative Clarity documents only when requirements, architecture, contracts,
   deployment, testing, operations, or durable decisions actually changed.
8. Report completion, verification, material assumptions, and unresolved Escalation/Reserved items.

### When dispatched by an orchestrator

- Goal, Included, Excluded, requirements, and documented architecture are authoritative.
- Resolve local reversible plan gaps from repository evidence when they remain inside those
  boundaries; record the correction.
- Stop only when continuing requires a material scope/architecture/security/privacy/cost change,
  incompatible product behavior, or another Reserved action.
- Do not invoke another AI CLI or orchestration skill; you are the assigned execution level.
- Stay inside the requested report budget.
- Do not commit unless the orchestrator explicitly assigns commit responsibility.

### Java style

- Follow the repository's Java version, formatter, compiler settings, package layout, and naming;
  absent one, default to the Google Java Style Guide: 4-space indentation, UTF-8 source, ~120-char
  lines.
- Prefer small cohesive types, explicit dependencies, constructor injection, immutable values, and
  clear ownership of mutable state.
- Prefer records for immutable data carriers when the configured Java baseline supports them and the
  framework does not require proxy-friendly mutable entities.
- Use interfaces where they define a real boundary or multiple implementations, not mechanically.
- Prefer explicit types unless local style already favors `var` and the initializer is obvious; use
  constants or enums instead of magic values, and imports instead of fully qualified names in method
  bodies.
- Avoid static mutable state, service locators, hidden global configuration, and reflection when a
  typed alternative exists.
- Keep exceptions meaningful. Preserve causes, map them at the appropriate boundary, prefer unchecked
  exceptions for validation and programming errors unless the API/domain needs checked exceptions,
  and never use broad catch blocks to hide failures.
- Handle nullability explicitly. Prefer domain types, `Optional<T>` at return boundaries where
  established (not fields/parameters, unless local style differs), `Objects.requireNonNull` at
  constructors/boundaries, and validation at ingress over scattered null checks.
- Prefer early returns and named boolean conditions over deeply nested logic or an unnecessary `else`
  after a return/throw.
- Keep concurrency explicit: state thread-safety assumptions and avoid blocking calls on
  event-loop/virtual-thread-sensitive paths.

### Logging, security, and configuration

- Use SLF4J with Logback as the standard implementation (Spring Boot's default); use parameterized
  messages, never string concatenation, and no `System.out`/`System.err` or stack traces in
  production paths.
- Choose levels deliberately: `debug` for diagnostics, `info` for meaningful lifecycle events, `warn`
  for recoverable problems, `error` for failures needing attention.
- Log operational context, never passwords, tokens, session identifiers, raw personal data, or full
  sensitive payloads.
- Validate untrusted input at the boundary and encode output for its destination.
- Use parameterized database access; never concatenate untrusted values into SQL, shell commands,
  URLs, paths, or expressions.
- Enforce authorization server-side at the operation/resource boundary, not only in UI routing.
- Keep secrets outside source control and document required environment/property names, defaults,
  allowed values, and whether they are required.
- Prefer typed configuration with validation and fail fast at startup with clear messages on missing
  production-critical values; do not silently invent production defaults for credentials, hosts,
  ports, storage, or security.

### Testing

- Use the repository's existing framework; prefer TDD (failing test → smallest implementation →
  green → refactor) for service logic, parsers, algorithms, and bug fixes. Tests-after is fine for
  thin wiring, trivial CRUD/DTO serialization, and generated code.
- Unit-test business rules without external infrastructure; use Mockito for mocks and AssertJ (or the
  project's established fluent assertion style) when it improves failure messages.
- Integration-test boundaries that rely on framework wiring, serialization, persistence, security,
  transactions, messaging, or external protocols.
- Use `@TempDir` (or equivalent isolation) for tests that write files; mock network calls and
  external processes in unit tests.
- Cover negative, boundary, authorization, validation, concurrency, and recovery paths when relevant.
- Tests must be deterministic and independent of order. Each test restores shared state it changes.
- Do not mock the type under test, remove tests, or replace the behavior being verified with an
  incompatible fake.
- A skipped/flaky test (`@Disabled`, `@Ignore`, assumptions) needs a recorded reason and follow-up, or
  explicit approval; never hide it by weakening assertions.
- Run the smallest relevant suite first, then the repository's normal verification gate.

### Documentation and Definition of Done

- Add Javadoc for all newly added or materially changed types and methods — public, protected, and
  private — documenting behavior, invariants, edge cases, and failure modes; use `{@link TypeName}`
  for existing types, and do not restate the method/class name or add comments that merely restate
  syntax.
- Update README, usage docs, API docs, or release notes when user-visible behavior changes.

A change is done when:

- the project compiles with its configured toolchain;
- relevant tests and static/format checks pass, with no known regressions;
- changed public/API/data behavior is documented and covered;
- security-sensitive paths have explicit failure handling;
- no unrelated files, generated artifacts, formatting churn, or secrets are included;
- affected Clarity documents reflect durable state changes.

Completion notes state whether the task is done, commands executed, and test results
(run/failure/error/skipped counts when reported). Do not list changed files — the diff shows them.
If checks could not run locally, explain why and name the CI job that should run instead.

## Profile: Maven

Apply when `pom.xml` exists.

- Use the project wrapper (`./mvnw`) when present; otherwise use the documented Maven command.

```bash
./mvnw -q test
./mvnw -q -Dtest=SpecificTest test
./mvnw -q clean test
./mvnw -q verify
```

- Respect Maven Enforcer/toolchains, profiles, modules, dependencyManagement, and pluginManagement;
  prefer a build-level guard such as `requireJavaVersion` over local shell/agent bootstrap for a
  fixed Java baseline.
- Add dependencies in the owning module only; use managed versions rather than overriding a platform,
  and use correct scopes (`test`, `provided`, `runtime`, or compile).
- Do not add repositories or plugin repositories without a task-driven reason.
- Run static analysis with `maven-pmd-plugin` bound to `verify`: fail the build on PMD's
  `bestpractices`, `errorprone`, `design`, `codestyle`, `documentation`, `multithreading`, and
  `security` category rulesets; run `performance.xml` in a second execution with
  `failOnViolation=false`, reporting without blocking.

## Profile: Gradle

Apply when `build.gradle[.kts]` exists.

- Use `./gradlew`; do not depend on a globally installed Gradle.

```bash
./gradlew test
./gradlew check
./gradlew build
```

- Respect version catalogs, convention plugins, toolchains, source sets, and module boundaries; keep
  dependency versions in the existing central location.
- Use the narrow task first, then the project's normal `check`/build gate.
- Do not bypass dependency locking, verification metadata, or configured quality tasks, and do not
  make the build depend on IDE-only behavior.
- Run static analysis with the `pmd` plugin: configure `pmdMain`/`pmdTest` with the same seven
  blocking category rulesets as Maven, plus a separate PMD task for `performance.xml` with
  `ignoreFailures = true`, reporting without blocking `check`.

## Profile: Lombok

Apply only when Lombok already exists or the project explicitly chooses it; never introduce it merely
to remove a few accessors.

- Use `@RequiredArgsConstructor` for constructor injection and `@Slf4j` for logging unless the
  project has a different established pattern.
- Prefer records, `@Value`, or final fields for immutable data; use `@Builder` for complex
  construction, combined with no-args/all-args constructors when deserialization frameworks require
  them.
- Avoid `@Data` on JPA entities and other classes where generated equality, mutability, or `toString`
  exposure is unsafe; prefer granular `@Getter`/`@Setter` and
  `@EqualsAndHashCode(onlyExplicitlyIncluded = true)` with explicit identity fields instead.
- Exclude lazy collections, bidirectional relationships, self-references, and sensitive fields from
  generated `toString`.
- Avoid `@SneakyThrows`; handle or propagate exceptions explicitly.
- In Maven `annotationProcessorPaths`, put Lombok before MapStruct or any processor that depends on
  Lombok-generated members.

## Profile: CLI

- Prefer Picocli for non-trivial CLI applications — subcommands, typed options, validation, generated
  help, exit codes, or shell completion; hand-written parsing is fine only for tiny tools with one or
  two flags and no expected growth.
- Keep command classes thin: parse input, call application/domain services, format output, return an
  exit code. Do not hide business logic inside command classes.
- Preserve backward compatibility for flags, positional arguments, output formats, and exit codes;
  validate arguments before side effects, send errors to stderr and normal output to stdout, and
  avoid stack traces on fatal user errors by default.
- Treat file paths as untrusted input; use `Path`/`Files` APIs and atomic writes for replacing
  important files.
- Test parsing, exit status, stdin/stdout/stderr, filesystem failure (with `@TempDir`, never the
  project tree or global `/tmp`), and cancellation paths.

## Profile: REST Web

- Keep controllers thin: HTTP adaptation, validation, authorization boundary, service call, response.
- Use explicit request/response DTOs; do not expose persistence entities as API contracts.
- Treat the repository's versioned OpenAPI file as the canonical API contract when one exists; keep
  prose documentation and runtime-generated schemas aligned with it.
- Keep pagination, sorting, filtering, idempotency, and versioning consistent with the documented API.
- Use a consistent structured error response format (a global `@ControllerAdvice` or equivalent
  established mechanism in Spring); never expose stack traces, class names, SQL errors, or internal
  implementation details to clients.
- Use status codes consistently: `400` for malformed requests, `401`/`403` for auth failures, `404`
  for missing resources, `409` for conflicts, and `422` when syntactically valid input fails domain
  validation.
- Cover happy path plus validation, authentication/authorization, not-found, conflict, and server
  failure behavior; do not test framework infrastructure unless the project has custom configuration
  logic.

## Profile: Persistence

- Follow the documented database and migration tool. Do not swap database engines in tests when SQL
  dialect, locking, constraints, or migration behavior matters. SQLite suits small local-first,
  desktop, CLI, and embedded deployments; PostgreSQL (or another server database) is usually the
  better default for multi-user, concurrent-write, production services.
- Schema changes require versioned migrations (Flyway by default unless the project uses another
  tool). Never edit an applied production migration — add a new forward one instead. Versions are
  strictly ordered and never reused; destructive changes (`DROP`, `TRUNCATE`, column removal) require
  explicit approval and a rollback plan.
- Keep transaction boundaries in services/use cases, not scattered through controllers. Prefer lazy
  relationships by default and fetch explicitly for use cases that need related data; avoid N+1
  queries, accidental eager loading, unbounded queries, and serialization of lazy proxies. Keep
  `equals`/`hashCode`/`toString` safe for proxies, lazy collections, and bidirectional relationships.
- Use explicit indexes/constraints for real integrity and query needs; keep business logic out of
  repositories.
- Immutable/audit records should reference mutable entities by durable identifiers, not foreign
  keys, for lifecycle independence.
- Test against the same database family as production when dialect/migrations matter (SQLite
  projects against SQLite, not H2); prefer Testcontainers for PostgreSQL/MySQL-style behavior.
- Persistence tests must isolate state. With shared Testcontainers/database instances, each test
  truncates/rolls back what it changes and never depends on execution order.

## Profile: Dependency Policy

- Reuse existing platform/BOM/catalog versions and libraries before adding another dependency.
- Add a dependency only for a task-driven capability that is not reasonably provided by the JDK or
  current stack.
- Prefer mature, maintained libraries with compatible license and security posture; avoid duplicate
  libraries for JSON, HTTP, logging, collections, testing, or validation.
- Be cautious with dependencies that introduce reflection-heavy behavior, bytecode generation, native
  binaries, background threads, network calls, or global state; consider artifact size, startup cost,
  security surface, and transitive dependencies for runtime additions.
- Explain why each new dependency is needed, and remove unused dependencies when the same change
  makes them obsolete.

## Profile: Web Frontend

Apply when Java serves or packages a browser frontend.

- Determine the run model first. **Embedded** (most common): the Java process serves a built static
  frontend — build with `npm run build`; for hot reload, proxy the frontend dev server to the backend
  and enable `spring-boot-devtools`/LiveReload. **Standalone**: a separately deployed frontend with
  its own server — requires `docs/03-sad.md` documentation of CORS and ports. Never infer the model
  from `package.json` alone; if undocumented, ask.
- Use the frontend's own package-manager lockfile and scripts; do not invent a parallel toolchain or
  add frontend dependencies to Java build files.
- Follow `docs/09-visual-profile.md` and its design tokens for all visual values; never hardcode hex
  colors, pixel values, or font names when tokens are available, and do not invent tokens.
- Keep API base URLs and environment differences in configuration, not hardcoded source; treat the
  canonical OpenAPI file referenced by `docs/04-data-model-api.md` as the source of truth.
- Verify the actual rendered experience at supported viewports/states in addition to automated tests;
  cover keyboard navigation, focus, semantics, contrast, loading, empty, error, and disabled states.
- Use Playwright for browser-level and end-to-end tests unless an equivalent framework is already
  established, preferring its built-in locators (`getByRole`, `getByLabel`, `getByText`) over CSS
  selectors and XPath; mock backend/network calls unless the test is explicitly a live integration
  test.
- Keep frontend build artifacts out of Git unless the project explicitly versions them.

### Accessibility Testing

- Run `@axe-core/playwright` against every major view and significant UI state in the Playwright
  suite, at WCAG 2.2 Level AA unless the project documents a different target.
- Treat every violation as a test failure; suppress only with explicit approval and a documented
  reason (`exclude()` for third-party embeds or unfixable platform constraints). Axe covers
  structural/attribute issues only — it does not replace manual keyboard or screen-reader testing.

## Profile: Packaging and Runtime

- Respect the configured Java toolchain and target runtime; do not silently compile for a newer JDK.
- Prefer clean, conventional runnable JAR or Spring Boot executable JAR artifacts before custom
  installers or complex packaging; keep libraries as plain JARs without application runtime behavior,
  and keep dev-only tools, test fixtures, generated debug files, and local config out of runtime
  artifacts.
- Preserve the project's JAR/image/native packaging model, entrypoint, JVM flags, health behavior,
  and configuration injection; keep startup behavior deterministic and fail fast on invalid
  configuration.
- For CLIs, verify main class, argument handling, exit codes, stdout/stderr behavior, and executable
  packaging; for Spring Boot apps, verify `bootJar` (or the project's equivalent runnable artifact)
  when runtime behavior changes.
- Reproducible artifacts should come from CI/build scripts, not an IDE-only workflow.
- For containers, use a non-root runtime where practical, minimal base images, pinned/managed
  versions, explicit health checks, and no embedded secrets.

### IntelliJ IDEA

- Commit only project-level IDE metadata the repository intentionally owns.
- Never depend on personal run configurations, absolute SDK paths, or local caches for correctness;
  the project must still build cleanly from the command line.

## Profile: Spring Boot

- Follow the repository's Spring Boot and Spring Cloud platform versions; do not override managed
  transitive versions casually. Prefer constructor injection. Keep controllers, services/use cases,
  repositories, and configuration responsibilities distinct.
- Use `@ConfigurationProperties` with validation for grouped configuration; avoid direct
  `System.getenv()` access in business logic.
- Keep transaction boundaries explicit; understand proxy limitations and self-invocation. Use
  `jakarta.persistence`, avoid `@Data` on entities, and keep Hibernate `ddl-auto` out of production
  schema management when migrations own the schema.
- Define HTTP contracts independently of entities. Prefer `springdoc-openapi` unless another tool is
  established; in a contract-first project, validate generated schemas against the canonical OpenAPI
  file rather than letting annotations become a second source of truth, and restrict/disable Swagger
  UI in production when public exploration is not intended.
- Security rules must default deny, distinguish authentication from authorization, and cover
  method/resource ownership in tests; keep CORS/CSRF configuration explicit.
- Actuator exposure must be intentional — expose only what the deployment needs, keep sensitive
  endpoints disabled/authenticated/network-restricted, and never leak secrets or dependency
  internals through health/readiness checks.
- For async/background and messaging work, define ownership, retries, idempotency, shutdown,
  observability, and failure handling; validate payloads and test retry, failure, and invalid-message
  behavior. Do not create unmanaged executors.
- Spring tests should use the smallest useful slice: plain unit test, MVC/data slice, then full
  context only when wiring across boundaries is the behavior under test; use `*Test`/`*IT` (or the
  project's convention) to distinguish unit from integration tests.

## Profile: MCP Server

Apply when the project exposes tools, resources, or prompts via the Model Context Protocol. The
official MCP Java SDK (`io.modelcontextprotocol.sdk`) is the foundation; for Spring Boot projects,
`spring-ai-starter-mcp-server` adds auto-configuration and annotation-based tool registration on top
of it.

| Transport | Use when |
| --- | --- |
| STDIO | Local single-client use (Claude Desktop, Claude Code, local agents); no network surface. |
| Streamable HTTP (servlet) | Network-accessible/shared clients — `spring-ai-starter-mcp-server`. |
| Streamable HTTP (reactive) | Same, on a WebFlux project — `spring-ai-starter-mcp-server-webflux`. |

- Use the transport required by the client/environment; do not mix stdio protocol output with logs.
  Do not expose an HTTP transport on a public port without authentication unless the server is
  intentionally public.
- Define tools around bounded user intentions, with typed schemas and deterministic validation. Keep
  `@Tool` methods thin — validate input, delegate to the service layer, return a structured result;
  the annotation is a transport concern, not a place for business logic.
- Tool names/descriptions are part of the client contract; keep them stable or version changes, and
  write precise, action-oriented descriptions — vague ones produce incorrect invocations.
- Resources expose retrievable state; prompts provide reusable, parameterized instructions. Do not
  misuse tools as filesystem/shell escape hatches, and never expose resources containing secrets or
  data the client is not authorized to see.
- Treat all tool arguments and external content as untrusted; never pass input directly to
  `Runtime.exec()`, string-interpolated SQL, or filesystem operations without validation. Apply
  least privilege: expose only what the client needs.
- For HTTP transports, enable authentication (OAuth 2.0 or API key). Log invocations at `INFO`;
  never log sensitive parameter values.
- Unit test the service methods behind each tool independently of MCP. Add integration tests that
  invoke tools through the server for registration, parameter binding, serialization, and error
  handling — invalid/missing/out-of-range input included — plus, for HTTP transport, a server-start
  and list-tools round trip.

---

*Clarity Framework v4.4.0 - Java Application Agent Starter*
