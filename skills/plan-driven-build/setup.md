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

## 1. Accounts that separate subscriptions

The purpose of the level split is to move token usage away from the interactive session. This
requires **separate subscriptions or accounts**, not merely separate processes. aimux is a multiplexer
for accounts within the same LLM provider; its profiles select credentials and token allowances,
not agent personas or behavioral profiles.

```bash
aimux profile add reasoning      --cli codex && aimux auth login reasoning
aimux profile add implementation --cli codex && aimux auth login implementation
aimux profile add review         --cli codex && aimux auth login review         # optional
aimux profile list
```

Each account can use its own model: `aimux profile update implementation -m <model>`. The build is
usually the longest run and may justify a faster or cheaper model once scope is approved.

`review` is optional. When present, step 2 runs under a different account from the plan author. If
it is missing, fall back to `reasoning` and record that fact in the run journal.

The skill's dispatch commands set `CODEX_HOME="$HOME/.aimux/profiles/<account>"` directly instead of
using `aimux run`, so they compose with background execution. This is aimux's own mechanism: one
configuration-directory variable per CLI (`CLAUDE_CONFIG_DIR` / `CODEX_HOME` / `GEMINI_CLI_HOME`).

---

## 2. Permission model

**Gates belong on decisions, not tool calls.** The human decisions in this workflow are scope
(step 3), merge (step 7), release, and deleting the plan (step 8). Everything else is a tool call
inside a sandbox and should proceed without asking. A workflow that stops to ask permission to run
`git status` has gated the wrong thing.

### Codex – always set both dimensions

Sandbox and approval are independent settings. The dispatcher previously set only the sandbox and
left approval at its default, a common reason for an unattended dispatch to stop and ask questions.

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

Run `codex --profile orchestrator`. A Codex profile (`--profile`) and an aimux account are different:
the Codex profile controls behavior, while the aimux account determines which subscription pays.
They are complementary.

`danger-full-access` solves the same problem more bluntly by removing the sandbox entirely. Do not
use it as the default; unattended implementation should still run inside a sandbox.

Codex reads the shared skill from `.agents/skills/plan-driven-build/SKILL.md`. Start the orchestrator
profile and select `$plan-driven-build`; no separate prompt installation is needed.

The most common reason to switch orchestrators mid-run is that the first one reaches its limit. The
run journal carries the workflow forward; the new client invokes its copy of the same skill and
continues from the journal's next step.

### Claude Code as orchestrator

Copy `settings.example.json` to the project's `.claude/settings.json` (or merge it with an existing
file) so the workflow's own commands are not gated one by one.

The `allow` list covers dispatch, the Git commands the workflow actually runs, and reading the plan
directory. Routing every dispatch through `dispatch.sh` makes it matchable: a background command
with environment prefixes is difficult to describe reliably, while a stable script path is not.

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
```

Raw dispatch output—reviews, build logs, and verification reports—is local working material. The run
journal (`docs/plans/*.run.md`) is committed: it is the handover surface, and a cloud agent sees only
what has been pushed.

---

## 4. Verify the setup

```bash
aimux profile list
CODEX_HOME="$HOME/.aimux/profiles/reasoning" codex -a never exec -s read-only \
  "Answer with one word: ok"
```

If it completes without asking for permission, the approval policy is configured correctly. If it
asks or hangs, that is the question that would otherwise stop an unattended build in the middle of
the night.

---

*Clarity Framework – Plan-Driven Build Setup*
