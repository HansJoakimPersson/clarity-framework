# Agents – AI behavior instructions by stack

This directory contains predefined `AGENTS.md` starters for common project types. Choose the
closest starter and copy it unchanged; project-specific adjustments belong in `docs/`. Starters
describe ways of working, not product architecture.

## What is AGENTS.md?

`AGENTS.md` is an instruction file placed at a project's root. It tells AI agents **how** to work
in that project. Codex reads it directly. Claude Code reads the project's `CLAUDE.md`, which
contains the single line `@AGENTS.md` and imports the same rules. `CLAUDE.md` carries no rules of
its own.

| Document | Answers |
| --- | --- |
| `docs/00-ai-context.md` | What is the project? |
| `docs/01-vision-scope.md` | Why is it being built? |
| `docs/03-sad.md` | How is it architected? |
| `AGENTS.md` | How should the agent work here? |

Together they give an agent enough context to make local decisions without guessing.

## Available starters

| File | Use when… |
| --- | --- |
| `generic.md` | No specialized starter matches; provides a neutral stack-independent baseline |
| `java-application.md` | The project is a Java application, with or without Spring Boot |
| `ios-springboot.md` | The project has a Spring Boot backend and a native Swift iOS/iPadOS app |
| `r-shiny.md` | The project is an R/Shiny app, with or without a plumber API |
| `vanilla-web-spa.md` | The project is a build-step-free HTML/CSS/JS web app |
| `shell-dotfiles.md` | You work with shell scripts, aliases, or dotfiles |
| `macos-swift.md` | The project is a Swift macOS app |
| `electron-desktop.md` | The project is an Electron desktop app intended to feel native |

## How to use a starter

1. Copy the relevant file to the project root and rename it `AGENTS.md`.
2. Create `CLAUDE.md` containing exactly `@AGENTS.md`. If the file already exists and holds
   project-specific rules, move them into the `docs/` document that governs them, then reduce
   `CLAUDE.md` to the import.
3. Commit both files like any other documentation.

That is the entire procedure. **Do not edit the copied starter.**

Each starter conditionally applies its own sections. The agent decides which profiles are relevant;
a profile for a technology the project does not use costs nothing. Deleting it in advance only makes
the file impossible to update mechanically.

`AGENTS.md` is framework-owned and replaced wholesale when the project updates to a new framework
release. Project-specific material belongs in `docs/`, which the framework never overwrites.

## Integration with Clarity Framework

All starters refer to Clarity Framework's standard paths, such as `docs/00-ai-context.md` and
`docs/03-sad.md`. A project that deviates from those paths records the deviation in
`docs/00-ai-context.md` instead of editing `AGENTS.md`.

```text
Clarity Framework documents in docs/
  ↓ always take precedence; they are the project's own decisions
Stack-specific rules from this starter, imported by CLAUDE.md
  ↓ govern the way of working where docs/ is silent
```

`CLAUDE.md` does not appear in that order because it holds no rules — it is the one-line import that
lets Claude Code read the same `AGENTS.md` Codex reads.

## Adding a new starter

1. Name the file `[stack].md` using lowercase letters and hyphens.
2. Include the three sections every starter must have, whatever the stack:
   - **Workflow** — the order of work, referring to the Clarity Framework documents by path.
   - **When You Are a Dispatched Agent** — keeps an agent inside an approved plan's scope.
   - **Definition of Done** — what "finished" means here, in checkable terms.
3. Open with a section stating the rules that always apply — *Core Rules* or *Core Principles*,
   whichever fits the stack's vocabulary.
4. Everything else is stack-dependent. A starter for a language with build profiles needs optional
   profile sections; one for shell scripts needs formatting and quoting rules instead. Do not add a
   section to match another starter's shape when the stack has nothing to put in it.
5. Add a row to the table above.
6. Add an entry to `framework/CHANGELOG.md`.

Starters differ because the stacks differ. The three required sections are the contract the rest of
the framework relies on; heading order and depth below them are the author's call.

---

*Clarity Framework – Agents*
