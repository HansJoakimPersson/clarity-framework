# Clarity Framework

> Ett metodagnostiskt dokumentationsramverk för mjukvaruutveckling.  
> Fungerar för alla skalor – från ett personligt sidoprojekt till ett team på 20 personer.  
> AI-assistans är ett valfritt accelerationslager, inte en förutsättning.

**Version:** 1.4.0 · [CHANGELOG](./framework/CHANGELOG.md)

---

## Tre kärnprinciper

- **Just enough documentation** – varje dokument ska tillföra värde, inte skapa byråkrati
- **Dokumentation som kod** – versioneras i Git, granskas i PR, lever nära implementationen
- **Klarhet framför fullständighet** – ett tydligt halvfärdigt dokument är bättre än ett otydligt komplett

---

## Repo-struktur

```text
clarity-framework/
│
├── framework/                          # Ramverkets egna dokument
│   ├── dokumentationsguide.md          # Huvudguiden – riktlinjer för alla dokumenttyper
│   ├── ai-usage-guide.md               # AI som valfritt accelerationslager
│   ├── PROJEKTINSTRUKTIONER.md         # Instruktioner för Claude/OpenAI projekt
│   └── CHANGELOG.md                   # Versionshistorik
│
├── templates/                          # Mallar – kopiera till ditt projekts /docs
│   ├── 00-ai-context.md                # Komprimerad projektöversikt för AI-sessioner
│   ├── 01-vision-scope.md
│   ├── 02-kravdokumentation.md
│   ├── 03-sad.md
│   ├── 04-datamodell-api.md
│   ├── 05-deployment-view.md
│   ├── 06-testdokumentation.md
│   ├── 07-runbook.md
│   ├── 08-andringshantering.md
│   ├── 09-grafisk-profil.md            # Varumärke och design tokens (DTCG)
│   └── plan.md                         # Arbetsorder vid planstyrt AI-arbetsflöde
│
├── agents/                             # AGENTS.md-starters per stack
│   ├── README.md                       # Välj och anpassa rätt starter
│   ├── java-application.md
│   ├── ios-springboot.md
│   ├── electron-desktop.md
│   ├── macos-swift.md
│   ├── r-shiny.md
│   ├── vanilla-web-spa.md
│   └── shell-dotfiles.md
│
├── skills/                             # Skills att kopiera till .claude/skills/
│   ├── README.md                       # Vad en skill är och hur den används
│   ├── ramverksuppdatering/            # Lyfter ett projekt till senaste releasen
│   │   └── SKILL.md
│   └── planstyrt-bygge/                # Claude orkestrerar, Codex planerar och bygger
│       ├── SKILL.md                    # Proceduren – det enda orchestratorn läser
│       ├── codex-orchestrator.md       # Frontend: Codex tar orchestratorrollen
│       ├── prompts/                    # Dispatch-prompter, utanför orchestratorns kontext
│       ├── dispatch.sh                 # Enda vägen till en dispatch: sandbox, approval, budget
│       ├── plan-mall.md                # Kopia av templates/plan.md – följer med skillen
│       ├── journal-mall.md             # Körjournal – flödets tillstånd mellan sessioner
│       ├── uppsattning.md              # Engångsuppsättning: profiler och permissions
│       └── settings.exempel.json       # Permissionslista för Claude Code
│
└── README.md                           # Denna fil
```

---

## Projektstruktur

Så här ser ett projekt ut som använder ramverket. Det här avsnittet är **normerande** – det avgör var
filer hamnar, och `skills/ramverksuppdatering/` läser det för att veta vart den ska lägga saker.

```text
mitt-projekt/
│
├── docs/                          # Ramverkets dokument, ifyllda för projektet
│   ├── .clarity-version           # Vilken ramverksversion projektet ligger på
│   ├── 00-ai-context.md
│   ├── 01-vision-scope.md         # … till och med 09, de projektet valt
│   └── plans/                     # Transienta arbetsordrar, om planstyrt flöde används
│
├── .claude/
│   └── skills/                    # Kopior av ramverkets /skills/
│       ├── ramverksuppdatering/
│       └── planstyrt-bygge/
│
├── AGENTS.md                      # Kopia av vald /agents/-starter, oredigerad
├── CLAUDE.md                      # Projektspecifika regler – ägs av projektet
└── …                              # Projektets egen kod
```

### Vem äger vad

| Sökväg | Ägare | Vid uppdatering |
| --- | --- | --- |
| `AGENTS.md` | Ramverket | **Ersätts helt.** Redigeras aldrig i projektet |
| `.claude/skills/*/` | Ramverket | **Ersätts helt.** Redigeras aldrig i projektet |
| `docs/NN-*.md` | Projektet | Innehållet behålls, strukturen lyfts till nya mallen |
| `docs/.clarity-version` | Ramverket | Skrivs om vid varje uppdatering |
| `CLAUDE.md`, kod, allt annat | Projektet | **Rörs aldrig** |

Regeln är att en fil har en ägare, inte två. Det som är projektspecifikt hör hemma i `CLAUDE.md` –
aldrig som en lokal redigering i en ramverksägd fil, eftersom en sådan redigering går förlorad vid
nästa uppdatering och inte går att skilja från en föråldrad version.

---

## Kom igång

### Nytt projekt

1. Skapa en `/docs`-mapp i ditt projektrepo
2. Kopiera relevanta mallar från `/templates/` till `/docs/`
3. Börja alltid med `01-vision-scope.md`
4. Välj dokumentationsnivå efter projektstorlek:

| Projektstorlek | Obligatoriskt | Valfritt |
| --- | --- | --- |
| Personligt / hobby | 01, README | Övriga vid behov |
| Sidoprojekt med lansering | 01, 02, 03, README | 04, 05, 07 |
| Litet team (2–5 pers) | Alla 01–08 | 00, 09 |
| Större team (5–20 pers) | Alla 00–08 | 09 |

### Befintligt projekt på en äldre version

Kopiera `skills/ramverksuppdatering/` till projektets `.claude/skills/` och anropa den. Den hämtar
senaste releasen, jämför projektets filer mot den version de kopierades från, och lyfter projektet
till nuvarande struktur utan att skriva över något du fyllt i. Nya mallar och avsnitt kommer in
tomma – rapporten säger vilka som behöver fyllas.

Den skriver också `docs/.clarity-version`, vilket gör nästa uppgradering exakt istället för härledd.
Ett projekt som satts upp innan skillen fanns saknar den filen och får versionen härledd vid första
körningen – skillen säger uttryckligen till när den härleder istället för att läsa.

## Dokumentflöde

```text
00-ai-context        ← Uppdateras löpande. Klistras in i ny AI-session.
      ↕
01-vision-scope      ← Starta här. Godkänns innan allt annat.
        ↓
02-kravdokumentation ← NFR definieras innan funktionella krav.
        ↓
03-sad               ← Arkitektur grundad i NFR:erna.
        ↓
04-datamodell-api    ← Contract-first, innan implementation.
        ↓
05-deployment-view   ← CI/CD och infrastruktur.
        ↓
06-testdokumentation ← Parallellt med implementation.
07-runbook           ← Vid första staging-deployment.
08-andringshantering ← Löpande under hela produktens livstid.
```

---

*Clarity Framework v1.4.0*
