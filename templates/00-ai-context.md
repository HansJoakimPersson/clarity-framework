# AI Context Document

## [Produktnamn]

> **Syfte:** Komprimerad projektöversikt för ny AI-session eller ny teammedlem.  
> **Längd:** Max 1 sida. Korthet är en kvalitet, inte en brist.  
> **Uppdateras:** Vid fasändring, nytt ADR, ändrad NFR eller förändrad teknisk skuld.

| | |
| --- | --- |
| **Senast uppdaterad** | ÅÅÅÅ-MM-DD |
| **Ramverksversion** | Clarity Framework v1.1.0 |
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

## Var finns mer kontext?

| Fråga | Dokument |
| --- | --- |
| Varför byggs det? | `docs/01-vision-scope.md` |
| Vad ska byggas? | `docs/02-kravdokumentation.md` |
| Hur är det byggt? | `docs/03-sad.md` |
| Datastruktur & API? | `docs/04-datamodell-api.md` |
| Hur driftsätts det? | `docs/05-deployment-view.md` |
| Hur testas det? | `docs/06-testdokumentation.md` |
| Hur driftas det? | `docs/07-runbook.md` |

---

*Clarity Framework v1.1.0 – AI Context Document*
