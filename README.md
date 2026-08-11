# Clarity Framework

> Ett metodagnostiskt dokumentationsramverk för mjukvaruutveckling.  
> Fungerar för alla skalor – från ett personligt sidoprojekt till ett team på 20 personer.  
> AI-assistans är ett valfritt accelerationslager, inte en förutsättning.

**Version:** 1.3.0 · [CHANGELOG](./framework/CHANGELOG.md)

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
│   └── planstyrt-bygge/                # Claude orkestrerar, Codex planerar och bygger
│       ├── SKILL.md                    # Proceduren – det enda orchestratorn läser
│       ├── prompts/                    # Dispatch-prompter, utanför orchestratorns kontext
│       ├── dispatch.sh                 # Enda vägen till en dispatch: sandbox, approval, budget
│       ├── plan-mall.md                # Kopia av templates/plan.md – följer med skillen
│       ├── kor-mall.md                 # Körjournal – flödets tillstånd mellan sessioner
│       ├── uppsattning.md              # Engångsuppsättning: profiler och permissions
│       └── settings.exempel.json       # Permissionslista för Claude Code
│
└── README.md                           # Denna fil
```

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

*Clarity Framework v1.3.0*
