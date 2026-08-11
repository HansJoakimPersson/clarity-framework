# Skills – återanvändbara arbetsflöden för Claude Code

Den här katalogen innehåller färdiga skills att kopiera in i ett projekt när flödet behövs.

En kopierad skill **ägs av ramverket och redigeras inte i projektet** – den ersätts i sin helhet när
projektet uppdateras till en ny ramverksversion. Behöver flödet bete sig annorlunda i just ditt
projekt hör det hemma i projektets `CLAUDE.md`, som ramverket aldrig rör. Se ägarskapstabellen i
ramverkets `README.md`.

---

## Vad är en skill?

En skill är ett namngivet arbetsflöde som Claude Code kan anropa. Den skiljer sig från övriga
Clarity Framework-dokument i vad den svarar på:

| Dokument | Svarar på |
| --- | --- |
| `docs/00-ai-context.md` | Vad är projektet? |
| `AGENTS.md` | Hur ska agenten arbeta här, alltid? |
| `.claude/skills/*/SKILL.md` | Hur körs det här specifika flödet, när det körs? |

`AGENTS.md` gäller varje uppgift. En skill gäller bara när den anropas.

---

## Tillgängliga skills

| Katalog | Passar när... |
| --- | --- |
| `planstyrt-bygge/` | Uppgiften är stor nog att omfattningen behöver godkännas innan kod skrivs, och du vill att Claude Code orchestrerar medan planering, granskning och bygge dispatchas till andra CLI:er/konton |
| `ramverksuppdatering/` | Projektet ligger på en äldre version av ramverket och ska lyftas till senaste releasen utan att det som redan är ifyllt går förlorat |

De två är oberoende av varandra. `ramverksuppdatering/` dispatchar ingenting och har inget med
orkestrering att göra – den kör i din session och rör bara `docs/`, `AGENTS.md` och
`.claude/skills/`.

---

## Så använder du en

1. Kopiera katalogen till projektets `.claude/skills/`:

   ```bash
   cp -r skills/planstyrt-bygge /sökväg/till/projektet/.claude/skills/
   ```

2. Gå igenom `uppsattning.md` – profiler, sandbox- och approval-inställningar, permissionslista.
   Det är en engångsuppsättning per maskin och den som avgör om flödet kan köra obevakat.
3. Anropa den i Claude Code med `/planstyrt-bygge`.

Steg 2 rör din maskin, inte de kopierade filerna. Behöver projektet avvika från flödet skriver du
det i projektets `CLAUDE.md` – de kopierade filerna lämnas orörda så att de kan ersättas vid nästa
ramverksuppdatering.

### Vad filerna i `planstyrt-bygge/` gör

| Fil | Roll |
| --- | --- |
| `SKILL.md` | Proceduren. Det enda orchestratorn läser vid anrop – skriven för rollen, inte för ett visst CLI |
| `codex-orchestrator.md` | Frontend som låter Codex hålla orchestratorrollen. Kopieras till `~/.codex/prompts/`. Duplicerar inte flödet – pekar på `SKILL.md` och beskriver bara det som skiljer |
| `prompts/*.txt` | Instruktionerna till de dispatchade agenterna. Ligger i filer just för att hållas utanför orchestratorns kontext – orchestratorn fyller platshållare, den läser dem inte |
| `dispatch.sh` | Enda vägen till en dispatch. Sätter sandbox och approval tillsammans, upptäcker saknad kontoprofil, mäter rapportens storlek mot budgeten |
| `plan-mall.md` | Planmallen. Identisk kopia av ramverkets `templates/plan.md` – skillen kopieras ensam och måste bära sin egen |
| `journal-mall.md` | Körjournalmallen. Flödets tillstånd utanför orchestratorns kontext |
| `uppsattning.md` | Engångsuppsättning: profiler, permissions, gitignore |
| `settings.exempel.json` | Permissionslista för Claude Code. `deny`-halvan gör läsbudgeten till en regel istället för en uppmaning |

Skills versioneras i projektrepot som all annan dokumentation som kod.

---

## Vad som gäller före vad

Samma prioritetsordning som för `agents/`:

1. Uttrycklig instruktion från användaren i sessionen
2. Projektets `AGENTS.md`
3. Skillens `SKILL.md`
4. Projektets `docs/`

En skill som motsäger projektets `AGENTS.md` ska anpassas, inte följas.

---

*Clarity Framework v1.4.0*
