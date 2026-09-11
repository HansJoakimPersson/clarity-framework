# CHANGELOG

## Clarity Framework

All significant framework changes are recorded here. Releases follow
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/).

A dated heading corresponds to an annotated Git tag. A version that was superseded before it was
ever tagged is folded into the release that shipped it rather than left as a heading pointing at a
tag that does not exist — `framework-update` and `clarity-bootstrap` both resolve the latest stable
tag, so an untagged heading here is a version no project can reach.

## [4.0.0] – 2026-09-11

### Changed (breaking)

- `plan-driven-build`'s `dispatch.sh` now resolves which CLI and model runs each dispatch from
  aimux's own `~/.aimux/config.yaml` instead of a hardcoded `codex` binary and a reimplemented
  `CODEX_HOME` account switch. The dispatch contract changed:
  - `--account NAME[,NAME...]` → `--profile NAME[,NAME...]` (an ordered pool of aimux **profile**
    names, each looked up in `~/.aimux/config.yaml`).
  - `--cli` removed — the CLI now comes from the resolved profile's `cli` field. Switching a
    level's tool is `aimux profile update <name> --cli <cli>`.
  - `--fallback NAME` removed — append `NAME` to the `--profile` list instead.
  - The old `--profile` account-alias is removed; `--profile` now means the aimux profile pool.
  - A pool entry written `cli:NAME` runs that CLI directly with no aimux wrapper and no
    subscription separation — an explicit opt-in fallback, reported on a `FALLBACK:` line.
  - The `DISPATCH` summary line reports `profile=` instead of `account=`.
- `docs/00-ai-context.md`'s AI-workflow runtime-contract table: the "Agent / account pool" column
  is now "Agent / profile pool", and its Model column is a per-dispatch override only (the profile
  carries its own model).

### Migration — projects running `plan-driven-build`

1. `dispatch.sh --account X` → `dispatch.sh --profile X`. A pool stays comma-separated.
2. `dispatch.sh --cli codex` → drop it. Ensure each named profile exists in aimux and is
   authenticated: `aimux profile add <name> --cli codex && aimux auth login <name>`.
3. `dispatch.sh --fallback Y` → append `Y` to the `--profile` list.
4. No aimux installed? Pass `--profile cli:codex` to run codex directly (unseparated), or install
   aimux and add a profile.
5. `docs/00-ai-context.md`: rename the "account pool" column to "Profile pool"; the values are now
   aimux profile names, which already imply the CLI and model.
6. Re-run `framework-update` to refresh the skill copies and the template.

## [3.6.0] – 2026-09-08

### Added

- `docs/00-ai-context.md`'s AI workflow section gained a `Default gate profile` field, and
  `plan-driven-build`'s step 1 now proposes it instead of always defaulting a new plan to
  `semi-automatic`. On a real project the looser profile was re-authorized by hand at least 5
  separate times over two weeks as trust in the workflow grew — a persistent per-project setting
  captures that once.
- `plan-template.md` and `templates/plan.md` (kept identical) gained a third `## Steps` callout: in
  a whole-module compilation language (Java, C#, Go), a step must not write a test referencing a
  production symbol a later step introduces — the module fails to compile, not just to pass, so
  Implementation cannot improvise the missing type. Observed on a real Java plan that split test
  authoring from the implementation it exercised across separate steps.
- `plan-driven-build/SKILL.md`'s Step 0 prerequisite that the working tree be clean now allows a
  user-confirmed exception when the dirty paths belong to other in-flight work (e.g. a concurrent
  agent on the same tree), recorded under the journal's Deviations rather than assumed silently.
  `journal-template.md` gained a matching Deviations bullet. Observed blocking Step 0 twice on a
  real project before being resolved ad hoc.
- `templates/00-ai-context.md`'s `Current status` section gained a callout that it is a snapshot,
  not a log, pointing delivered-FR history to `08-change-management.md` §3 instead. A real project's
  copy of this section grew to over 60% of the document across two weeks before being pruned.
- `framework-update/SKILL.md`'s Step 5 project-owned merge procedure now names the orphaned-content
  heading explicitly (`## Parked content (no matching section in current template)`) and requires
  re-attempting to place previously parked entries against the current template on every subsequent
  run, before parking anything new. Without it, content parked once stayed parked across every later
  release even after a matching section reappeared.
- `plan-template.md` and `templates/plan.md` (kept identical) gained a Definition of Done note: a
  condition that checks an **Excluded** boundary held must scan the whole diff or package, not a
  single named file or class. A narrower check had repeatedly passed while other excluded files were
  touched elsewhere in the same change.
- `plan-driven-build/SKILL.md`'s background-build wait loop now compares `build.log`'s size across
  the wait window and flags a live-but-unchanged log as a likely stall, instead of relying on `kill
  -0` alone. A live PID proves the process exists, not that it is making progress — observed hanging
  silently three separate times on a real project.
- `plan-driven-build/SKILL.md`'s Step 4 background-dispatch guidance now warns against wrapping
  `dispatch.sh --background` in a second layer of backgrounding (`&`, an outer `nohup`, `disown`).
  On a real project a double-backgrounded orphan outlived its own round and later overwrote another
  round's `--log`/`--out` path, which looked like a hostile concurrent writer until traced.
- `plan-driven-build/SKILL.md`'s usage-limit-mid-run guidance now covers borrowing an account from a
  different level's pool for the one blocked call, logged under the journal's Deviations, before
  falling back to stop-and-report or `aimux handoff`. A real project needed this in both directions
  when one level's pool ran out mid-plan while the other still had headroom.
- `plan-driven-build/SKILL.md`'s Step 1 now asks for a full diagnostic sweep before writing `TASK`
  when the task fixes a defect suspected to recur across a family of similar units. A real project
  needed five separate build-and-reverify rounds to work through five sibling test classes because
  each round only surfaced the next one.
- `plan-template.md` and `templates/plan.md` (kept identical) gained a fourth `## Steps` callout: a
  schema-wide directive ("all N tables") must name every affected table explicitly and state what is
  excluded and why, since a count drifts silently as the schema section is edited later.
- `templates/04-data-model-api.md`'s "Data lifecycle and integrity" section gained a rule that an
  append-only or immutable audit table must reference the mutable entity it observed by a plain
  identifier column, never an enforced foreign key — an enforced FK to a mutable row blocked routine
  cleanup and broke test teardown twice on a real project.

### Changed

- `README.md`'s "New project" getting-started step replaced the manual "copy `skills/clarity-bootstrap/`
  to both runtime roots" instruction with a two-command `curl`/`cp` one-liner that fetches
  `SKILL.md` directly, so bootstrapping a new project no longer requires a separate clone of this
  repository first.

## [3.5.0] – 2026-09-03

### Added

- `agents/java-application.md` § Persistence Tests gained guidance on isolating test state when
  test classes share one Testcontainers instance for speed: each test must leave the database as it
  found it (truncate or roll back), never assume execution order. On a real Spring Boot project,
  exactly this cross-contamination pattern cost five separate remediation runs before the actual
  isolation gap was found.
- `dispatch.sh` gained `--mode danger-full-access`, which removes codex's macOS sandbox entirely.
  Scoped to the one case that needs it: Playwright/Chromium's Mach-port rendezvous IPC is denied
  under `--mode workspace-write` (`bootstrap_check_in ... MachPortRendezvousServer: Permission
  denied (1100)`), confirmed against a two-week production run where the same Chromium binary
  launched cleanly unsandboxed on the same machine. `--network` now also applies under this mode.
- `plan-template.md` and `templates/plan.md` (kept identical) gained guidance under `## Steps`: a
  step whose Verification launches a real browser must be its own step, dispatched under
  `--mode danger-full-access` instead of `workspace-write`; and a preference for `(cd dir && cmd)`
  subshells over chaining a relative `cd` into a Verification line, after a chained `cd` left the
  shell in the wrong directory and produced a false "JAR not found" past a successful build.
- `plan-template.md` and `templates/plan.md` `## At closeout` gained a check for whether
  `docs/02-requirements.md` §2.6 has passed roughly 20 active stories without being split into
  `docs/02-user-stories.md` — observed reaching ~4x that threshold unsplit on a real backlog.
- `templates/08-change-management.md` gained a `Decision log` section (Date / Status / Scope plus
  prose), validated against a real project that used the same ad hoc pattern at nearly every plan
  closeout across a two-week run — the plan template already asked "what belongs in
  `docs/08-change-management.md`?" without the template offering a place to answer it.

### Fixed

- `prompts/1-plan.txt` told the planning agent to "touch no file other than the one you are writing
  to," but that dispatch runs under `--mode read-only`, where the agent has no file-write access at
  all — it must reply with the finished plan as its chat message, not attempt to save one. The
  prompt now also requires verifying a cited path exists before including it in the plan.

## [3.3.0] – 2026-08-19

### Fixed

- `ai-usage-guide.md` § 5 still required the review level to use a different account from the plan's
  author, contradicting the rule stated everywhere else in this release. Accounts distribute cost;
  prompts distribute judgment.
- `plan-driven-build/SKILL.md` step 8 referred to the plan's `Vid avslut` section, a heading that no
  longer exists — the template names it `At closeout`. An orchestrator following the instruction
  literally looked for a section that was not there.
- `clarity-bootstrap` step 6 described a marker block without naming the file it belongs in, and its
  `agents-starter` placeholder still read `inga`. The marker now has a named destination and the
  placeholder is English.
- The `skills:` ownership list `framework-update` depends on had no home in
  `templates/00-ai-context.md`, so it could never exist in practice and every update fell back to
  asking the user which skills were Clarity-owned.
- `documentation-guide.md` § 13 introduced the four-level runtime contract with a colon, then placed
  two paragraphs on file ownership before the list that answered it.
- The review dispatch in `plan-driven-build` step 2 took no model override while steps 1, 4, and 5
  did, so a project setting a reasoning model got it everywhere except the review.
- `settings.example.json` anchored its patterns on literal paths (`mkdir -p docs/plans/`,
  `cp .agents/skills/plan-driven-build/`) while `SKILL.md` runs those commands through variables
  (`mkdir -p "$RUN"`). Permission patterns match the command text before expansion, so the file
  prompted for exactly the commands it was meant to pre-approve. The patterns are now the plain
  verbs, and `setup.md` explains the matching rule and states which half of the file is load-bearing:
  `deny` mechanizes the reading budget, `allow` is adjustable convenience.
- `templates/08-change-management.md` was titled "Change Log & Technical Debt" while every reference
  to it — the README ownership table, `documentation-guide.md` §11, the plan template's closeout
  questions — calls it Change Management. It also lacked the `Status` field and the `Version history`
  section every other document-style template carries; `09-visual-profile.md` lacked the same
  section.
- `templates/08-change-management.md` §4 sent full post-mortems to `/docs/incidents/`, a path the
  framework defines nowhere: no template, no entry in the README project structure, and nothing
  selectable in `clarity-bootstrap`. The incident table is the record; a project that writes longer
  post-mortems links to them from it and chooses where they live.
- `templates/06-test-documentation.md` §3 used `TC-001` and `TC-001-2` for its own test-case examples
  while §2 defines the format as `TC-[story-ID]-[number]` and demonstrates `TC-FR001-001`. The
  traceability table in `02-requirements.md` already followed the convention; only §3 diverged.
- The four dispatch blocks in `plan-driven-build/SKILL.md` tested `[ -n "$MODEL_REASONING" ]`
  unguarded while step 0 told the orchestrator it could "leave empty" — an orchestrator that left the
  variable unassigned rather than assigned-empty hit `parameter not set` under `set -u` instead of
  falling back to the account's own model. The tests are now `${VAR:-}` and step 0 shows the
  assignment explicitly.
- `clarity-bootstrap` used "roughly 20 stories" as the threshold for splitting the backlog into
  `02-user-stories.md`, while the guide and both templates say "roughly 20 **active** stories".
  Dropped stories keep their IDs and stay listed, so counting them would split a document earlier
  than intended.
- `AGENTS.md` had no rule keeping the story block in `templates/02-requirements.md` §2.6 identical to
  the one in `templates/02-user-stories.md`. Splitting a backlog moves stories between the two, so a
  field added to one and not the other disappears on the move — the same class of drift the existing
  `plan.md` / `plan-template.md` row already guards against.
- Four starters told an agent that "completion notes always include modified files", the exact
  opposite of the rule the other four and `prompts/4-build.txt` state: do not list changed files,
  the diff already shows them. `agents/macos-swift.md` carried both — the corrected rule in its
  Workflow and the old one in its Definition of Done. A dispatched agent in a Java, Swift, R/Shiny,
  or iOS project therefore received contradictory reporting instructions from `AGENTS.md` and the
  build prompt, and spent report budget listing what the diff already showed. An earlier release
  fixed the Workflow lines in four starters and never reached the Definition of Done lines.
- `agents/README.md` did not say how a starter's Definition of Done relates to the project's own in
  `docs/06-test-documentation.md` §8. Both carry the name; the starter's is the stack baseline and
  the project's is authoritative.
- `plan-driven-build/setup.md` § 3 listed only `docs/plans/.runs/` as the project's `.gitignore`
  entries, contradicting its own § 2 — which calls `.agents/build-env.local.sh` "gitignored
  machine-specific override" and tells Maven projects to put the dependency cache under `.m2/` and
  "gitignore it" — and contradicting `clarity-bootstrap`, which adds all three automatically. Anyone
  setting the workflow up by hand therefore committed another developer's toolchain paths and a
  dependency cache. All three are now listed, each with the reason it is excluded.
- `README.md`'s Ownership table covered only `CLAUDE.md`, `AGENTS.md`, and `docs/` — but
  `framework-update` declares that section normative and reads it to decide what it may replace, and
  the paths with the most delicate rule were missing from it: the managed skill directories, whose
  ownership is name-scoped rather than wildcard-scoped. The rule existed in `skills/README.md` and in
  the update skill's own prose, just not in the place both point at. The table now carries it.
- Five templates carried no `*Clarity Framework vX.Y.Z*` footer: `01-vision-scope.md`,
  `02-requirements.md`, `02-user-stories.md`, `03-sad.md`, and `08-change-management.md`, which also
  ended mid-table with no closing separator. `framework-update` step 2 falls back to that footer to
  detect a project's framework version when `00-ai-context.md` is absent — and the documents that
  lacked it are exactly the minimum set a personal or side project adopts, so the fallback failed
  for the projects most likely to need it. The release checklist in `AGENTS.md` gained a step for
  this: its existing check compares markers against each other and therefore cannot see a missing
  one.
- `render-update-commit.sh` emitted its commit message in Swedish — `"[minor] Uppdatera Clarity
  Framework till vX.Y.Z"` — so every project that ran `framework-update` got a Swedish commit in its
  history, against the repository rule that all framework content is English. Its regression test
  asserted the Swedish string, so the suite stayed green while the output was wrong.
- `AGENTS.md` never told anyone to run the three shipped regression tests. Commit discipline required
  a CHANGELOG entry, consistent guides, and updated version markers, but said nothing about tests —
  which is how the defect above survived. Running them is now part of a complete commit when a
  shipped script changes, with a note that a green assertion can lock in a defect just as easily as
  it can catch one.
- Nothing stated plainly that `plan-driven-build` requires a second AI CLI. `dispatch.sh` stops hard
  without one, but `README.md` and `skills/README.md` described dispatch to "other CLIs or accounts"
  as though a single-CLI project could still run the workflow. Both now say it outright, as does the
  skill's prerequisite list.
- `README.md`'s repository structure omitted the framework repo's own `AGENTS.md` and `CLAUDE.md`.
- `agents/java-application.md`, `agents/macos-swift.md`, and `agents/r-shiny.md` still routed ADRs to
  `docs/08-change-management.md` after the ADR home was settled, so a starter contradicted the guide
  it points at. They now name `03-sad.md` §6 as where an ADR is written and describe `08` as the
  index of superseded ones.
- `agents/generic.md` — the neutral fallback used when no stack starter matches — never mentioned
  `docs/03-sad.md`. Every other starter reads it; the one meant to work anywhere omitted the
  document that answers where a change belongs.
- ADRs had three homes described across the framework, and `README.md` contradicted itself in one
  file: line 31 placed them in `03-sad.md`, line 108 in `08-change-management.md`. The templates
  already implemented a coherent split that none of the prose described. Confirmed and written down:
  ADRs are authored in `03-sad.md` §6, next to the architecture they explain, and
  `08-change-management.md` §2 is an index of which ones were superseded so the history survives a
  SAD rewrite. `README.md`, `documentation-guide.md` §3/§6/§11, `templates/00-ai-context.md`, and
  both templates now say the same thing.
- "Definition of Done" named four different things: a document-completeness checklist in four
  templates, the project's story-level DoD in `06-test-documentation.md`, the plan's own DoD, and a
  framework-level checklist in the documentation guide. `plan-driven-build` step 5 verifies "each
  condition under Definition of Done", so the collision was operational, not just editorial. The
  document-completeness checklists in `04`, `05`, `07`, and `09` are now **Document completeness**,
  the guide's §14 is **Documentation completeness checklist**, and *Definition of Done* means only
  the project's DoD and a plan's DoD.
- `README.md` described `framework/PROJECT-INSTRUCTIONS.md` as a template for Claude Code and Codex.
  Its content is for chat-based projects — project knowledge plus custom instructions — while
  `AGENTS.md` is what governs the CLI clients.
- `agents/README.md` prescribed a heading structure only one of eight starters followed. It now
  requires the three sections all of them share — Workflow, When You Are a Dispatched Agent, and
  Definition of Done — plus an opening rules section under either accepted name, and leaves the rest
  to the stack. A starter for shell scripts and one for a Java build do not have the same shape.
- `setup.md` § "Implementation and the network" used `--account implementation` as its example,
  contradicting § 1's own rule against naming or using a subscription after the level it fills. Now
  reads `--account "$ACCT_IMPLEMENTATION"`, matching `SKILL.md`. The § 4 setup-verification example
  had the same problem with a literal `reasoning` account name; replaced with a placeholder.
- `plan-driven-build` now tells the orchestrator how to handle an Implementation stop caused by an
  internally inconsistent plan. It must propose the smallest concrete scope correction, stop for
  approval, patch the plan and journal after approval, and then re-dispatch instead of handing the
  diagnosis back to the user as an open-ended choice. *(Was 3.2.2, never tagged.)*
- `dispatch.sh --background` now starts the build child through `nohup` and writes a
  `DISPATCH child started` marker to the log. Some CLI harnesses can clean up ordinary background
  children when the short-lived wrapper command exits; the symptom is a vanished PID, empty log, and
  no sentinel. The marker makes that failure distinguishable from a build that started and failed.
  *(Was 3.2.1, never tagged.)*

### Added

- `agents/hugo-static-site.md` — a starter for static websites built with Hugo. Neither
  `vanilla-web-spa.md` nor `generic.md` fits: Hugo has a build step, a templating language, a content
  model with two bundle types, and its own development server. The mandatory core carries the rules
  that break Hugo projects most often — never edit a theme in place but override it from the
  project's own `layouts/`, and know that `assets/` is processed while `static/` is copied verbatim.
  Optional profiles cover the three theme models (project-owned layouts, Hugo Module, Git submodule),
  Tailwind and plain CSS, multilingual sites, and deployment, so one starter serves a one-page site
  and a large documentation site without either carrying the other's machinery. Verification is
  Playwright against `hugo server` plus axe, matching the other web starters, with an explicit note
  that a green `hugo` build is not verification.
- `agents/hugo-static-site.md` gained a **Third-Party Assets and Dependencies** profile, following the
  precedent set by the Dependency Policy profile in `agents/java-application.md`: the starter carries
  the routes and their costs, while which library a project uses is an ADR in `docs/03-sad.md` §6.
  It names the three ways to bring an asset in — `js.Build`, vendored, CDN — and states that a CDN
  reference sends every visitor's IP to a third party before consent, which is why self-hosting is
  the default and why an approved CDN reference needs Subresource Integrity.
- The Hugo Module profile was widened from themes to modules generally. A module may provide a single
  partial, shortcode, or asset rather than a whole theme, and `module.mounts` remaps where its files
  land — an architectural change rather than configuration tidying.
- `dispatch.sh --cli NAME` selects a CLI adapter, defaulting to `codex`. Everything tool-specific —
  binary name, how sandbox, approval, output-file, network and model are spelled, and which
  configuration-directory variable the account pool sets — is confined to one adapter block and one
  `cli_exec` branch. Previously `SKILL.md` told a project to change tools by editing `dispatch.sh`
  and `prompts/`, which contradicts the rule that a copied skill is framework-owned, must not be
  edited, and is replaced wholesale on update: the edit would have been reverted at the next
  `framework-update`. Selecting a tool is now a flag; supporting a new one is a framework change.
  `codex` remains the only adapter implemented.
- `dispatch.sh --account` now accepts a comma-separated, priority-ordered pool of aimux accounts
  instead of a single name. Resolved once per dispatch: `read-only` dispatches retry the next
  account in the pool automatically when one fails (side-effect-free, safe to retry);
  `workspace-write` dispatches pick the first account whose profile exists and never retry after
  launch, because a failed build cannot be safely resumed on a different account without knowing
  what it already wrote. Rate-limit detection is unverified — a retry currently fires on any
  non-zero codex exit, which may also retry a genuine task failure. Flagged in the script's own
  header comment.
- `dispatch.sh --model NAME`, passed straight through to codex independent of which account in a
  pool ends up running the dispatch. Lets a pool of otherwise-interchangeable accounts share one
  capability tier instead of requiring each account to carry its own `aimux profile update -m`
  config. The exact codex flag is unverified against the installed CLI version — check
  `codex exec --help` first, per the skill's existing setup convention for unverified flags.
- `tests/dispatch-test.sh`: coverage for pool retry on `read-only` failure, no retry on
  `workspace-write` failure, the logged-in-account fallback message, and `--model` pass-through.
- A **Clarity-managed setup** block in `templates/00-ai-context.md` holding `version`, `updated`,
  `agents-starter`, `skills`, and `skill-paths`. `clarity-bootstrap` writes it and `framework-update`
  reads and refreshes it; its `skills:` line is the ownership boundary that separates a Clarity skill
  from a project- or third-party-owned one.

### Changed

- Review no longer requires a different aimux account from Reasoning. What separates them is a
  different prompt file (`prompts/2-review.txt` vs `prompts/1-plan.txt`), not a different
  subscription — the earlier requirement conflated judgment independence with billing separation
  for no real benefit. `SKILL.md`, `setup.md`, and `templates/00-ai-context.md`'s runtime contract
  table updated accordingly; the table also gained a Model column, independent of the account pool
  column.
- `setup.md` no longer narrates prior skill behavior ("an earlier version of this skill required a
  distinct Review account", "the dispatcher previously set only the sandbox") — it states the
  current rule only. The history stays in this changelog, not in the living documentation.

## [3.2.0] – 2026-08-13

### Added

- `plan-driven-build` now supports an explicit `dispatch.sh --env-file FILE` hook for project-owned
  build environment bootstrap. The dispatcher stays language-agnostic: Java, Node, Go, and other
  toolchains belong in the project's env file, not in the workflow infrastructure.
- Step 4 documents the standard build-env paths, `.agents/build-env.sh` for portable committed
  bootstrap and `.agents/build-env.local.sh` for gitignored machine-specific overrides. The run
  journal now records which env file was used and any environment corrections made during the build.
- `clarity-bootstrap` adds `.agents/build-env.local.sh` to `.gitignore` when `plan-driven-build` is
  selected, matching the new local override convention.
- The build-env guidance now covers workspace-local dependency caches, including Maven
  `maven.repo.local` under `.m2/repository`, so dependency resolution can write inside the sandbox
  without granting access to user-level caches such as `~/.m2`.

### Changed

- Levels are bound to aimux accounts through the project's runtime contract instead of by name.
  `setup.md` previously told projects to create accounts called `reasoning`, `implementation`, and
  `review`, which contradicted the framework's own doctrine that an aimux account selects which
  subscription pays and is not a persona. An account is a subscription; naming one after a level
  collapses the two and makes that subscription unusable for any other level.

  The `Agent / account` column in `templates/00-ai-context.md` is now the mapping. Step 0 of
  `plan-driven-build` reads it into `ACCT_REASONING` / `ACCT_IMPLEMENTATION` / `ACCT_REVIEW`, and
  the dispatch commands pass those variables. Any account may fill any level, one account may fill
  several, and a project may hold any number of subscriptions — changing which one pays for a level
  is an edit to that table and nothing else. `dispatch.sh` is unchanged; it already took
  `--account NAME` generically.

- Step 0 verifies each mapped account's directory exists and prints `ok` or `MISSING` per level,
  replacing a prerequisite that asked the reader to eyeball `aimux profile list`. A level whose
  account is missing runs on the logged-in account with cost unseparated — previously visible only
  as a `FALLBACK:` line per dispatch, which is easy to scroll past and gives no signal until a usage
  report weeks later shows every session attributed to one account.

- The run journal records the account that actually paid for each step, rather than a level name
  that says nothing about which subscription was billed.

- `setup.md` states that spreading load across subscriptions is a change to the mapping between
  runs, not a rotation within one: rotating per dispatch starts every dispatch on a cold prompt
  cache and can land the review on the subscription that drafted the plan.

- `docs/00-ai-context.md` now treats the build environment as part of the AI runtime contract, so a
  project can state both the toolchain bootstrap path and the build-level guard that fails when the
  wrong runtime is active.
- The Java AGENTS starter now calls out build-level Java version enforcement, such as Maven Enforcer,
  as the source of truth when a project has a fixed Java baseline.

## [3.1.0] – 2026-08-13 *(never tagged; shipped in v3.2.0)*

### Changed

- The default gate profile is `semi-automatic` instead of `interactive`. A gate belongs where a
  decision is the user's and hard to walk back — scope, before any code exists, and merge, before
  the work reaches the shared branch. A commit inside a round is reversible and touches nobody else,
  so stopping there bought a confirmation rather than a decision. `interactive` stays available for
  unfamiliar or risky work. `templates/plan.md` and its copy state the reasoning.
- `dispatch.sh` takes `--account` rather than `--profile`, and reports `account=` and
  "no aimux account 'implementation'" rather than "no aimux profile". `--profile` is kept as a
  deprecated alias, so existing invocations and the regression test still pass. An aimux account
  selects which subscription pays; naming it a profile suggested a missing behavioral persona and
  collided with both the Codex profile and the plan's gate profile.

### Fixed

- The build dispatch had no waiting mechanism. Step 4 said to poll the sentinel but never said when,
  how often, or that the orchestrator must block — so it announced it was watching, ended its turn,
  and the run stalled until the user asked about it. Step 4 now carries a bounded blocking wait that
  distinguishes three outcomes: sentinel written, process still alive, and process gone without a
  sentinel. The last case is a killed build leaving a partial tree; without the `kill -0` check it
  was indistinguishable from a slow build, so waiting on it never ended.
- The build dispatch could not resolve dependencies. `workspace-write` denies network access by
  default, and `-a never` — which is what stops a background dispatch from hanging on a prompt
  nobody answers — leaves the build no way to ask for it, so any download failed the run. Step 4
  now passes a new `dispatch.sh --network` flag that sets `sandbox_workspace_write.network_access`
  for that single dispatch. The read-only levels keep the default, the account's stored
  configuration is untouched, and the sandbox still confines writes to the workspace. `--network`
  is rejected for any mode other than `workspace-write`.

## [3.0.1] – 2026-08-13 *(never tagged; shipped in v3.2.0)*

### Fixed

- `clarity-bootstrap` left a project without version control on first run. The Git decision sat in
  the guardrails, before the questions and before the step 4 approval gate, and produced only a
  report — so the user was asked about documents, starters, and skills but never about Git, and
  learned only at step 6 that `.gitignore` handling, `git check-ignore` verification, and the
  bootstrap commit had all been skipped, leaving the documents unversioned in a framework whose
  second core principle is *documentation as code*.

  Initialization is now a question in step 1, part of the proposal in step 4 with its consequences
  stated, and the first action of step 5, so files land inside the bootstrap commit instead of
  arriving as untracked clutter. Step 6's Git-dependent checks are unconditional again, with a
  single explicit closing note reserved for the one path that still lacks a repository — the user
  declining the recommendation.

  Detection distinguishes three states and compares the toplevel with `-ef` rather than by string,
  so a symlinked repository root is not misread. A directory already inside another repository is
  never initialized again, which would nest one repository in another.

## [3.0.0] – 2026-08-13 *(never tagged; shipped in v3.2.0)*

### Breaking changes

- `CLAUDE.md` contains exactly `@AGENTS.md` and nothing else. It is a pointer that lets Claude Code
  load what Codex reads directly; it is no longer the home for project-specific instructions.
- Everything project-specific lives in `docs/`, routed to the document that governs it. `README.md`
  carries the routing table: architecture to `03-sad.md` with ADRs in `08-change-management.md`,
  behavior to `02-requirements.md`, data and interfaces to `04-data-model-api.md`, delivery to
  `05-deployment-view.md`, test rules to `06-test-documentation.md`, operations to `07-runbook.md`,
  visual rules to `09-visual-profile.md`, and everything else to `00-ai-context.md`.
- Precedence changed. It was: session instruction, `CLAUDE.md`, `AGENTS.md`, skill, `docs/`. It is
  now: session instruction, `docs/`, `AGENTS.md`, skill. `CLAUDE.md` is absent because it holds no
  rules.

**Migration.** A project with content in `CLAUDE.md` below the import must move it into the `docs/`
document that governs each rule, then reduce `CLAUDE.md` to the single line. `framework-update`
detects the content, proposes a destination per rule, and reduces the file only after that migration
is approved — it never silently discards a project's rules.

### Added

- A `Project conventions` section in `templates/00-ai-context.md` as the home for agent-facing rules
  that no numbered document covers, kept short and pointing decisions at ADRs.
- An `Ownership` section in `README.md` stating what each of the three files holds, and the same
  division in `framework/documentation-guide.md` §13.

### Changed

- `agents/README.md`, all eight stack starters, `skills/README.md`, both skills, `templates/plan.md`
  with its `plan-driven-build/plan-template.md` copy, and all four dispatch prompts now point at
  `docs/` instead of `CLAUDE.md` for project-specific rules.
- `clarity-bootstrap` and `framework-update` treat project content found in `CLAUDE.md` as
  project-owned: it must be migrated to `docs/` with approval before the file is reduced.

## [2.2.0] – 2026-08-12

### Added

- A sizing rule for plans: one plan is one mergeable increment — the smallest change that can merge
  on its own without leaving the product broken or half-migrated, usually a single user story. The
  rule, its size test, and its lower bound are stated in `templates/plan.md`, its
  `skills/plan-driven-build/plan-template.md` copy, and `framework/ai-usage-guide.md` §9.
  `prompts/1-plan.txt` now instructs the planning level to plan only the first increment when the
  task spans more, and to list the rest under `Excluded` rather than compressing scope by making
  steps vaguer. A milestone is delivered by a sequence of plans; it lives in the story map's release
  slices and in Change Management, not in a plan.

### Fixed

- `skills/plan-driven-build/SKILL.md` step 2 dispatched `--profile granskning`, but `setup.md`
  creates the account as `review`. The review level therefore never found its profile and always
  fell back to `reasoning`, silently defeating the account separation the step exists for.
- `skills/plan-driven-build/SKILL.md` referred to a plan field named `Rapportbudget`; the template
  emits `Report budget`.
- Remaining Swedish placeholders in the `templates/00-ai-context.md` technology-stack table
  (`t.ex.` and `Databas`), missed by the v2.1.0 language sweep.

## [2.1.0] – 2026-08-12 *(never tagged; shipped in v2.2.0)*

### Added

- User stories are documented as the unit of product work rather than only a requirement format.
  `templates/02-requirements.md` gains a role table with stable role IDs, an INVEST quality bar with
  behavior-based splitting guidance, a story lifecycle, a Definition of Ready, an epic overview, and
  per-story status, size, and dependency fields.
- Visual requirements views: a Mermaid story-lifecycle state diagram, a Mermaid journey diagram for
  the story-map backbone, a release-slice story-map table, and a Mermaid traceability chain from a
  Vision & Scope goal through epic, story, acceptance criterion, and test case to the release.
- `templates/02-user-stories.md` for projects whose backlog outgrows the requirements document.
  Adopt it past roughly 20 active stories or more than one backlog owner; the roles, quality bar,
  lifecycle, story map, epic overview, priorities, and traceability stay in `02-requirements.md`.
- `templates/plan.md` and its `skills/plan-driven-build/plan-template.md` copy gain a `Delivers`
  field naming the story IDs a plan implements, a requirements row in “Context to read first”, a
  Definition of Done condition citing acceptance criteria by ID, and a closeout question that writes
  story status and traceability back before the plan is deleted. Plans cite story IDs and never copy
  acceptance criteria, because the plan is transient and the requirements document is authoritative.
- Role IDs in `templates/01-vision-scope.md` §3 so that stories name a role defined in scope.

### Fixed

- `skills/plan-driven-build/SKILL.md` looked for a plan field named `Grindprofil` with the profile
  values `interaktiv`, `halvautomatisk`, and `obevakad`, none of which the plan template has emitted
  since v2.0.0. The gate-profile table, the scope gate, and the commit gate now match the template's
  `Gate profile` field and its `interactive` / `semi-automatic` / `unattended` values.
- Swedish text left after the v2.0.0 translation: `Versionshistorik`, `Prioritet`, `Krav`,
  `Kort storytitel`, and `Komponent i SAD` in `templates/02-requirements.md`, and the performance
  NFR row in `templates/00-ai-context.md`.

## [2.0.5] – 2026-08-11

### Changed

- Restored detailed test-documentation guidance, including the test pyramid, traceability matrix,
  visual UX verification records, test data, execution evidence, and exception handling.
- Restored detailed runbook guidance, including operational ownership, lifecycle commands, release
  procedures, backup and restore, troubleshooting, incident response, and smoke tests.

## [2.0.4] – 2026-08-11 *(never tagged; shipped in v2.0.5)*

### Changed

- Restored the detailed deployment-view guidance, including infrastructure topology, service
  configuration, secrets, CI/CD stages, release traceability, observability, backups, recovery,
  rollback, and production UX verification.

## [2.0.3] – 2026-08-11 *(never tagged; shipped in v2.0.5)*

### Changed

- Restored the detailed data-model and API-contract guidance, including domain relationships,
  physical schema examples, migration strategy, endpoint examples, error registry, and security
  and compatibility rules.

## [2.0.2] – 2026-08-11 *(never tagged; shipped in v2.0.5)*

### Changed

- Expanded the README repository tree with descriptions for framework documents, templates, agent
  starters, skills, scripts, tests, and workflow support files.
- Restored the detailed architecture-template guidance, including context, component, data-flow,
  technology-choice, ADR, quality-attribute, and technical-debt sections.

## [2.0.1] – 2026-08-11 *(never tagged; shipped in v2.0.5)*

### Changed

- Replaced the AI runtime-model section in `AGENTS.md` with the normative release strategy.

## [2.0.0] – 2026-08-11 *(never tagged; shipped in v2.0.5)*

### Breaking changes

- All framework content and file names use English.
- The four-level runtime contract—Orchestrator, Reasoning, Review, and Implementation—is the only
  AI operating model. The former three-step model is removed; no migration mapping is required.
- `aimux` is documented as a multiplexer for separate subscriptions or accounts within one LLM
  provider. It does not create agent personas.
- `docs/.clarity-version` is no longer required. Updates read version markers already present in
  project documents.
- The optional `skills/clarity-bootstrap/agents/openai.yaml` metadata file is removed.
- Swedish framework file names are replaced with English names, including `framework-update`,
  `plan-driven-build`, `requirements`, `data-model-api`, `test-documentation`, `change-management`,
  and `visual-profile`.

### Added

- Required visual UX verification for UI changes, including rendered states, target viewports,
  responsive behavior, accessibility checks, screenshots, and human review.
- English run journals, plan templates, setup documentation, dispatch prompts, and project starters.
- Explicit account separation guidance for agent workflows.

## [1.5.1] – 2026-08-11

### Fixed

- Framework updates allow unrelated dirty source, build, test, and application-configuration paths.
- Update commits use an explicit path list and `git commit --only`.
- Dispatches use stable sentinels, bounded reports, and explicit approval policies.

## [1.5.0] – 2026-08-11

### Added

- `clarity-bootstrap` for need-driven project setup.
- Generic and stack-specific agent starters.
- Plan-driven build regression tests and bounded dispatch reporting.
- The Visual Profile and DTCG design-token guidance for projects with a UI.

### Changed

- Framework-owned files are replaced wholesale; project-owned documents preserve their content.
- Skills are installed identically for Codex and Claude Code.
- API contracts, deployment views, test documentation, runbooks, and change management are linked
  through a consistent numbered document set.

## [1.4.0] – 2026-08-10

### Added

- The plan-driven multi-agent workflow with planning, review, implementation, verification, human
  approval gates, run journals, and bounded orchestrator context.
- Dispatch scripts for sandbox, approval, account selection, background execution, and sentinels.

## [1.3.0] – 2026-08-09

### Added

- Deployment View guidance for environments, CI/CD, release traceability, health checks, monitoring,
  and rollback.
- Test Documentation guidance for unit, integration, end-to-end, and accessibility testing.
- Runbook guidance for deployment, operations, backup, restore, and incident response.

## [1.2.0] – 2026-08-08

### Added

- Data Model & API Contract template with contract-first OpenAPI guidance.
- Requirements template with NFRs, user stories, use cases, MoSCoW priorities, and traceability.
- System Architecture Document template with component, data-flow, quality-attribute, and ADR sections.

## [1.1.0] – 2026-08-07

### Added

- Vision & Scope template.
- AI Context Document template.
- Documentation guide and project instruction template.

## [1.0.0] – 2026-08-06

### Added

- Initial Clarity Framework release with the core principles: just enough documentation,
  documentation as code, and clarity over completeness.
