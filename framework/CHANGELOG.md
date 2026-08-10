# CHANGELOG

## Clarity Framework

Alla betydande förändringar i ramverket dokumenteras här.  
Format följer [Keep a Changelog](https://keepachangelog.com/sv/1.0.0/).  
Versionshantering följer [Semantic Versioning](https://semver.org/lang/sv/).

---

## [Unreleased]

## [1.3.0] – 2026-08-10

### Ändrat

- `.gitignore`: `.token-pilot/` tillagd. Katalogen låg oskyddad och riskerade att committas av
  misstag, till skillnad från `.claude/` som redan ignorerades
- Skalningstabellen i `framework/dokumentationsguide.md` § 1: `00-ai-context.md` flyttad från
  obligatoriskt till valfritt för personliga/hobbyprojekt. Tabellen motsade `README.md` och § 12:s
  egen regel att AI-lagret är valfritt – ett personligt projekt kunde läsa två olika svar på om
  filen krävs
- `skills/planstyrt-bygge/SKILL.md` översatt till engelska. Ny språkkonvention i `CLAUDE.md`:
  innehåll som primärt läses av en agent (`agents/`, `SKILL.md`) skrivs på engelska, innehåll som
  läses och godkänns av en människa (`templates/`, ramverkets guider) på svenska
- `README.md` och `CLAUDE.md`: `docs-example/` borttagen ur repo-strukturen. Katalogen fanns aldrig
  i repot – referensen pekade på ingenting
- Avsnitt `Vid avslut` i `templates/plan.md` och `skills/planstyrt-bygge/plan-mall.md`: tre frågor som
  måste besvaras innan planen raderas – vad som hör hemma i `03-sad.md`, vad som hör hemma i
  `08-andringshantering.md`, och vad som var fel i planen. Planen raderades tidigare utan att något
  tvingade fram kontrollen, och lärdomen försvann med den
- `skills/planstyrt-bygge/`: nytt steg 7 (grind före merge) och steg 8 (avsluta planen). Flödet hade
  bara en namngiven grind – före bygget. Diffen granskades men ingen punkt gjorde godkännandet till
  ett uttalat beslut
- `skills/planstyrt-bygge/` bär nu en egen kopia av planmallen som `plan-mall.md`. Förutsättningen
  pekade på `templates/plan.md`, en sökväg som bara finns i ramverksrepot och aldrig i projekt som
  använder ramverket – flödet stannade därför på en förutsättning som var omöjlig att uppfylla.
  Synkkravet mot `templates/plan.md` är infört i `CLAUDE.md`
- `skills/planstyrt-bygge/`: nytt steg 6 som committar bygget. Flödet lämnade arbetsträdet smutsigt
  och blockerade därmed sin egen nästa körning på förutsättningen om rent repo. Kravet på rent repo
  är samtidigt motiverat i skillen – det finns för att göra Codex ändringar särskiljbara
- Scope-reglerna i samtliga sju starters skrivna om från storlek till gräns: `Keep changes minimal and localized` /
  `Implement the smallest coherent change` ersatta med `Deliver the task's full scope` plus `Stay inside the task's
  scope`. Den gamla formuleringen fick agenter att leverera skelett och fråga om de skulle fortsätta när uppgiften
  var att bygga något komplett. TDD-loopens `smallest change` är orörd – den gäller per testcykel, inte per uppgift
- Rapporteringsregeln i `electron-desktop.md`, `macos-swift.md`, `shell-dotfiles.md` och `vanilla-web-spa.md`:
  rapportera om uppgiften är klar eller inte, inte en lista över ändrade filer
- `framework/ai-usage-guide.md`: ny sektion 5 om flera agenter – roller, planen som artefakt, praktiska
  begränsningar och vad vinsten faktiskt är; tidigare sektion 5 omnumrerad till 6
- `framework/09-ai-usage-guide.md` omdöpt till `framework/ai-usage-guide.md`. Sifferprefixet kolliderade med
  `templates/09-grafisk-profil.md` och antydde att filen var ett projektdokument i `docs/`-sekvensen; den
  inledande dementin om detta är borttagen
- Inline-kopian av `00-ai-context.md`-mallen i `ai-usage-guide.md` § 3 ersatt med en hänvisning till
  `templates/00-ai-context.md`. Kopian hade glidit isär från mallen – saknade tabellstruktur, grafisk profil
  och avsnittet AI-arbetsflöde
- Rolltabellen i `ai-usage-guide.md` § 2 kompletterad med rad för grafisk profil
- Repo-strukturen i `README.md` uppdaterad – `09-grafisk-profil.md` och `agents/`-filerna saknades
- Läsordningen i samtliga sju starters villkorad: bara `docs/00-ai-context.md` och en eventuell styrande plan läses
  alltid, övriga dokument läses när uppgiften berör deras ämne. Startern läste tidigare upp till fem dokument oavsett
  uppgift, vilket kostade kontext utan att tillföra något för till exempel en ren CSS-ändring

### Tillagt

- `framework/dokumentationsguide.md` § 12: ny mening om att `00-ai-context.md` i praktiken är värt
  att skapa redan i Fas 1 när en AI-agent är inblandad, trots att den formellt är valfri
- `CLAUDE.md`: ny sektion `Språkkonvention`
- `skills/planstyrt-bygge/SKILL.md` steg 4: hantering av abonnemangs-/tokenlimit mitt i bygget via
  [aimux](https://github.com/Digital-Threads/aimux) om verktyget redan är installerat och
  konfigurerat – sammanfattningsöverlämning till en annan CLI/konto istället för att bygget bara
  tappas. Oprövat i skarpt läge; flödet instrueras att falla tillbaka till stanna-och-rapportera om
  det inte fungerar som beskrivet
- `framework/ai-usage-guide.md` § 5: ny sektion `Verktygsdetektion` – principen att kompletterande
  verktyg (limit-failover, kontextkomprimering) får användas om de redan finns installerade, men
  aldrig krävs
- `templates/plan.md` – transient arbetsorder för planstyrt arbetsflöde där en agent planerar och en annan bygger;
  auktoritativt omfattningsavsnitt med `Ingår` / `Ingår inte`, blockerande frågor och kontrollerbar Definition of Done
- Avsnitt `AI-arbetsflöde` i `templates/00-ai-context.md`: rolltabell (planerare / byggare / granskare) och
  planplacering, utelämnas av projekt som använder en enda agent
- Läsordningen i samtliga sju starters utökad med `docs/plans/` – planens omfattningsavsnitt är auktoritativt,
  byggagenten planerar inte om utan stannar och rapporterar
- Avsnitt `Flera agenter` i `framework/dokumentationsguide.md` § 12
- Ny katalog `/skills/` med skills att kopiera till ett projekts `.claude/skills/`, plus `skills/README.md`
  som förklarar vad en skill är, hur den skiljer sig från `AGENTS.md` och vad som gäller före vad
- `skills/planstyrt-bygge/` – kör hela det planstyrda flödet: Claude Code skriver planen, Codex CLI granskar
  den mot koden read-only, flödet stannar för godkännande av omfattningen, Codex bygger i bakgrunden med
  `workspace-write`, Claude Code granskar diffen mot Definition of Done och tar aldrig över bygget
- Avsnitt `Automatisera flödet` i `framework/ai-usage-guide.md` § 5
- `agents/electron-desktop.md` – AGENTS.md-starter för Electron-baserade desktop-appar med native känsla: obligatorisk
  säkerhetssektion (context isolation, sandbox, contextBridge, CSP, IPC-validering), processarkitektur main/preload/
  renderer, Native Platform Integration (fönsterchrome, menyer med `role`, plattformsgenvägar, native dialoger,
  systemtema, `ready-to-show`), Development Run Model, prestanda och Playwright-baserad testning; valfria profiler för
  Renderer Framework, Local Persistence, Auto Update, Packaging and Distribution och Native Modules

## [1.2.0] – 2026-06-12

### Tillagt

- Repository- och releaseflöde för projekt som använder Clarity Framework: commit/push-regler, pull requests,
  GitHub Actions-workflows, taggbaserade GitHub Releases, releasenoter och spårbar releasehistorik i Deployment
  View, Runbook, ändringshantering och dokumentationsguiden
- `agents/r-shiny.md` – AGENTS.md-starter för R/Shiny-applikationer med valfria profiler för renv, Tidyverse, Persistence (DBI), Plumber och Deployment
- `agents/ios-springboot.md` – hybrid AGENTS.md-starter för Spring Boot-backend med native iOS/iPadOS-frontend i Swift; täcker Integration Contract, Development Networking (Simulator vs fysisk enhet), ATS-krav, authentication-flöde (JWT + Keychain), och Distribution
- Lombok obligatoriskt i `agents/java-application.md`: flyttat från Optional Profile till egen obligatorisk sektion; borttaget ur How To Use-listan
- Lombok obligatoriskt i `agents/ios-springboot.md`: tillagt som obligatorisk undersektionen i Spring Boot Backend-profilen
- Ny mall `templates/09-grafisk-profil.md`: varumärkesgrunder, WCAG-kontrastkrav, design tokens i DTCG-format med fullständigt JSON-exempel, plattformstransformation via Style Dictionary, ägarskap och underhållsprocess
- Grafisk profil tillagd i `framework/dokumentationsguide.md` som sektion 10: obligatorisk för projekt med UI, med fasdiagram och review-checklist uppdaterade
- Grafisk profil tillagd i dokumenthierarkin i `templates/00-ai-context.md`
- `agents/vanilla-web-spa.md`, `agents/macos-swift.md`, `agents/ios-springboot.md` och Web Frontend-profilen i `agents/java-application.md`: läs `docs/09-grafisk-profil.md` före visuellt arbete; inga hårdkodade visuella värden när tokens finns
- MCP Server-profil i `agents/java-application.md`: transport-val (STDIO / Streamable HTTP), tool design, resurser och prompts, säkerhet och testning med Spring AI MCP Boot Starter
- Hot Reload-sektion i `agents/r-shiny.md`: `shiny.autoreload`-konfiguration för filbevakad omladdning under utveckling
- Development Run Model-sektion i `agents/java-application.md` (Web Frontend-profil): skiljer på Embedded och Standalone, kräver att körmodellen är dokumenterad, beskriver Spring Boot DevTools och hot reload via proxy
- Körmodellsvarning i `agents/vanilla-web-spa.md` Workflow: agenten ska verifiera hur projektet körs innan en separat frontend-server startas
- Accessibility Testing-sektion i `agents/r-shiny.md` med tre nivåer: `a11yShiny` (byggnorm), `shinya11y` (dev-inspektion) och axe-core via `shinytest2` (automatiserad skanning)
- Automated Accessibility Testing-sektion i `agents/vanilla-web-spa.md` med `@axe-core/playwright`, WCAG 2.1 AA-baslinje och riktlinjer för undantag
- Accessibility Testing-sektion i `agents/java-application.md` (Web Frontend-profil) med motsvarande axe-core/Playwright-riktlinjer
- Uppdaterade Testing-sektioner i `vanilla-web-spa.md` och `java-application.md` med riktlinjer för Playwright-lokaliserare (`getByRole`, `getByLabel`, `getByText`)

### Borttaget

- Versionshanterad `.markdownlint.json`; konfigurationen används lokalt och ignoreras av Git
- Inaktuella samarbetsinstruktioner för Claude.ai-synkning och pull requests till solo-repot

## [1.1.0] – 2026-04-22

### Tillagt

- Ny katalog `/agents/` med fördefinierade AGENTS.md-starters för Java, Vanilla Web SPA, Shell/Dotfiles och macOS Swift
- `/agents/README.md` förklarar katalogens syfte, hur man väljer och anpassar en starter, och prioritetsordningen mot övriga Clarity Framework-dokument
- Samtliga starters integrerade med Clarity Framework: strukturerade dokumentreferenser i Workflow-steget (ersätter generisk `ARCHITECTURE.md`-referens) och i Documentation/Hygiene-sektionerna

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
