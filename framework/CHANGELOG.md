# CHANGELOG

## Clarity Framework

Alla betydande förändringar i ramverket dokumenteras här.  
Format följer [Keep a Changelog](https://keepachangelog.com/sv/1.0.0/).  
Versionshantering följer [Semantic Versioning](https://semver.org/lang/sv/).

---

## [Unreleased]

### Tillagt

- Ny katalog `/agents/` med fördefinierade AGENTS.md-starters för Java, Vanilla Web SPA, Shell/Dotfiles och macOS Swift
- `/agents/README.md` förklarar katalogens syfte, hur man väljer och anpassar en starter, och prioritetsordningen mot övriga Clarity Framework-dokument
- Samtliga starters uppdaterade med strukturerade Clarity Framework-dokumentreferenser i Workflow-steget (ersätter generisk `ARCHITECTURE.md`-referens) och i Documentation/Hygiene-sektionerna

### Korrigerat

- Lade till `.markdownlint.json` med projektanpassad konfiguration (MD013, MD024, MD036 avstängda)
- Åtgärdat formateringsfel (MD040, MD060, MD022/031/032) i alla 15 markdown-filer: tabellseparatorer, saknade tomrader och kodblock utan språkspecifikation

## [1.0.0] – 2026-04

### Tillagt

- Initial version av Clarity Framework

### Filosofi

*Just enough documentation* – metodagnostisk, teamagnostisk, skalbar.

---

## Versionshanteringsprinciper

| Typ | När | Exempel |
| --- | --- | --- |
| **Patch** (x.x.Y) | Korrigeringar, förtydliganden, stavfel | Felaktig instruktion i Runbook |
| **Minor** (x.Y.0) | Nya sektioner, nya mallar, nya riktlinjer | Ny malltyp, ny sektion i guiden |
| **Major** (Y.0.0) | Förändringar som bryter bakåtkompatibilitet med ifyllda dokument | Ändrat mallformat som kräver migrering |
