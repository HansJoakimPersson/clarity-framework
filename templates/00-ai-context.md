# AI Context Document

## [Produktnamn]

> **Syfte:** Komprimerad projektöversikt för ny AI-session eller ny teammedlem.  
> **Längd:** Max 1 sida. Korthet är en kvalitet, inte en brist.  
> **Uppdateras:** Vid fasändring, nytt ADR, ändrad NFR eller förändrad teknisk skuld.

| | |
| --- | --- |
| **Senast uppdaterad** | ÅÅÅÅ-MM-DD |
| **Ramverksversion** | Clarity Framework v1.4.0 |
| **Projektfas** | Initiering / Krav / Design / Implementation / Drift |

---

## Vad är detta?

[2–3 meningar. Vad produkten gör, vilket problem den löser och för vem. Ska kunna läsas av en AI och ge omedelbar förståelse utan ytterligare kontext.]

---

## Teknisk stack

| Komponent | Teknologi | Version |
| --- | --- | --- |
| Backend | [t.ex. Spring Boot] | [X.X] |
| Frontend | [t.ex. React] | [X.X] |
| Databas | [t.ex. PostgreSQL] | [X.X] |
| Hosting | [t.ex. Hetzner VPS / AWS] | — |
| CI/CD | [t.ex. GitHub Actions] | — |

---

## Arkitektur i korthet

[3–5 meningar om arkitekturmönster och de viktigaste komponenterna och deras ansvar. Tillräckligt för att en AI ska kunna fatta lokala designbeslut i linje med helheten.]

---

## Viktigaste NFR

| NFR | Krav |
| --- | --- |
| Prestanda | [t.ex. Svarstid < 300 ms, p95] |
| Tillgänglighet | [t.ex. 99.5% uptime] |
| Skalbarhet | [t.ex. Ska hantera 10x datatillväxt utan omdesign] |
| [Övrig kritisk NFR] | [Konkret krav] |

---

## Aktuell status

**Pågående arbete:** [Vad som är aktivt just nu – t.ex. "Implementerar FR-005 till FR-009"]  
**Senaste release:** [Version och datum, eller "Ej releasad"]  
**Nästa milstolpe:** [t.ex. "MVP-release v0.1 – target ÅÅÅÅ-MM-DD"]

---

## Öppna frågor och beslut

[Lista med arkitekturella eller produktmässiga frågor som ännu inte är avgjorda. Hjälper AI:n att förstå var osäkerhet finns och undvika att ta dessa beslut implicit.]

- [ ] [Öppen fråga 1]
- [ ] [Öppen fråga 2]

---

## Känd teknisk skuld

| ID | Beskrivning | Påverkan |
| --- | --- | --- |
| TD-001 | [Kort beskrivning] | Hög / Medel / Låg |

---

## Viktiga avgränsningar

[Vad som medvetet exkluderats från produkten. Förhindrar att AI föreslår lösningar utanför scope.]

- [Out-of-scope 1]
- [Out-of-scope 2]

---

## AI-arbetsflöde

[Utelämna hela avsnittet om projektet inte delar upp arbetet mellan flera agenter.]

Det här avsnittet är projektets **runtime-kontrakt**: det säger vilken agent som fyller vilken nivå
och under vilket konto och vilka rättigheter den körs. Det är den enda platsen den informationen
finns – en skill eller ett skript ska kunna bytas ut utan att flödet definieras om.

| Nivå | Agent / profil | Sandbox + approval | Ansvar |
| --- | --- | --- | --- |
| Orchestrator | [t.ex. Claude Code] | [t.ex. allowlist i `.claude/settings.json`] | Sekvenserar, äger grindarna, för körjournal. Läser inte kodbas eller diff själv. |
| Reasoning | [t.ex. Codex, profil `reasoning`] | `read-only` + approval `never` | Skriver plan till `docs/plans/`, granskar diff mot plan. Bygger inte, godkänner inte sitt eget arbete. Annat CLI/konto än Orchestrator. |
| Granskning *(valfri)* | [t.ex. Codex, profil `granskning`] | `read-only` + approval `never` | Granskar planen kallt mot koden. Annat konto än Reasoning – annars granskar en nivå sig själv. |
| Implementation | [t.ex. Codex, profil `implementation`] | `workspace-write` + approval `never` | Bygger enligt planen. Planerar inte om – stannar vid blockerande fråga. |

> Sandbox och approval är två oberoende inställningar. Sätts bara sandbox ligger approval kvar på
> default, och då stannar en obevakad körning och frågar. Sätt alltid båda.

**Planer:** `docs/plans/ÅÅÅÅ-MM-DD-kort-namn.md` (mall: ramverkets `templates/plan.md`). Planen måste vara committad och pushad för att en molnagent ska kunna läsa den. Raderas när ändringen är mergad.

**Körjournal:** `docs/plans/ÅÅÅÅ-MM-DD-kort-namn.run.md` – flödets tillstånd utanför orchestratorns kontext: vilket steg som är klart, vad som väntar, var rapporterna ligger. Committas med planen. Det är den som gör att en avbruten körning kan tas över av en annan session eller ett annat CLI. Råutdata i `docs/plans/.runs/` är lokalt och gitignorerat.

**Orchestratorbudget:** [Vad orchestratorn får läsa per runda – t.ex. "plan + kritik ≤ 40 rader + verifiering ≤ DoD + 10 rader". Läser den kodbasen eller diffen är kostnadsfördelningen skenbar.]

**Kräver alltid människa:** [t.ex. godkännande av omfattning, merge, releasebeslut, radering av plan]

---

## Var finns mer kontext?

| Fråga | Dokument |
| --- | --- |
| Varför byggs det? | `docs/01-vision-scope.md` |
| Vad ska byggas? | `docs/02-kravdokumentation.md` |
| Hur ska det se ut? (om UI) | `docs/09-grafisk-profil.md` |
| Hur är det byggt? | `docs/03-sad.md` |
| Datastruktur & API? | `docs/04-datamodell-api.md` |
| Hur driftsätts det? | `docs/05-deployment-view.md` |
| Hur testas det? | `docs/06-testdokumentation.md` |
| Hur driftas det? | `docs/07-runbook.md` |
| Vad byggs just nu, konkret? | `docs/plans/` (om planstyrt arbetsflöde används) |

---

*Clarity Framework v1.4.0 – AI Context Document*
