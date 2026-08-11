# Agents – AI behavior instructions by stack

This directory contains predefined `AGENTS.md` starters for common project types. Choose the
closest starter and copy it unchanged; project-specific adjustments belong in `CLAUDE.md`. Starters
describe ways of working, not product architecture.

## What is AGENTS.md?

`AGENTS.md` is an instruction file placed at a project's root. It tells AI agents **how** to work
in that project. Codex reads it directly. Claude Code reads the project's `CLAUDE.md`, which should
begin with `@AGENTS.md` and import the same rules.

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
2. Create `CLAUDE.md` with `@AGENTS.md` as its first line, or add that import first in an existing
   file without removing project-specific rules.
3. Commit both files like any other documentation.

That is the entire procedure. **Do not edit the copied starter.**

Each starter conditionally applies its own sections. The agent decides which profiles are relevant;
a profile for a technology the project does not use costs nothing. Deleting it in advance only makes
the file impossible to update mechanically.

`AGENTS.md` is framework-owned and replaced wholesale when the project updates to a new framework
release. Project-specific material belongs in `CLAUDE.md`, which the framework does not overwrite.

## Integration with Clarity Framework

All starters refer to Clarity Framework's standard paths, such as `docs/00-ai-context.md` and
`docs/03-sad.md`. A project that deviates from those paths records the deviation in `CLAUDE.md`
instead of editing `AGENTS.md`.

```text
Project-specific rules in CLAUDE.md after @AGENTS.md
  ↓ always take precedence
Stack-specific rules from this starter
  ↓ govern the way of working
Clarity Framework documents in docs/
  ↓ provide architecture and requirements context
```

## Adding a new starter

1. Name the file `[stack].md` using lowercase letters and hyphens.
2. Follow the same structure: *How To Use*, *Core Rules*, optional profiles, and *Definition of Done*.
3. Refer to Clarity Framework documents in the Workflow section.
4. Include *When You Are a Dispatched Agent*; it keeps an agent within the approved plan's scope.
5. Add a row to the table above.
6. Add an entry to `framework/CHANGELOG.md`.

---

*Clarity Framework – Agents*
