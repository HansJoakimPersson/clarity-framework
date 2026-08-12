# AGENTS.md - Shell and Dotfiles v1.1

Guidance for agents editing shell scripts, aliases, functions, and dotfiles.

## Core Principles

- Preserve behavior while improving clarity.
- Deliver the task's full scope. A skeleton or partial implementation offered with "let me know if you want me to
  continue" is an incomplete delivery, not a small one.
- Stay inside the task's scope; do not mass-reformat unrelated lines.
- Follow the existing file's style unless it is clearly broken.
- Prefer portable, explicit shell code over dense one-liners.
- Never add secrets, tokens, credentials, or machine-specific private data.

## Workflow

1. Read `AGENTS.md` and, when it exists, `docs/00-ai-context.md` before starting any task.
2. In Clarity Framework projects, read `docs/00-ai-context.md` first when it exists — it is short,
   and it routes you to whatever else matters. If it is absent, continue from `README.md` and the
   task-relevant numbered documents; AI Context is optional. If a plan in `docs/plans/` governs
   this task, read that too: its scope section is
   authoritative, so do not re-plan, and if the plan is wrong or incomplete, stop and report rather than
   improvising. Read `docs/03-sad.md` only when the script is part of a larger system and the change touches how
   it fits in. Do not read a document speculatively.
3. Identify whether the change affects behavior, formatting, portability, or security.
4. Implement the task in full, within its stated scope.
5. Run `shellcheck` when available.
6. Report whether the task is done. If it is not, say what remains and why. Do not list changed files — the diff
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

## Baseline Formatting

- Use UTF-8.
- Use LF line endings.
- End files with a trailing newline.
- Remove trailing whitespace unless Markdown or shell syntax intentionally needs it.
- Keep one blank line between logical blocks.
- Use clear section headers in large shell files when the existing style supports them.

## Shebangs and Shell Mode

- Bash scripts should use:

```bash
#!/usr/bin/env bash
```

- POSIX shell scripts should use:

```sh
#!/usr/bin/env sh
```

- Do not use Bash-only features in files intended for POSIX `sh`.
- Keep `shellcheck` directives near the top and scope them narrowly.

## Function Style

- Use multi-line functions for non-trivial logic:

```bash
name() {
  local value="$1"
  printf '%s\n' "$value"
}
```

- Use one-line functions only for trivial wrappers.
- Use `local` for Bash function-local variables.
- Keep names descriptive and consistent with nearby aliases/functions.

## Indentation and Layout

- Use 2 spaces for new or edited shell blocks unless the file clearly uses another style.
- Keep `then` and `do` on the same line when readable.
- Prefer readable multi-line conditionals over packed expressions.
- Do not reindent entire legacy files just to normalize style.

## Quoting and Expansion

- Quote variable expansions by default: `"$var"` or `"${var}"`.
- Use `${var}` when concatenating or disambiguating.
- Use arrays in Bash when handling lists of arguments.
- Use `read -r` when reading input.
- Use `printf` instead of `echo` when output must be predictable.

## Checks and Safety

- Use `command -v name >/dev/null 2>&1` for command detection.
- Avoid parsing `ls`; use globs, `find`, or shell arrays.
- Avoid destructive commands unless the task requires them and the user intent is clear.
- Guard deletes, overwrites, and recursive operations carefully.
- Keep aliases and functions from surprising users with hidden network, delete, or privilege-escalation behavior.

## Dotfiles

- Group aliases and functions by topic.
- Keep comments short and practical.
- Avoid environment-specific absolute paths unless the file is intentionally local-only.
- Prefer opt-in configuration for machine-specific tools.
- Do not export secrets directly; reference external secret managers or local ignored files.

## Tooling

- Run `shellcheck` when available for shell script changes.
- Run formatters only if the project already uses them.
- For dotfiles, test by sourcing in a clean shell when practical.
- If a script is executable, preserve or intentionally update executable permissions.

## Documentation and Hygiene

- In Clarity Framework projects, update the relevant docs when their content changes:
  - `docs/07-runbook.md` — when operational scripts or runbook-relevant procedures change
  - `docs/05-deployment-view.md` — when deployment or infrastructure scripts change
  - `docs/08-change-management.md` — for change tracking

## Definition of Done

- Edited shell parses and preserves intended behavior.
- Relevant checks run, or the reason they could not run is stated.
- No unrelated formatting churn is included.
- Risky operations remain explicit and guarded.
- Relevant Clarity Framework docs are updated when their content is affected.
