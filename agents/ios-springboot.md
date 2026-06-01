# AGENTS.md - iOS/iPadOS App + Spring Boot Backend v1.0

Guidance for agents working in a monorepo or closely coupled project with a Spring Boot backend and a native
iOS/iPadOS frontend in Swift. Apply the Core Rules to every task, then apply the profiles that match the surface
being changed. Always read the Integration Contract section before touching anything that crosses the client–server
boundary.

## How To Use This Guide

- Always follow **Core Rules**.
- Add **Spring Boot Backend** when the task touches the Java server.
- Add **iOS/iPadOS Frontend** when the task touches the Swift app.
- Add **Integration Contract** whenever a change affects the API — request/response shapes, authentication,
  endpoints, error responses, or versioning. This profile applies even if only one side is changing.
- Add **Authentication** when the task involves login, token handling, session management, or protected endpoints.
- Add **Persistence** when the task involves the server-side database (JPA, Flyway, DBI).
- Add **Distribution** when the task involves TestFlight, App Store submission, or backend deployment.
- Local project-specific instructions, `CLAUDE.md`, and local `AGENTS.md` files always take precedence when
  present.

---

## Core Rules

### Operating Principles

- Keep changes minimal and localized — no drive-by refactors outside the task scope.
- The API contract is a shared public interface. Changes to it affect both sides simultaneously; treat API changes
  as the highest-risk category of change in this project.
- Never commit secrets, credentials, tokens, personal data, or environment-specific values in source code.
- Keep both the server and the app buildable and runnable at all times. A change is not done if either side is
  broken.
- Prefer public Apple APIs and standard Spring/Java conventions. Do not introduce exotic dependencies to either
  side without a clear task-driven reason.

### Workflow

1. Read local project instructions before starting any task. If `CLAUDE.md` or `AGENTS.md` exists, read it.
2. In Clarity Framework projects, read project documentation in this order:
   - `docs/00-ai-context.md` — stack overview, current status, and which part of the monorepo owns what
   - `docs/03-sad.md` — architecture, component responsibilities, and which layer owns what decisions
   - `docs/04-datamodell-api.md` — API contracts, authentication flows, and data model; read this before any
     task that touches network behavior
   - `docs/02-kravdokumentation.md` — requirements context when the task touches functional behavior
   - `docs/05-deployment-view.md` — deployment and distribution context when the task affects builds
3. Determine which side the task primarily affects — backend, frontend, or both — before writing any code.
4. If the task crosses the API boundary, read `docs/04-datamodell-api.md` and all affected endpoint definitions
   before proceeding.
5. Use TDD for non-trivial logic on both sides. Write or update the failing test first, implement the smallest
   change, then refactor while keeping tests green.
6. Run tests after every completed step on the affected side. Stop and fix before continuing.
7. Mark completed tasks in `TASKS.md` (if present) and continue to the next without waiting.
8. Define "done" as: server compiles and tests pass + app builds and tests pass + the integration surface is
   consistent across both sides.

### Definition of Done

- Behavior is implemented and scoped to the request.
- The Spring Boot application compiles and all relevant tests pass.
- The iOS app builds for the simulator and all relevant tests pass.
- The API contract in `docs/04-datamodell-api.md` is updated if the task changed any endpoint, field, error
  response, or authentication behavior.
- Authentication, error handling, and loading/empty/error states are coherent across both sides.
- No secrets, credentials, tokens, or personal data are committed.
- No unrelated dependency churn, formatting churn, or refactoring is included.
- Relevant Clarity Framework docs are updated when their content is affected.
- Completion notes always include modified files, commands executed, and test results for both sides.
- If tests or checks could not run locally, explain why and name the CI pipeline or command that should run
  instead.

### Explicitly Forbidden

- Changing an existing API field name, type, or removing a field without explicit approval and a versioning plan.
- Hardcoded backend URLs, ports, secrets, or environment-specific values in source code on either side.
- Logging sensitive data, tokens, personal data, or full request/response bodies at any level.
- Private Apple APIs.
- Skipping or suppressing failing tests without explicit approval.
- Storing authentication tokens anywhere other than the iOS Keychain.

---

## Integration Contract

Read this section before any task that touches endpoints, request/response shapes, authentication, error handling,
or API versioning. This is the highest-risk surface in the project.

### The API Is a Shared Interface

- `docs/04-datamodell-api.md` is the source of truth for the API contract. Keep it current; if the code and the
  doc disagree, fix both.
- Every field name, type, nullability, and HTTP status code is part of the contract. Changes to any of these are
  breaking changes for the iOS client.
- Additive changes (new optional fields, new endpoints) are safe. Removals, renames, and type changes are
  breaking.
- When a breaking change is genuinely needed, update both sides in the same commit or PR, document the change in
  `docs/08-andringshantering.md`, and consider API versioning.

### Error Response Shape

- Define a single structured error response format and use it consistently across all endpoints.
- The iOS client must be able to parse every error response without crashing. Agree on the shape in
  `docs/04-datamodell-api.md` and do not deviate from it.
- Never expose stack traces, class names, SQL errors, or internal server details in error responses.
- Use HTTP status codes consistently: `400` malformed request, `401` unauthenticated, `403` forbidden, `404`
  not found, `409` conflict, `422` domain validation failure, `500` unexpected server error.

### Development Networking

- iOS Simulator can reach the development machine's loopback address directly. Use `http://localhost:PORT` or
  `http://127.0.0.1:PORT` in the simulator build configuration.
- Physical devices cannot reach `localhost`. Use the development machine's LAN IP address, a tunneling tool
  (e.g., ngrok), or a shared development server.
- App Transport Security (ATS) blocks plain HTTP in production builds. For local development only, add an ATS
  exception for `localhost` in `Info.plist`; document this exception and ensure it is not present in release
  builds.
- Never hardcode IP addresses or ports in source code. Use build configuration files, `.xcconfig`, or a project
  configuration layer that can be overridden per environment.

### API Versioning

- If the project prefixes routes with a version (e.g., `/api/v1/`), respect it consistently on both sides.
- If the project does not yet have versioning and a breaking change is needed, introduce a versioning strategy
  before making the change; document the decision in `docs/08-andringshantering.md`.

---

## Spring Boot Backend Profile

Apply this profile when the task touches the Java server.

### Backend Operating Principles

- Keep business logic out of controllers. Controllers validate input, call service or use-case methods, and return
  structured responses.
- Keep request/response DTOs separate from JPA entities and domain objects.
- Validate all request input at the controller boundary.
- Treat the API contract as immutable unless a versioned change is planned.

### Maven Commands

Prefer Maven Wrapper when present:

```bash
./mvnw -q test
./mvnw -q clean test
./mvnw -q spring-boot:run
./mvnw -q -DskipTests package
```

### Spring Boot Style

- Use constructor injection.
- Use `@ConfigurationProperties` for structured configuration.
- Keep transaction boundaries in service or use-case classes, not in controllers.
- Use Flyway for schema migrations when the project has a relational database.
- Keep `ddl-auto` out of production schema management; prefer `validate` when migrations own the schema.
- Enable `spring-boot-devtools` during local development for fast class reloading without full JVM restarts.

### REST API Rules

- Keep resource paths stable and lowercase with hyphens.
- Use standard HTTP methods: `GET` for reads, `POST` for creation, `PUT`/`PATCH` for updates, `DELETE` for
  removal.
- Return structured JSON for both success and error responses; never return plain strings as API responses.
- Validate and sanitize all input. Return `400` or `422` with a structured error body for invalid input; do not
  let validation errors produce `500` responses.
- Keep OpenAPI documentation current when endpoints change. Prefer `springdoc-openapi` unless the project uses
  another established tool.

### Backend Testing

- Unit test service logic, validation, and domain rules.
- Integration test controllers, persistence, and application wiring.
- Test all error paths — invalid input, missing resources, auth failures — to verify the structured error response
  shape.
- Use `*Test` for unit tests and `*IT` for integration tests.

---

## iOS/iPadOS Frontend Profile

Apply this profile when the task touches the Swift app.

### iOS Operating Principles

- Treat product correctness, user safety, privacy, and App Store viability as first-class constraints.
- Keep UI updates on the main actor. Never block the main thread with network calls, file I/O, or computation.
- Prefer public Apple APIs and platform conventions over third-party equivalents.
- Do not add dependencies, background behavior, or entitlements without explicit approval.
- Call out App Store, privacy, permission, or signing risk whenever a change touches those areas.

### Xcode Commands

Use project-specific schemes and an iOS Simulator destination:

```bash
xcodebuild -scheme AppName -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme AppName -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Adjust the simulator name to match what the project uses. Run only commands that apply to the project.

### Swift Style

- Follow the project's formatter and Swift language mode first.
- Use descriptive names and explicit control flow.
- Prefer value types and immutable state where they fit.
- Avoid force unwraps and `try!` unless failure is truly unrecoverable and documented.
- Use access control deliberately; keep implementation details `private` or `fileprivate`.
- Use early returns to keep nesting shallow.
- Add documentation comments for public or reused types with non-obvious contracts.

### Networking

- Use `URLSession` with `async`/`await` for all network calls unless the project already uses an established
  networking library.
- Define a central network layer that owns request construction, authentication header injection, response
  decoding, and error mapping. Do not scatter `URLSession` calls across view models or views.
- Always handle HTTP error status codes explicitly; do not treat a non-2xx response with a parseable body as a
  success.
- Map server error responses to typed Swift errors that the UI can present cleanly.
- Cancel in-flight requests when the initiating view or view model is deallocated or the user navigates away.
- Never log full request or response bodies in production builds.

### UI Architecture

- Follow the project's established UI pattern (SwiftUI, UIKit, or mixed).
- Keep domain logic out of views and view controllers.
- Keep network calls out of views; use view models, stores, or a service layer.
- Validate and handle loading, empty, error, and success states explicitly for every network-backed view.
- Preserve accessibility labels, dynamic type support, keyboard navigation, and focus behavior.

### SwiftUI

- Keep `body` computations cheap. Move expensive work out of `body`.
- Keep view state narrow and explicit.
- Use `@Observable` or `ObservableObject` where they clarify ownership; do not add reactive machinery without a
  reason.
- Add previews for reusable pure SwiftUI views where practical.

### iOS Persistence

- Use `Keychain` for all authentication tokens and sensitive credentials — never `UserDefaults`.
- Use `UserDefaults` only for small, non-sensitive preferences.
- Use Core Data or SwiftData when the app needs a local relational store; use simple file storage for simpler
  needs.
- Keep caches disposable and rebuildable; never store authoritative data only in a local cache.

### Permissions and Privacy

- Request only the permissions the feature genuinely needs.
- Keep `Info.plist` usage descriptions honest and aligned with actual behavior.
- Degrade gracefully when permission is denied or revoked.
- Update privacy documentation when data collection or protected capabilities change.

### iOS Testing

- Unit test pure logic, parsing, state transitions, and network response mapping with XCTest.
- Use XCUITest for critical user flows: login, key screens, error states, and regression-prone interactions.
- Mock network responses in unit and UI tests; do not hit the live server from automated tests.
- Do not remove tests or skip failing tests without explicit approval.
- If UI automation, signing, or App Store paths cannot be validated locally, say so explicitly.

---

## Authentication Profile

Apply this profile when the task involves login, token handling, session management, or protected endpoints.

### Authentication Flow

- The canonical authentication flow for this project is documented in `docs/04-datamodell-api.md`. Read it before
  making any auth-related change.
- The Spring Boot backend issues tokens (typically JWT). The iOS client stores them in the Keychain and attaches
  them to requests via the `Authorization` header.
- Never store tokens in `UserDefaults`, `NSCache`, in-memory globals that survive app restart, or anywhere other
  than the Keychain.

### Spring Boot Auth Rules

- Keep authentication and authorization logic in dedicated filter, interceptor, or security configuration classes.
- Issue tokens with appropriate expiry. Implement and document the refresh flow if the project uses refresh
  tokens.
- Return `401` for unauthenticated requests and `403` for authenticated but unauthorized requests — never mix
  these.
- Never log tokens, passwords, or credentials at any level.

### iOS Auth Rules

- Encapsulate all Keychain access in a dedicated service class. Do not scatter Keychain calls across the codebase.
- Clear stored tokens on logout and on authentication failure responses (`401`) that cannot be recovered by a
  refresh.
- Handle token expiry gracefully: attempt a silent refresh if the project supports it; otherwise redirect to
  login without crashing or showing a raw error.
- Test the unauthenticated state, the token-expired state, and the successful re-authentication flow.

---

## Distribution Profile

Apply this profile when the task involves TestFlight, App Store submission, or backend deployment.

### iOS Distribution

- Use TestFlight for beta distribution. Keep `Info.plist` version and build numbers aligned with each TestFlight
  upload.
- Document the required App Store metadata, privacy labels, and entitlements in `docs/05-deployment-view.md`.
- Call out App Review risk explicitly — locally working behavior is not a guarantee of App Store acceptance.
- Keep signing, entitlements, and bundle identifier configuration in `.xcconfig` or Xcode build settings; do not
  hardcode them in source.
- Ensure ATS exceptions used in development (e.g., `localhost` exception) are absent from release builds.

### Backend Deployment

- The Spring Boot server must be reachable over HTTPS in all non-development environments. ATS on iOS enforces
  this for production builds.
- Document the base URL configuration mechanism: how does the iOS app know which server to connect to in each
  environment (development, staging, production)?
- Keep environment-specific values (URLs, ports, credentials) out of source code; use build configuration,
  environment variables, or a secrets manager.
- Document deployment steps, environment variables, and required infrastructure in `docs/05-deployment-view.md`.
