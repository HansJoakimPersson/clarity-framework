# AGENTS.md - Electron Desktop v1.0

Guidance for agents working in Electron desktop applications that should feel native on macOS, Windows, and Linux.
Apply the Core Rules to every Electron project, then apply only the optional profiles that match the project in
front of you.

Electron gives you a browser engine, not a desktop application. Everything that makes an app feel native — window
behaviour, menus, shortcuts, dialogs, theming, and startup timing — has to be built deliberately. Treat "it looks
like a website in a window" as a defect, not a starting point.

## How To Use This Guide

- Always follow **Core Rules**. The Security and Native Platform Integration sections are not optional.
- Add **Renderer Framework** when the renderer uses React, Vue, Svelte, or a similar framework.
- Add **Local Persistence** when the app stores data on disk beyond simple preferences.
- Add **Auto Update** when the app ships updates to users outside an app store.
- Add **Packaging and Distribution** when the project produces installers or signed artifacts.
- Add **Native Modules** when the project depends on compiled Node addons.
- Local project-specific instructions, `CLAUDE.md`, and local `AGENTS.md` files always take precedence when present.

## Core Rules

### Operating Principles

- Deliver the task's full scope. A skeleton or partial implementation offered with "let me know if you want me to
  continue" is an incomplete delivery, not a small one.
- Stay inside the task's scope — no refactors, renames, reformatting, or improvements beyond what the task requires.
- Never weaken a security setting to make a feature work. Find another way or raise the constraint.
- Do not introduce new dependencies unless the task explicitly requires them; every dependency ships to the user's
  machine with full Node privileges in the main process.
- Never commit secrets, tokens, credentials, or signing certificates.
- Keep the build green on every target platform the project supports.

### Workflow

1. Read local project instructions before starting any task. If `CLAUDE.md` or `AGENTS.md` exists, read it.
2. In Clarity Framework projects, read project documentation in this order:
   - `docs/00-ai-context.md` — compressed overview of what the project is, its stack, and current status
   - `docs/plans/` — if a plan governs this task, read it before anything else. Its scope section is
     authoritative; do not re-plan. If the plan is wrong or incomplete, stop and report rather than improvising.
   - `docs/09-grafisk-profil.md` — design tokens, colour palette, typography, spacing, and motion; read before
     touching any visual value. If this file does not exist, do not hardcode visual values — raise the gap instead.
   - `docs/03-sad.md` — architecture, process boundaries, and key design decisions
   - `docs/04-datamodell-api.md` — IPC contracts, data structures, and external API contracts
   - `docs/05-deployment-view.md` — target platforms, packaging, signing, and update channel
3. Determine which process the change belongs in — main, preload, or renderer — before writing any code. If a change
   appears to need code in more than one process, define the IPC contract first.
4. Confirm the development run model before starting anything (see **Development Run Model**).
5. Add or update tests for the changed behaviour.
6. Implement the task in full, within its stated scope.
7. Run targeted tests, and verify on macOS and Windows when the change touches window chrome, menus, shortcuts, or
   file paths.
8. Report whether the task is done. If it is not, say what remains and why. Do not list changed files — the diff
   already shows them. Summarize by affected area only when the change spans several components.

### Process Architecture

- Keep a strict three-way separation: **main** (Node, full privileges), **preload** (bridge, isolated context), and
  **renderer** (UI, no Node access).
- Put all filesystem, network, OS, and child-process work in the main process. The renderer requests it over IPC.
- Keep the preload script thin. It defines the API surface; it does not contain business logic.
- Keep business logic out of `main.ts`/`main.js` itself — put it in modules the main process calls, so it can be unit
  tested without launching Electron.
- Use one `BrowserWindow` per logical window. Do not simulate multiple windows with in-page routing when the user
  expects real OS windows.

### Security

These rules are non-negotiable. They are the defaults in modern Electron; the failure mode is someone disabling them.

- `contextIsolation: true`, `nodeIntegration: false`, and `sandbox: true` on every `BrowserWindow` and every
  `webContents`. Never disable any of them, including "temporarily" during development.
- Never set `webSecurity: false` or `allowRunningInsecureContent: true`.
- Expose functionality to the renderer only through `contextBridge.exposeInMainWorld`, as a set of narrow,
  purpose-named functions. Never expose `ipcRenderer`, `require`, `process`, `fs`, or any Electron module itself.
- Load only application-local content. Never load remote URLs into a window that has any privileged bridge attached.
  Remote content belongs in a `<webview>` or an external browser.
- Set a Content Security Policy for all application windows. Do not rely on the renderer being local as a substitute.
- Handle `setWindowOpenHandler` on every `webContents` and return `{ action: 'deny' }` by default; route legitimate
  external links through `shell.openExternal` after validating the URL scheme against an allowlist (`https:` and
  `mailto:` unless the project needs more).
- Block or explicitly allow in-app navigation with the `will-navigate` event.
- Validate every IPC payload in the main process as untrusted input, including types, ranges, and file paths. Resolve
  and confine paths — never pass a renderer-supplied path to `fs` unchecked.
- Deny `setPermissionRequestHandler` requests by default; allow only the permissions the app actually uses.
- Store secrets with `safeStorage`, never in plain files, `localStorage`, or config JSON.
- Keep Electron itself current. Security fixes only reach users through an Electron upgrade plus a release.

### IPC

- Use `ipcMain.handle` / `ipcRenderer.invoke` for anything with a result. Reserve `webContents.send` for genuine
  main-to-renderer push (progress, OS events, update state).
- Name channels by intent and domain, not by implementation — `settings:save`, not `write-file`.
- Define the IPC surface in one shared type declaration used by preload, main, and renderer, so a contract change
  breaks the build rather than failing at runtime.
- Validate the sender in handlers that perform privileged operations; check `event.senderFrame` against the frames
  the app owns.
- Return structured errors over IPC. Never let a raw main-process exception, stack trace, or absolute path reach the
  renderer UI.
- Keep handlers fast. Long-running work should report progress and be cancellable, not block the reply.

### Native Platform Integration

This section is what separates a native-feeling app from a website in a frame. Apply it on every UI change.

**Application lifecycle**

- On macOS, keep the app running when all windows close, and recreate a window on the `activate` event. On Windows
  and Linux, quit on `window-all-closed`.
- Take a single-instance lock with `app.requestSingleInstanceLock()` and focus the existing window on a second
  launch, unless the app is genuinely multi-instance.
- Register a protocol handler with `app.setAsDefaultProtocolClient` when the app supports deep links, and handle both
  cold start and `second-instance` delivery.

**Windows and chrome**

- Create windows with `show: false` and a `backgroundColor` that matches the theme, then show on `ready-to-show`.
  A white flash on launch is the single most common tell that an app is Electron.
- Persist and restore window size, position, and maximized state across restarts. Validate the restored bounds
  against the current display set before applying them.
- Use platform-appropriate chrome: `titleBarStyle: 'hiddenInset'` with `vibrancy` on macOS, `titleBarOverlay` with
  `backgroundMaterial: 'mica'` on Windows 11. Set `-webkit-app-region: drag` on custom title bars, and
  `-webkit-app-region: no-drag` on every interactive control inside them.
- Never place custom controls where the macOS traffic lights render; account for their position and inset.
- Set sensible `minWidth`/`minHeight` so the layout cannot be broken by resizing.

**Menus and shortcuts**

- Build the application menu with `Menu.buildFromTemplate` using `role:` entries wherever a role exists. Roles give
  correct labels, correct platform placement, correct accelerators, and OS localisation for free.
- Follow platform menu conventions: an app menu named after the application on macOS with About/Preferences/Quit;
  File/Edit/View/Window/Help elsewhere. Do not ship the default menu in a production build.
- Use `CmdOrCtrl` accelerators and honour platform-standard shortcuts. Never reimplement Cut/Copy/Paste/Undo/
  Select All in JavaScript — use the roles, or clipboard and editing behaviour will diverge from the OS.
- Provide a context menu on right-click where the platform provides one, including spellcheck suggestions in text
  inputs via the `context-menu` event.

**System integration**

- Use native dialogs (`dialog.showOpenDialog`, `showSaveDialog`, `showMessageBox`) for file selection and
  destructive confirmations. HTML modals for these read as non-native and lose OS features such as sandbox access
  and recent locations.
- Use the main-process `Notification` API for system notifications, not the renderer's web notifications.
- Follow the system theme via `nativeTheme.shouldUseDarkColors` and the `updated` event. Expose an explicit
  light/dark/system setting that writes `nativeTheme.themeSource`.
- Call `app.addRecentDocument` when the app opens documents, and implement a dock menu on macOS or jump list on
  Windows when the app has recurring entry points.
- Add a tray icon only when the app has genuine background behaviour, with template images on macOS so the icon
  adapts to the menu bar.

**Visual and interaction detail**

- Use the platform UI font stack rather than a bundled web font for interface chrome, unless the graphic profile
  specifies otherwise.
- Disable text selection and the drag-image behaviour on non-content chrome. Selectable interface labels are a
  browser tell.
- Respect `prefers-reduced-motion` and `prefers-color-scheme`. Keep transitions short; desktop apps animate less
  than web pages.
- Keep scrolling native — no custom scrollbars or smooth-scroll hijacking, and no overscroll bounce on non-macOS.
- Ensure full keyboard operability with a visible focus ring, correct tab order, and Escape closing transient UI.

### Development Run Model

- The renderer dev server and the Electron process are one application, started by one command. Never start the
  renderer dev server alone and treat the browser tab as the app — the preload bridge does not exist there, so
  nothing that touches IPC works.
- Use a toolchain that owns both sides — `electron-vite`, Electron Forge with the Vite plugin, or the project's
  established equivalent — so a single `npm run dev` starts the renderer with HMR and launches Electron against it.
- Renderer changes hot-reload. Main and preload changes require an Electron restart; the toolchain should do this
  automatically. Do not add manual restart steps to the workflow.
- Read the project's scripts before running anything. If the run model is not documented in `CLAUDE.md`,
  `AGENTS.md`, or `docs/03-sad.md`, ask before assuming.
- Never run a production build to test a code change during normal development.

### Configuration

- Read configuration in the main process only, and pass what the renderer needs over IPC.
- Store user preferences under `app.getPath('userData')`. Never write to the installation directory — it is
  read-only for non-admin users on Windows and inside the signed bundle on macOS.
- Use `app.getPath()` for every OS location. Never construct platform paths by hand or assume separators.
- Version the preferences file and migrate on read when the shape changes.
- Keep build-time configuration (product name, identifiers, update channel) in the packaging configuration, not
  duplicated in application code.

### Performance

- Never block the main process. A stalled main process freezes every window, the menu bar, and the dock icon.
- Move CPU-bound work to a `utilityProcess`, a worker thread, or a worker in the renderer — chosen by which process
  owns the data, not by convenience.
- Measure startup time to first painted window and treat regressions as defects. Defer non-essential initialisation
  until after `ready-to-show`.
- Load renderer code lazily for views that are not on the startup path.
- Release listeners, timers, and `webContents` references when windows close; leaked windows are a common source of
  growing memory in long-running desktop apps.

### Testing

- Use Playwright's Electron support (`_electron.launch`) for end-to-end tests. It drives the real application, main
  process included.
- Prefer Playwright's built-in locators (`getByRole`, `getByLabel`, `getByText`) over CSS selectors and XPath.
- Use `electronApp.evaluate()` to reach Electron APIs from tests — asserting on window state, menu structure, and
  IPC results.
- Stub native dialogs in tests by overriding `dialog` methods through `electronApp.evaluate()`. Never let a test
  open a real modal file picker.
- Unit test main-process logic directly, without launching Electron. This is why business logic lives in modules
  rather than in `main.ts`.
- Test IPC handlers as functions with untrusted input, including malformed payloads and path traversal attempts.
- Add regression tests for fixed bugs.
- Run accessibility scans with `@axe-core/playwright` against the renderer at WCAG 2.1 Level AA. Treat every
  violation as a test failure. Axe does not cover menus, shortcuts, or window behaviour — verify those manually.

### Documentation and Hygiene

- In Clarity Framework projects, update the relevant docs when their content changes:
  - `docs/03-sad.md` — when process boundaries, window model, or update mechanism change
  - `docs/04-datamodell-api.md` — when the IPC contract or persisted data shape changes
  - `docs/05-deployment-view.md` — when target platforms, packaging, signing, or update channel change
  - `docs/06-testdokumentation.md` — when testing strategy or coverage changes
  - `docs/07-runbook.md` — when installation, update, or rollback procedures change
  - `docs/08-andringshantering.md` — for change tracking
  - `docs/00-ai-context.md` — when stack or project status shifts significantly
- Document every IPC channel with its payload, result, and error cases.
- Add documentation comments for all exported functions and all IPC handlers that are newly added or materially
  changed.

### Definition of Done

- The change works on every platform the project targets, or the untested platforms are named explicitly.
- Security settings are unchanged, and no new privileged surface reaches the renderer.
- New IPC channels are typed, validated, and documented.
- The app still starts without a visible flash and restores its window state.
- Menus, shortcuts, and dialogs follow platform conventions on each target.
- Tests pass, and new behaviour is covered or the verification gap is explained.
- Relevant Clarity Framework docs are updated when their content is affected.

### Explicitly Forbidden

- Disabling `contextIsolation` or `sandbox`, or enabling `nodeIntegration`.
- Exposing `ipcRenderer`, `require`, `fs`, `child_process`, or `process` to the renderer.
- Loading remote content into a privileged window.
- Passing renderer-supplied paths or shell arguments to the filesystem or a child process without validation.
- Writing to the installation directory or hardcoding platform paths.
- Shipping the default application menu or the developer tools open in a production build.
- Bundling private keys, certificates, or notarisation credentials in the repository or the packaged app.

## Optional Profile: Renderer Framework

- Keep the framework confined to the renderer. The main process stays plain Node.
- Access Electron only through the preload bridge — never import Electron modules in framework components.
- Keep IPC calls in a data layer (hooks, stores, services), not scattered through the component tree, so the bridge
  can be mocked in component tests.
- Route within the renderer for in-window navigation; use real windows for anything the user would expect to
  arrange, resize, or move to another display.
- Apply design tokens generated from `docs/09-grafisk-profil.md`. Do not hardcode colours, typography, spacing,
  radii, shadows, or durations.

## Optional Profile: Local Persistence

- Choose storage by data shape: a JSON file under `userData` for preferences, SQLite for relational or growing
  datasets. Do not use `localStorage` or IndexedDB for data the user would consider theirs — renderer storage can be
  cleared by cache eviction and is invisible to backup tools.
- Do all database access in the main process, exposed over IPC.
- Write files atomically — write to a temporary file, then rename. A crash mid-write must not destroy user data.
- Version the schema and migrate forward on startup. Never migrate backward silently.
- Keep the data location documented in `docs/07-runbook.md` so users and support can find, back up, and reset it.
- Encrypt sensitive fields with `safeStorage`, which is bound to the OS keychain.

## Optional Profile: Auto Update

- Use `update-electron-app` with `update.electronjs.org` for public open-source projects, or `electron-updater` with
  a self-hosted or S3-backed feed otherwise. Do not hand-roll an updater.
- Updates require signed builds on both macOS and Windows. An unsigned build cannot be updated safely and should not
  be shipped.
- Serve the update feed over HTTPS only, and verify signatures before applying.
- Never restart the app to apply an update without user consent. Notify, then let the user choose when to relaunch.
- Handle the no-update, failed-check, and download-failed paths explicitly; an updater that fails silently leaves
  users on old, vulnerable Electron versions.
- Keep the update channel (stable, beta) in packaging configuration and document it in `docs/05-deployment-view.md`.

## Optional Profile: Packaging and Distribution

- Use Electron Forge unless the project already uses electron-builder. Do not run both.
- Keep `asar` enabled, and keep `devDependencies` out of the packaged application.
- Sign every release build. On macOS this means a Developer ID certificate plus notarisation and stapling; on
  Windows it means a trusted code-signing certificate. Unsigned builds trigger Gatekeeper and SmartScreen warnings
  that users are right to heed.
- Keep signing credentials in CI secrets, never in the repository or in local configuration files.
- Build each platform's artifacts on that platform, or on a runner that supports the required signing toolchain.
- Set application identifiers, product name, icons, and file associations in packaging configuration, and keep them
  stable across releases — changing the identifier orphans installed applications and their user data.
- Document supported OS versions, artifact types, and the installation procedure in `docs/05-deployment-view.md`.

## Optional Profile: Native Modules

- Prefer a pure-JavaScript dependency when one exists. Native modules add per-platform build, signing, and
  compatibility burden to every release.
- Rebuild native modules against Electron's Node ABI with `@electron/rebuild`; the system Node build will not load.
- Load native modules in the main process only. They cannot be used from a sandboxed renderer.
- Pin the module version and record the required build toolchain in `docs/05-deployment-view.md`.
- Verify native dependencies after every Electron upgrade — an ABI change breaks them silently until runtime.
