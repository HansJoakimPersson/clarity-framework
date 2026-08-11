# CHANGELOG

## Clarity Framework

Alla betydande förändringar i ramverket dokumenteras här.  
Format följer [Keep a Changelog](https://keepachangelog.com/sv/1.0.0/).  
Versionshantering följer [Semantic Versioning](https://semver.org/lang/sv/).

---

## [Unreleased]

### Tillagt

- `skills/ramverksuppdatering/` – ny skill som lyfter ett projekt till senaste releasen. Hämtar
  ramverket från GitHub och klassar varje fil genom en **trevägsjämförelse**: filen vid projektets
  baseline-version, filen vid den nya versionen, och filen i projektet. Det gör skillnaden mellan
  "orörd sedan den kopierades" (säker att ersätta) och "ifylld eller anpassad" (rörs aldrig) exakt
  istället för gissad. Ifyllt innehåll flyttas in i den nya strukturen ordagrant; innehåll som inte
  har någon plats i den nya strukturen behålls och flaggas hellre än raderas. Skillen dispatchar
  ingenting och har ingen koppling till `planstyrt-bygge` – den kör i din egen session
- `docs/.clarity-version` – ny projektartefakt som `ramverksuppdatering` skriver: version, datum,
  vald `agents/`-starter och installerade skills. Versionen gick tidigare bara att läsa ur
  `00-ai-context.md`, som är valfri för mindre projekt – ett projekt kunde alltså sakna varje spår
  av vilken version det byggdes på
- `skills/planstyrt-bygge/prompts/` – dispatch-prompterna flyttade från `SKILL.md` till fyra
  separata filer (`1-plan`, `2-kritik`, `4-bygge`, `5-verifiering`). Motivet är rent
  kostnadsmässigt: prompterna utgjorde omkring 500 av `SKILL.md`:s 2 287 ord, och lästes in i
  orchestratorns kontext vid varje anrop trots att orchestratorn aldrig behöver dem. Utflyttade
  kunde de dessutom göras mer explicita (nu 682 ord) utan att det kostar orchestratorn något.
  Orchestratorn fyller platshållare (`{{PLAN}}`, `{{TASK}}`, `{{DATE}}`, `{{SHA}}`) och ser
  aldrig innehållet
- `skills/planstyrt-bygge/dispatch.sh` – enda vägen till en dispatch. Renderar promptfilen, sätter
  sandbox **och** approval-policy tillsammans, upptäcker saknad `aimux`-profil och rapporterar det
  som en explicit `FALLBACK:`-rad istället för att tyst landa på inloggat konto, och skriver ut
  rapportens radantal mätt mot budgeten. Bakgrundsläge skriver exitkoden till en sentinelfil.
  Ett skript med stabil sökväg är dessutom det enda en permissionsregel kan matcha pålitligt –
  ett env-prefixat, bakgrundskört sammansatt kommando är det inte
- `skills/planstyrt-bygge/journal-mall.md` – körjournal (`docs/plans/*.run.md`). Flödets tillstånd
  levde tidigare enbart i orchestratorns kontextfönster, vilket gjorde orchestratorn oersättlig:
  en tokengräns mitt i ett bygge tappade hela flödet och "byt CLI" var inte en möjlig manöver.
  Journalen uppdateras efter varje steg och committas med planen
- `skills/planstyrt-bygge/codex-orchestrator.md` – frontend som låter Codex hålla orchestrator-
  rollen, kopieras till `~/.codex/prompts/planstyrt-bygge.md`. Flödet låg tidigare inbakat i ett
  Claude-skillformat, så "byt orchestrator när ett abonnemang tar slut" var i praktiken en
  omskrivning av flödet, inte ett byte. Filen duplicerar inte proceduren – den pekar på samma
  `SKILL.md` och beskriver bara de fem delta som gäller när Codex håller rollen, bland annat att
  budgeten där saknar `deny`-regler och alltså vilar på instruktion
- `skills/planstyrt-bygge/uppsattning.md` – engångsuppsättning per maskin: aimux-profiler,
  Codex-profil med `network_access` för orchestratorrollen, installation av Codex-frontenden,
  permissionslista, gitignore
- `skills/planstyrt-bygge/settings.exempel.json` – permissionslista för Claude Code. `deny`-halvan
  (`git diff`, `git show`, läsning av `prompts/`) gör läsbudgeten till en regel istället för en
  uppmaning
- `skills/planstyrt-bygge/SKILL.md`: avsnitt om grindprofiler, orchestratorbudget och
  återupptagande av avbruten körning
- `framework/ai-usage-guide.md` § 5: fyra nya avsnitt – *Orchestratorbudget*, *Tillståndet ligger i
  filer, inte i orchestratorn*, *Permissionsmodellen* och *Grindprofiler*. Nivåtabellen utökad med
  en valfri Granskning-nivå
- `agents/*.md` (samtliga sju starters): sektionen *When You Are a Dispatched Agent*. Reglerna för
  en dispatchad agent – planens omfattning är auktoritativ, stanna vid fel plan, spawna inga
  subprocesser, håll rapportbudgeten, committa inte – låg tidigare bara som upprepade textrader i
  dispatch-prompterna och försvann om någon redigerade en prompt
- `templates/plan.md` och `skills/planstyrt-bygge/plan-mall.md`: fälten `Grindprofil`,
  `Rapportbudget` och `Körjournal`, samt krav på att Definition of Done-villkor ska gå att belägga
  med filväg, symbolnamn eller kommandoutfall
- `templates/00-ai-context.md`: avsnittet *AI-arbetsflöde* omgjort till ett runtime-kontrakt med
  kolumner för profil och sandbox/approval per nivå, plus fälten körjournal och orchestratorbudget

### Ändrat

- `skills/planstyrt-bygge/` steg 2 körs nu under en egen `granskning`-profil med `--fallback
  reasoning`. Kritikpasset var tidigare en självgranskning inom samma nivå, med den bedömnings-
  blindfläck det innebär. Med ett tredje konto blir det en korsgranskning utan extra kostnad på
  orchestratorn; saknas profilen faller det tillbaka och `dispatch.sh` säger till
- `skills/planstyrt-bygge/` steg 4: bygget körs inte längre som ett `nohup`-kommando vars enda spår
  är en PID i orchestratorns kontext. `dispatch.sh --background` skriver exitkoden till en
  sentinelfil, så färdigstatus kan konstateras med en filkontroll istället för genom att följa
  byggloggen – och ett bygge överlever den session som startade det
- `skills/planstyrt-bygge/` samtliga dispatcher sätter nu approval-policy explicit (`-a never`)
  vid sidan av sandbox. Tidigare sattes bara sandbox, vilket lämnade approval på sitt default –
  den vanligaste orsaken till att en obevakad körning stannar och frågar mitt i ett bygge
- `skills/planstyrt-bygge/` dispatch-artefakter flyttade från `/tmp` till `docs/plans/.runs/`.
  Ramverkets egen regel säger att en agent bara ser det som ligger i repot, och samma sak gäller
  vid överlämning mellan CLI:er – `/tmp` motsade den regeln
- `skills/planstyrt-bygge/plan-mall.md` är nu en exakt kopia av `templates/plan.md`. Filerna
  skilde sig på två rader, vilket gjorde dubblettkontrollen till en bedömningsfråga; nu är den
  `diff templates/plan.md skills/planstyrt-bygge/plan-mall.md`
- `framework/dokumentationsguide.md` § 12: avsnittet *Flera agenter* utökat med budget, körjournal
  och principen att grindar ska ligga på beslut, inte på verktygsanrop
- `CLAUDE.md`: språkundantaget för `skills/planstyrt-bygge/` explicitgjort, och commit-regeln för
  planmallen skärpt till ett verifierbart `diff`-kommando

- `skills/planstyrt-bygge/` dispatch-kommandon (steg 1, 2, 4, 5) prefixade med `CODEX_HOME="$HOME/.aimux/profiles/<profil>"`.
  Kommandona körde tidigare bara `codex exec` rakt av, vilket observerades i skarpt bruk – de landade
  då på vilket konto som redan var inloggat på maskinen istället för en separat `aimux`-profil, vilket
  gör hela poängen med nivåuppdelningen (kostnadsfördelning över konton) skenbar. Förutsättningarna
  kräver nu två namngivna `aimux`-profiler (`reasoning`, `implementation`) med fallback till vanlig
  `codex exec` – och en tydlig varning till användaren om fallbacken används
- `skills/planstyrt-bygge/` dispatch-prompts (steg 1, 2, 4, 5): tillagd instruktion att ignorera ett
  eventuellt kopierat `planstyrt-bygge`-skillfilerna i målrepot och aldrig anropa `codex` som
  subprocess. Observerat i skarpt bruk: en dispatchad agent som hittar skillfilen i repot kan annars
  försöka följa orkestreringsflödet själv och spawna nästlade `codex exec`-processer
- `.gitignore`: `.claudeignore` och `.mcp.json` tillagda. Båda genererades lokalt av token-pilots
  bootstrap-hook och innehåller bara personlig tooling-konfiguration (token-pilot, context-mode) –
  samma resonemang som `.token-pilot/` i förra releasen
- Rollmodellen för flera agenter döpt om från Planerare/Byggare/Granskare till
  Orchestrator/Reasoning/Implementation i `framework/ai-usage-guide.md` § 5,
  `templates/00-ai-context.md` och `framework/dokumentationsguide.md` § 12. Planerare och Granskare
  slås ihop till Reasoning – den enda konkreta implementationen (`skills/planstyrt-bygge/`) körde
  redan båda som samma agent, tabellen låtsades att de var separata
- `skills/planstyrt-bygge/`: orchestratorn (Claude Code) skriver inte längre planen själv och läser
  inte längre hela diffen själv. Steg 1 (plan) och steg 5 (verifiering mot Definition of Done)
  dispatchas nu till en reasoning-nivå som körs under ett annat CLI/konto, och orchestratorn läser
  bara det destillerade resultatet. Motivet: orchestratorns egen kontext och tokenförbrukning ska
  hållas liten oavsett hur stor kodbasen eller diffen är, och kostnaden ska faktiskt fördelas över
  separata konton – inte bara isoleras i kontext, vilket en Claude-subagent (Task-verktyget) inte
  uppnår eftersom den delar abonnemang med orchestratorn
- `skills/planstyrt-bygge/`: `Status: Godkänd` sätts nu efter användarens klartecken, inte innan.
  Tidigare ordning satte statusen före stoppunkten för godkännande, vilket lät fältet påstå ett
  beslut som ännu inte fattats

### Tillagt

- `framework/ai-usage-guide.md` § 5: ny sektion om kostnadsfördelning – varför Reasoning och
  Implementation måste köras under ett annat CLI/konto än orchestratorn för att faktiskt spara
  tokens på den interaktiva sessionen, inte bara isolera kontext
- `skills/planstyrt-bygge/` steg 2: explicit notering att kritikpasset är en självgranskning inom
  samma nivå, inte en korsgranskning mellan olika agenter som tidigare – en medveten avvägning värd
  att känna till, inte en dold försämring

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
