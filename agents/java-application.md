# AGENTS.md - Java Application v1.2

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

- Deliver the complete requested behavior; do not offer a partial skeleton as completion.
- Stay inside scope. Avoid unrelated refactors, renames, formatting churn, or dependency churn.
- Preserve public behavior and repository conventions unless the task explicitly changes them.
- Keep the project compilable and tests meaningful at each coherent step.
- Prefer standard Java/JDK/framework facilities over custom infrastructure.
- Never commit credentials, tokens, personal data, private paths, production secrets, or generated
  secret material.
- Do not weaken security, validation, tests, or quality gates to make a change pass.
- Ask only at an Escalation/Reserved boundary. Resolve local reversible implementation details from
  repository evidence and documented intent.

### Workflow

1. Use the runtime-injected instructions; do not reread `AGENTS.md` merely because a prompt names it.
2. Read `docs/00-ai-context.md` when present, then only task-relevant hot/warm sections. For a
   dispatched Clarity run, use its frozen context pack instead of scanning `docs/`.
3. Inspect build files, relevant source, tests, and configuration before editing.
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

- Follow the repository's Java version, formatter, compiler settings, package layout, and naming.
- Prefer small cohesive types, explicit dependencies, constructor injection, immutable values, and
  clear ownership of mutable state.
- Prefer records for immutable data carriers when the configured Java baseline supports them and the
  framework does not require proxy-friendly mutable entities.
- Use interfaces where they define a real boundary or multiple implementations, not mechanically.
- Avoid static mutable state, service locators, hidden global configuration, and reflection when a
  typed alternative exists.
- Keep exceptions meaningful. Preserve causes, map them at the appropriate boundary, and never use
  broad catch blocks to hide failures.
- Handle nullability explicitly. Prefer domain types, Optional at return boundaries where established,
  and validation at ingress over scattered null checks.
- Keep concurrency explicit. State thread-safety assumptions and avoid blocking calls on event-loop
  or virtual-thread-sensitive paths.

### Logging, security, and configuration

- Use the project's logging facade; no `System.out`/stack traces in production paths.
- Log operational context, never passwords, tokens, session identifiers, raw personal data, or full
  sensitive payloads.
- Validate untrusted input at the boundary and encode output for its destination.
- Use parameterized database access; never concatenate untrusted values into SQL, shell commands,
  URLs, paths, or expressions.
- Enforce authorization server-side at the operation/resource boundary, not only in UI routing.
- Keep secrets outside source control and document required environment/property names.
- Prefer typed configuration with validation and fail fast on missing production-critical values.
- Do not silently invent production defaults for credentials, hosts, ports, storage, or security.

### Testing

- Use the repository's existing framework and conventions.
- Unit-test business rules without external infrastructure.
- Integration-test boundaries that rely on framework wiring, serialization, persistence, security,
  transactions, messaging, or external protocols.
- Cover negative, boundary, authorization, validation, concurrency, and recovery paths when relevant.
- Tests must be deterministic and independent of order. Each test restores shared state it changes.
- Do not mock the type under test or replace the behavior being verified with an incompatible fake.
- A skipped/flaky test needs a recorded reason and follow-up; never hide it by weakening assertions.
- Run the smallest relevant suite first, then the repository's normal verification gate.

### Documentation and Definition of Done

A change is done when:

- the project compiles with its configured toolchain;
- relevant tests and static/format checks pass;
- changed public/API/data behavior is documented and covered;
- security-sensitive paths have explicit failure handling;
- no unrelated files, generated artifacts, or secrets are included;
- affected Clarity documents reflect durable state changes.

## Profile: Maven

Apply when `pom.xml` exists.

- Use the project wrapper (`./mvnw`) when present; otherwise use the documented Maven command.
- Respect Maven Enforcer/toolchains, profiles, modules, dependencyManagement, and pluginManagement.
- Prefer `./mvnw test` for targeted work and the repository's documented verification command for
  completion.
- Add dependencies in the owning module only; use managed versions rather than overriding a platform.
- Do not add repositories or plugin repositories without a task-driven reason.

## Profile: Gradle

Apply when `build.gradle[.kts]` exists.

- Use `./gradlew`; do not depend on a globally installed Gradle.
- Respect version catalogs, convention plugins, toolchains, source sets, and module boundaries.
- Use the narrow task first, then the project's normal `check`/build gate.
- Do not bypass dependency locking, verification metadata, or configured quality tasks.

## Profile: Lombok

Apply only when Lombok already exists or the project explicitly chooses it.

- Match existing annotations and IDE/build configuration.
- Do not add Lombok merely to remove a few accessors.
- Be cautious on JPA entities: equality, `toString`, builders, lazy relations, and generated
  constructors can change persistence behavior.
- Keep generated behavior obvious enough that tests and static analysis still describe the contract.

## Profile: CLI

- Keep parsing, domain work, and presentation separate.
- Use the established CLI library and exit-code convention.
- Validate arguments before side effects; send errors to stderr and normal output to stdout.
- Preserve scripting behavior: stable exit codes, deterministic machine-readable output when offered,
  and no interactive prompt in non-interactive mode.
- Treat file paths as untrusted input; use atomic writes for replacing important files.
- Test parsing, exit status, stdin/stdout/stderr, filesystem failure, and cancellation paths.

## Profile: REST Web

- Keep controllers thin: HTTP adaptation, validation, authorization boundary, service call, response.
- Use explicit request/response DTOs; do not expose persistence entities as API contracts.
- Preserve status-code and error-body conventions.
- Validate request shape and domain invariants at the right layer.
- Keep pagination, sorting, filtering, idempotency, and versioning consistent with the documented API.
- Cover happy path plus validation, authentication/authorization, not-found, conflict, and server
  failure behavior.

## Profile: Persistence

- Follow the documented database and migration tool; schema changes require versioned migrations.
- Never edit an applied production migration. Add a new forward migration and document rollback when
  the project requires one.
- Keep transaction boundaries in services/use cases, not scattered through controllers.
- Avoid N+1 queries, accidental eager loading, unbounded queries, and serialization of lazy proxies.
- Use explicit indexes/constraints for real integrity and query needs.
- Immutable/audit history should reference mutable entities by durable identifiers when lifecycle
  independence is required; do not create foreign keys that prevent legitimate cleanup.
- Persistence tests must isolate state. With shared Testcontainers/database instances, each test
  truncates/rolls back what it changes and never depends on execution order.

## Profile: Dependency Policy

- Reuse existing platform/BOM/catalog versions and libraries before adding another dependency.
- Add a dependency only for a task-driven capability that is not reasonably provided by the JDK or
  current stack.
- Prefer mature, maintained libraries with compatible license and security posture.
- Avoid duplicate libraries for JSON, HTTP, logging, collections, testing, or validation.
- Remove unused dependencies when the same change makes them obsolete.

## Profile: Web Frontend

Apply when Java serves or packages a browser frontend.

- Determine the run model first: backend-served assets versus a separate development server.
- Use the frontend's own package-manager lockfile and scripts; do not invent a parallel toolchain.
- Keep API base URLs and environment differences in configuration, not hardcoded source.
- For visual changes, follow `docs/09-visual-profile.md`; do not invent design tokens.
- Verify the actual rendered experience at supported viewports/states in addition to automated tests.
- Cover keyboard navigation, focus, semantics, contrast, loading, empty, error, and disabled states.
- Keep frontend build artifacts out of Git unless the project explicitly versions them.

## Profile: Packaging and Runtime

- Respect the configured Java toolchain and target runtime; do not silently compile for a newer JDK.
- Preserve the project's JAR/image/native packaging model, entrypoint, JVM flags, health behavior,
  and configuration injection.
- Reproducible artifacts should come from CI/build scripts, not an IDE-only workflow.
- For containers, use a non-root runtime where practical, minimal base images, pinned/managed
  versions, explicit health checks, and no embedded secrets.

### IntelliJ IDEA

- Commit only project-level IDE metadata the repository intentionally owns.
- Never depend on personal run configurations, absolute SDK paths, or local caches for correctness.

## Profile: Spring Boot

- Follow the repository's Spring Boot and Spring Cloud platform versions; do not override managed
  transitive versions casually.
- Prefer constructor injection. Keep controllers, services/use cases, repositories, and configuration
  responsibilities distinct.
- Use `@ConfigurationProperties` with validation for grouped configuration.
- Keep transaction boundaries explicit; understand proxy limitations and self-invocation.
- Define HTTP contracts independently of entities and document them with the project's OpenAPI source.
- Security rules must default deny where appropriate, distinguish authentication from authorization,
  and cover method/resource ownership in tests.
- Actuator exposure must be intentional; do not expose sensitive configuration or environment data.
- For async/background work, define ownership, retries, idempotency, shutdown, observability, and
  failure handling. Do not create unmanaged executors.
- Spring tests should use the smallest useful slice: plain unit test, MVC/data slice, then full
  context only when wiring across boundaries is the behavior under test.

## Profile: MCP Server

- Use the transport required by the client/environment; do not mix stdio protocol output with logs.
- Define tools around bounded user intentions, with typed schemas and deterministic validation.
- Tool names/descriptions are part of the client contract; keep them stable or version changes.
- Resources expose retrievable state; prompts provide reusable instructions. Do not misuse tools as
  unbounded filesystem/shell escape hatches.
- Treat all tool arguments and returned external content as untrusted.
- Enforce filesystem/network/credential permissions explicitly and return safe, actionable errors.
- Test schema validation, transport framing, cancellation/timeouts, permission failures, and malformed
  client input.

---

*Clarity Framework v4.3.1 - Java Application Agent Starter*
