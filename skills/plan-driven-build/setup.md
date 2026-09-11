# Setup – Plan-Driven Build

One-time setup per machine. `SKILL.md` assumes this is complete and does not read this file while running.

> **Verify flags and configuration keys against your installed version** before trusting them in an
> unattended workflow. Codex and Claude Code have changed flag and settings names between versions.
> Run `codex --help`, `codex exec --help`, and test a short dispatch first. A wrong approval flag can
> otherwise be discovered as a hung build halfway through execution.

---

## 0. Install the same skill for both tools

Codex and Claude Code follow the same Agent Skills format but search different project paths. Copy
the same directory to both locations:

```bash
mkdir -p .agents/skills .claude/skills
cp -R /path/to/clarity-framework/skills/plan-driven-build .agents/skills/
cp -R /path/to/clarity-framework/skills/plan-driven-build .claude/skills/
diff -qr .agents/skills/plan-driven-build .claude/skills/plan-driven-build
```

- Claude Code: invoke `/plan-driven-build`.
- Codex: invoke `$plan-driven-build` or select the skill through `/skills`.

Codex custom prompts under `~/.codex/prompts/` are deprecated and unused. Files under the skill's
own `prompts/` directory are internal instructions for dispatched processes and must remain there;
they are not custom prompts for either client.

---

## 1. aimux profiles that separate subscriptions

The purpose of the level split is to move token usage away from the interactive session. This
requires **separate subscriptions or accounts**, not merely separate processes. aimux is a
multiplexer for accounts within the same LLM provider, and it unifies each one into a **profile**:
a single object carrying the CLI, the model, the credentials and the token allowance. A profile is
not an agent persona; it selects who pays and what runs.

**Name each aimux profile after the subscription it is, not after the level it will fill.** aimux
manages the profiles; the framework binds levels to them. Naming one `implementation` collapses the
two and makes it unusable for any other level:

```bash
aimux profile add <your-subscription-name> --cli codex && aimux auth login <your-subscription-name>
aimux profile list
```

The `--cli` you pass here is what `dispatch.sh` reads back at dispatch time from
`~/.aimux/config.yaml` — switching a level from codex to gemini later is
`aimux profile update <name> --cli gemini` and nothing else.

Then record which profile fills which level in the project's runtime contract,
`docs/00-ai-context.md`. That table is the mapping — step 0 of `SKILL.md` reads it and verifies the
profiles exist. The binding is arbitrary and project-owned: any profile may fill any level, one
profile may fill several, and adding a subscription is an edit to that table, not a rename.

Each profile carries its own model (`aimux profile update <name> -m <model>`). That is enough for a
single fixed profile per level. Once a level is bound to a **pool** of interchangeable profiles
whose model configs may differ, `dispatch.sh --model NAME` overrides the model for one dispatch
regardless of which pool member runs (it is passed to `aimux run -m`). Prefer the profile's own
config when a level has exactly one profile; reach for `--model` when it has a pool.

Review does not need a separate profile. What keeps it from repeating the drafting level's blind
spots is a different prompt file (`prompts/2-review.txt` vs `prompts/1-plan.txt`), not a different
subscription. `$PROFILE_REVIEW` may equal `$PROFILE_REASONING`.

**A level's pool is resolved once per run, not rotated between runs by hand.** `docs/00-ai-context.md`
names an ordered, comma-separated pool per level — for example `codework1,codework2,codework3` for
Implementation. Within a single dispatch, `dispatch.sh` tries the pool in that order and, for
read-only dispatches only, moves to the next profile automatically if one fails; a `workspace-write`
dispatch picks the first profile that resolves and does not retry after it starts, because a failed
build cannot be safely resumed on a different subscription without knowing what it already wrote.
Put the profiles you want tried first at the front; changing the order is an edit to
`docs/00-ai-context.md`, not a runtime rotation the skill manages.

`dispatch.sh` runs each dispatch as `aimux run <profile> -- <cli invocation>`. This was verified to
compose with background execution under `nohup` on aimux 0.25.0 — the profile's authentication and
subscription apply to the child process, and the `.exit` sentinel is still written.

### Which CLI runs a dispatch

`dispatch.sh` resolves the CLI from the resolved profile's `cli` field in `~/.aimux/config.yaml`.
`codex` is the only adapter implemented. The adapter is the one place that knows a tool's grammar:
its binary name, how sandbox, approval, output-file, network and model are spelled. Everything else
in the dispatcher — profile pools, budgets, sentinels, retries, prompts — is the same whatever runs
underneath.

A pool entry written `cli:NAME` (for example `--profile codework1,cli:codex`) is an explicit
escape hatch: it runs `NAME` directly, with no `aimux run` wrapper and no subscription separation,
and only after every real profile ahead of it fails to resolve. `dispatch.sh` prints a `FALLBACK:`
line whenever it is used.

That boundary matters for ownership. A project changes tools with `aimux profile update`, never by
editing this skill: the copied skill is framework-owned and is replaced wholesale at the next
update, so an edit here would be silently reverted. Supporting a new CLI is a framework change —
one adapter function in `dispatch.sh` — and it leaves the levels, plan, journal, budgets and gates
untouched.

---

## 2. Permission model

**Gates belong on decisions, not tool calls.** The human decisions in this workflow are scope
(step 3), merge (step 7), release, and deleting the plan (step 8). Everything else is a tool call
inside a sandbox and should proceed without asking. A workflow that stops to ask permission to run
`git status` has gated the wrong thing.

### Codex – always set both dimensions

Sandbox and approval are independent settings. Set both explicitly, or an unattended dispatch can
stop to ask a question that never gets answered.

| Level | Flags |
| --- | --- |
| Reasoning, review | `codex -a never exec -s read-only …` |
| Implementation | `codex -a never exec -s workspace-write …` |

`--full-auto` is shorthand for `workspace-write` plus a less restrictive approval policy. It works,
but explicit flags make the command's behavior visible.

### Codex as orchestrator

This is the special case that explains why Codex may complain about permissions while orchestrating:
the orchestrator starts subprocesses that need **network access** to reach the model API, while
`workspace-write` blocks network access by default. The dispatch then dies or escalates to an
approval question. Add a profile to `~/.codex/config.toml`:

```toml
[profiles.orchestrator]
approval_policy = "never"
sandbox_mode    = "workspace-write"

[profiles.orchestrator.sandbox_workspace_write]
network_access = true
```

Run `codex --profile orchestrator`. A Codex profile (`codex --profile`) and an aimux profile are different: the Codex profile
controls codex's own behavior, while the aimux profile determines which CLI runs and which
subscription pays. `dispatch.sh --profile` refers to the aimux one.

`danger-full-access` solves the same problem more bluntly by removing the sandbox entirely. Do not
use it as the default; unattended implementation should still run inside a sandbox.

### Implementation and the build environment

Codex uses local binaries, but a sandboxed non-interactive dispatch may not see the same login-shell
environment as an interactive terminal. Version managers and shell startup files can therefore make
`java`, `node`, `go`, or another tool resolve differently inside step 4 than they do in a normal
shell.

Keep the dispatcher language-agnostic. Put project-specific build bootstrap in an explicit env file
instead:

```text
.agents/build-env.sh        # committed when it is portable for the project
.agents/build-env.local.sh  # gitignored machine-specific override
```

For example, a Java 21 project on macOS might use:

```sh
if command -v /usr/libexec/java_home >/dev/null 2>&1; then
  JAVA_HOME="$(/usr/libexec/java_home -v 21)"
  PATH="$JAVA_HOME/bin:$PATH"
  export JAVA_HOME PATH
fi

# Keep Maven artifact writes inside the workspace sandbox instead of ~/.m2.
MAVEN_OPTS="${MAVEN_OPTS:-} -Dmaven.repo.local=$PWD/.m2/repository"
export MAVEN_OPTS
```

Step 4 passes the selected file with `dispatch.sh --env-file FILE`. The file is sourced before
`codex exec`, so Codex and every build command it starts inherit the same environment. Use the
project's own build verification as the hard guard: Maven Enforcer, package-manager `engines`,
`go.mod`, CI images, or equivalent should fail clearly when the wrong runtime is active.

Dependency caches should follow the same rule: keep build writes inside the workspace unless there
is a deliberate reason to grant access elsewhere. For Maven, prefer `maven.repo.local` under the
project, such as `.m2/repository`, and gitignore it. For other ecosystems, use the equivalent
workspace-local cache when the tool supports one. Granting `~/.m2`, package-manager home caches, or
other user-level directories to the implementation sandbox is a larger exception and should be
journaled as such.

An orchestrator may correct the env file during a run when the sandbox sees the wrong local
toolchain. Journal the correction. Changing the project's supported runtime, dependency baseline, or
ADR is not an environment correction; it is a scope or decision change.

### Implementation and the network

The same `workspace-write` default applies to the build dispatch, where it blocks dependency
resolution: Maven reaching Central, npm reaching the registry, Go reaching a module proxy. The build
cannot negotiate its way past it either, because `dispatch.sh` runs `-a never` — approval prompts
and background execution do not compose, and a build that stops to ask is a build that hangs until
someone notices.

So step 4 passes `--network`, which sets `sandbox_workspace_write.network_access` for that single
dispatch:

```bash
"$SKILLDIR/dispatch.sh" --profile "$PROFILE_IMPLEMENTATION" --mode workspace-write --background --network \
  --env-file .agents/build-env.sh …
```

`$PROFILE_IMPLEMENTATION` is the shell variable `SKILL.md` step 0 binds from the runtime
contract — not a literal profile name. Writing `--profile implementation` here, even as a
placeholder, contradicts § 1's own rule against naming or using a subscription after the level it
fills.

Per dispatch, not stored on the profile: the read-only levels keep the default, and the wider
sandbox lasts one build rather than becoming the machine's permanent posture. The sandbox still
confines writes to the workspace — network access changes what the build can reach, not what it can
overwrite.

Pre-fetching dependencies from a normal shell (`mvn dependency:go-offline`, `npm ci`,
`go mod download`) still works and is a reasonable habit for slow or flaky registries. It is a
convenience, not a prerequisite; the build no longer depends on a warm cache.

`dispatch.sh --background` uses `nohup` to keep the child alive after the short-lived dispatch
command returns. If a build PID disappears with an empty log and no sentinel, treat that as a
wrapper or host-process cleanup failure and debug the dispatch path before continuing to
verification.

`danger-full-access` is still the wrong tool here. It removes the sandbox altogether, which is a
much larger grant than the one thing a build actually needs.

Codex reads the shared skill from `.agents/skills/plan-driven-build/SKILL.md`. Start the orchestrator
profile and select `$plan-driven-build`; no separate prompt installation is needed.

The most common reason to switch orchestrators mid-run is that the first one reaches its limit. The
run journal carries the workflow forward; the new client invokes its copy of the same skill and
continues from the journal's next step.

### Claude Code as orchestrator

Copy `settings.example.json` to the project's `.claude/settings.json` (or merge it with an existing
file) so the workflow's own commands are not gated one by one.

**The two halves of the file are not equally important.** The `deny` list is the reason the file
exists: it turns the reading budget from an instruction into a mechanism. The `allow` list is
convenience — it removes permission prompts for the commands this workflow runs anyway, and a
project that prefers to approve them interactively can drop it entirely without weakening anything.
Treat `allow` as a starting point to adjust per project; treat `deny` as the part to keep.

The `allow` list covers dispatch, the Git commands the workflow actually runs, and reading the plan
directory. Routing every dispatch through `dispatch.sh` makes it matchable: a background command
with environment prefixes is difficult to describe reliably, while a stable script path is not.

Its patterns match the literal command text, before the shell expands anything. `SKILL.md` step 0
runs `mkdir -p "$RUN"` and `cp "$SKILLDIR/journal-template.md" …`, so a pattern anchored on
`mkdir -p docs/plans/` never matches and the command prompts anyway. That is why the shipped
patterns are the plain verbs — `Bash(mkdir -p:*)`, `Bash(cp:*)`, `Bash(test:*)` — rather than
path-anchored ones. Narrow them if a project wants tighter control, but verify against the commands
as written in `SKILL.md`, not as they look after expansion.

The `deny` list is the important half. It turns the reading budget into a mechanism rather than a
matter of discipline:

| Rule | Why |
| --- | --- |
| `Bash(git diff:*)`, `Bash(git show:*)` | The orchestrator must never read the diff; that is step 5's job. Without this rule it is only an instruction, and instructions to avoid information are the first to fail when something looks strange |
| `Read(…/prompts/**)` | Prompts live in files to keep them outside the orchestrator's context. A rule that prevents reading is cheaper than an instruction asking the orchestrator not to read them |

If you exceptionally need to inspect a hunk, remove the rule deliberately for that run instead of
keeping it disabled by default.

The file lives here rather than in `.claude/` because that directory is gitignored in the framework
repository. In a project, `.claude/settings.json` is worth versioning because it is part of how the
project is built.

### If you edit the prompts

Each `prompts/*.txt` file contains a line telling the dispatched agent to ignore orchestration skills
found in the repository and never invoke `codex` as a subprocess. Removing it can cause a dispatched
agent that finds the copied `SKILL.md` to run the workflow itself and spawn nested processes. Keep it.

---

## 3. The project's `.gitignore`

```gitignore
docs/plans/.runs/
.agents/build-env.local.sh
.m2/
```

`docs/plans/.runs/` is raw dispatch output — reviews, build logs, verification reports — and is local
working material. The run journal (`docs/plans/*.run.md`) is committed: it is the handover surface,
and a cloud agent sees only what has been pushed.

`.agents/build-env.local.sh` is the machine-specific override from § 2. Its committed sibling
`.agents/build-env.sh` is versioned; the `.local` one is not, which is the entire distinction between
them — committing it pushes one developer's toolchain paths onto everyone else.

`.m2/` is the workspace-local Maven cache § 2 recommends so a sandboxed build can resolve
dependencies without write access to `~/.m2`. Replace it with whatever workspace-local cache path
your ecosystem uses, or drop the line for a project that has none. It is here because a dependency
cache inside the workspace is large, machine-specific, and reproducible — three reasons never to
commit it.

`clarity-bootstrap` adds these three automatically when `plan-driven-build` is selected. Add them by
hand when you set the workflow up yourself.

---

## 4. Verify the setup

```bash
aimux profile list
aimux run <one of your profile names> -- codex -a never exec -s read-only "Answer with one word: ok"
```

If it completes without asking for permission, the approval policy is configured correctly. If it
asks or hangs, that is the question that would otherwise stop an unattended build in the middle of
the night.

---

*Clarity Framework – Plan-Driven Build Setup*
