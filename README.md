# Clarity Framework

> Ett metodagnostiskt dokumentationsramverk för mjukvaruutveckling.  
> Fungerar för alla skalor – från ett personligt sidoprojekt till ett team på 20 personer.  
> AI-assistans är ett valfritt accelerationslager, inte en förutsättning.

**Version:** 1.5.0 · [CHANGELOG](./framework/CHANGELOG.md)

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
│   ├── README.md                       # Välj rätt starter och lägg avvikelser i CLAUDE.md
│   ├── generic.md                      # Neutral fallback när ingen stack-starter matchar
│   ├── java-application.md
│   ├── ios-springboot.md
│   ├── electron-desktop.md
│   ├── macos-swift.md
│   ├── r-shiny.md
│   ├── vanilla-web-spa.md
│   └── shell-dotfiles.md
│
├── skills/                             # Skills att kopiera till .agents/skills/ och .claude/skills/
│   ├── README.md                       # Vad en skill är och hur den används
│   ├── clarity-bootstrap/              # Behovsstyrd uppsättning av ett nytt projekt
│   │   ├── SKILL.md
│   │   └── agents/openai.yaml          # Valfri Codex-UI-metadata; krävs inte av Claude
│   ├── ramverksuppdatering/            # Lyfter ett projekt till senaste releasen
│   │   └── SKILL.md
│   └── planstyrt-bygge/                # Claude eller Codex orkestrerar externa Codex-körningar
│       ├── SKILL.md                    # Proceduren – det enda orchestratorn läser
│       ├── prompts/                    # Dispatch-prompter, utanför orchestratorns kontext
│       ├── dispatch.sh                 # Enda vägen till en dispatch: sandbox, approval, budget
│       ├── tests/dispatch-test.sh       # Regressionstest för CLI-ordning och sentinel
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
├── .agents/
│   └── skills/                    # Codex: kopior av valda ramverksskills
├── .claude/
│   └── skills/                    # Claude Code: identiska kopior av samma skills
│
├── AGENTS.md                      # Kopia av vald /agents/-starter, oredigerad
├── CLAUDE.md                      # `@AGENTS.md` + projektspecifika regler
└── …                              # Projektets egen kod
```

### Vem äger vad

| Sökväg | Ägare | Vid uppdatering |
| --- | --- | --- |
| `AGENTS.md` | Ramverket | **Ersätts helt.** Redigeras aldrig i projektet |
| `.agents/skills/<clarity-skill>/` | Ramverket | **Ersätts helt.** Bara namn listade i `docs/.clarity-version`; andra skills rörs aldrig |
| `.claude/skills/<clarity-skill>/` | Ramverket | **Ersätts helt.** Identisk Claude-kopia av samma listade skills |
| `docs/NN-*.md` | Projektet | Innehållet behålls, strukturen lyfts till nya mallen |
| `docs/.clarity-version` | Ramverket | Skrivs om vid varje uppdatering |
| `CLAUDE.md`, övriga skills, kod, allt annat | Projektet | **Skrivs aldrig över** |

Regeln är att en fil har en ägare, inte två. Det som är projektspecifikt hör hemma i `CLAUDE.md` –
aldrig som en lokal redigering i en ramverksägd fil. För dubbel kompatibilitet börjar filen med
`@AGENTS.md`: Claude Code importerar då startern automatiskt, medan Codex läser `AGENTS.md` direkt
och instrueras där att även läsa den projektspecifika delen av `CLAUDE.md`.

---

## Kom igång

### Nytt projekt

Rekommenderat: kopiera `skills/clarity-bootstrap/` till både `.agents/skills/` och
`.claude/skills/`. Anropa `$clarity-bootstrap` i Codex eller `/clarity-bootstrap` i Claude Code.
Skillen utgår från vad som ska byggas, föreslår minsta sammanhängande dokumentuppsättning och
stannar för godkännande innan den skriver.

Manuell uppsättning:

1. Skapa en `/docs`-mapp i ditt projektrepo
2. Kopiera relevanta mallar från `/templates/` till `/docs/`
3. Börja alltid med `01-vision-scope.md`
4. Välj dokumentationsnivå efter projektstorlek:

| Projektstorlek | Obligatoriskt | Valfritt |
| --- | --- | --- |
| Personligt / hobby | 01, README; 09 före visuellt UI-arbete | 00 om AI används; övriga vid behov |
| Sidoprojekt med lansering | 01, 02, 03, 06, README; 04 vid data/API, 05 vid deployment, 07 vid drift, 09 vid UI | 00 om AI används, 08 vid ändringsspårning |
| Litet team (2–5 pers) | 01, 02, 03, 06, 08; 04 vid data/API, 05 vid deployment, 07 vid drift, 09 vid UI | 00 om AI används |
| Större team (5–20 pers) | 01, 02, 03, 06, 08; 04 vid data/API, 05 vid deployment, 07 vid drift, 09 vid UI; striktare DoD | 00 om AI används; formell releaseprocess vid behov |

### Befintligt projekt på en äldre version

Kopiera `skills/ramverksuppdatering/` till både projektets `.agents/skills/` och
`.claude/skills/`, och anropa den som `$ramverksuppdatering` i Codex eller
`/ramverksuppdatering` i Claude Code. Den hämtar
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

*Clarity Framework v1.5.0*
