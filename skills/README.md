# Skills – återanvändbara arbetsflöden för Claude Code och Codex

Den här katalogen innehåller färdiga skills att kopiera in i ett projekt när flödet behövs.

En kopierad skill **ägs av ramverket och redigeras inte i projektet** – den ersätts i sin helhet när
projektet uppdateras till en ny ramverksversion. Det gäller bara skillnamn som listas i
`docs/.clarity-version`; andra lokala eller tredjepartsinstallerade skills rörs aldrig. Behöver
flödet bete sig annorlunda i just ditt projekt hör det hemma i projektets `CLAUDE.md`, som
ramverket inte skriver över. Se ägarskapstabellen i
ramverkets `README.md`.

---

## Vad är en skill?

En skill är ett namngivet arbetsflöde enligt Agent Skills-formatet som Claude Code och Codex kan
anropa. Den skiljer sig från övriga
Clarity Framework-dokument i vad den svarar på:

| Dokument | Svarar på |
| --- | --- |
| `docs/00-ai-context.md` | Vad är projektet? |
| `AGENTS.md` | Hur ska agenten arbeta här, alltid? |
| `.agents/skills/*/SKILL.md` / `.claude/skills/*/SKILL.md` | Hur körs det här specifika flödet, när det körs? |

`AGENTS.md` gäller varje uppgift. En skill gäller bara när den anropas.

---

## Tillgängliga skills

| Katalog | Passar när... |
| --- | --- |
| `clarity-bootstrap/` | Ett nytt eller ännu inte Clarity-hanterat projekt ska få minsta relevanta dokumentuppsättning, rätt stack-starter och skills för båda klienterna utifrån vad som ska byggas |
| `planstyrt-bygge/` | Uppgiften är stor nog att omfattningen behöver godkännas innan kod skrivs, och du vill att Claude Code eller Codex orchestrerar medan planering, granskning och bygge dispatchas till andra CLI:er/konton |
| `ramverksuppdatering/` | Projektet ligger på en äldre version av ramverket och ska lyftas till senaste releasen utan att det som redan är ifyllt går förlorat |

De tre är oberoende av varandra. `clarity-bootstrap/` sätter upp ett ännu inte hanterat projekt,
medan `ramverksuppdatering/` endast arbetar med projekt som redan har en ramverksversion. Den senare
dispatchar ingenting och har inget med
orkestrering att göra – den kör i din session och rör bara godkända ramverksfiler under `docs/`,
`AGENTS.md`, `.agents/skills/` och `.claude/skills/`.

---

## Så använder du en

1. Kopiera samma katalog till båda klienternas projektsökvägar:

   ```bash
   mkdir -p /sökväg/till/projektet/.agents/skills /sökväg/till/projektet/.claude/skills
   cp -R skills/planstyrt-bygge /sökväg/till/projektet/.agents/skills/
   cp -R skills/planstyrt-bygge /sökväg/till/projektet/.claude/skills/
   diff -qr /sökväg/till/projektet/.agents/skills/planstyrt-bygge \
     /sökväg/till/projektet/.claude/skills/planstyrt-bygge
   ```

2. Gå igenom `uppsattning.md` – profiler, sandbox- och approval-inställningar, permissionslista.
   Det är en engångsuppsättning per maskin och den som avgör om flödet kan köra obevakat.
3. Anropa den i Claude Code med `/planstyrt-bygge`, eller i Codex med `$planstyrt-bygge` eller
   genom `/skills`.

Steg 2 rör din maskin, inte de kopierade filerna. Behöver projektet avvika från flödet skriver du
det i projektets `CLAUDE.md` – de kopierade filerna lämnas orörda så att de kan ersättas vid nästa
ramverksuppdatering.

### Vad filerna i `planstyrt-bygge/` gör

| Fil | Roll |
| --- | --- |
| `SKILL.md` | Proceduren. Det enda orchestratorn läser vid anrop – skriven för rollen, inte för ett visst CLI |
| `prompts/*.txt` | Instruktionerna till de dispatchade agenterna. Ligger i filer just för att hållas utanför orchestratorns kontext – orchestratorn fyller platshållare, den läser dem inte |
| `dispatch.sh` | Enda vägen till en dispatch. Sätter sandbox och approval tillsammans, upptäcker saknad kontoprofil, mäter rapportens storlek mot budgeten |
| `tests/dispatch-test.sh` | Regressionstest för Codex CLI-flaggornas ordning och sentinel vid misslyckad bakgrundskörning |
| `plan-mall.md` | Planmallen. Identisk kopia av ramverkets `templates/plan.md` – skillen kopieras ensam och måste bära sin egen |
| `journal-mall.md` | Körjournalmallen. Flödets tillstånd utanför orchestratorns kontext |
| `uppsattning.md` | Engångsuppsättning: profiler, permissions, gitignore |
| `settings.exempel.json` | Permissionslista för Claude Code. `deny`-halvan gör läsbudgeten till en regel istället för en uppmaning |

Skills versioneras i projektrepot som all annan dokumentation som kod. Kontrollera med
`git check-ignore` att en bred regel för `.claude/` eller `.agents/` inte råkar utesluta de två
hanterade kopiorna; lokala settings, credentials och caches ska fortsatt vara ignorerade.

Mapparna `prompts/` i en skill är interna resurser för dess skript. De har ingen koppling till
Codex utfasade `~/.codex/prompts/` eller Claude Codes äldre `.claude/commands/`; båda klienterna
använder den delade `SKILL.md`-frontenden.

---

## Vad som gäller före vad

Samma prioritetsordning som för `agents/`:

1. Uttrycklig instruktion från användaren i sessionen
2. Projektspecifika regler i `CLAUDE.md` efter `@AGENTS.md`-importen
3. Projektets ramverksägda `AGENTS.md`
4. Skillens `SKILL.md`
5. Projektets `docs/`

En skill som motsäger projektets `CLAUDE.md` eller `AGENTS.md` ska anpassas, inte följas. Codex
läser `CLAUDE.md` därför att alla starters uttryckligen kräver det; Claude Code läser filen direkt
och importerar `AGENTS.md` via första raden.

---

*Clarity Framework v1.5.0*
