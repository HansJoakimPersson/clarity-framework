# Testdokumentation

## [Produktnamn]

| | |
| --- | --- |
| **Version** | 0.1 |
| **Status** | Aktiv |
| **Datum** | ÅÅÅÅ-MM-DD |
| **Författare** | [Namn] |
| **Kopplad till** | Kravdokumentation v[X.X] |

### Versionshistorik

| Version | Datum | Förändring | Författare |
| --- | --- | --- | --- |
| 0.1 | ÅÅÅÅ-MM-DD | Initial version | [Namn] |

---

## 1. Teststrategi

### Mål

Teststrategin syftar till att:

- Ge förtroende för att acceptanskriterierna är uppfyllda
- Säkerställa att regressioner fångas automatiskt
- Ge snabb feedback under development (< [X] sekunder för enhetstester)

### Testpyramid

```text
           /\
          /  \       E2E-tester
         / E2E\      Få, långsamma – täcker kritiska användarflöden
        /------\
       /        \    Integrationstester
      / Integ.   \   Komponentinteraktion, databas, externa beroenden
     /------------\
    /              \  Enhetstester
   / Unit           \ Många, snabba – isolerad affärslogik
  /------------------\
```

### Ansvarsfördelning

| Testtyp | Vem skriver | Vem kör | Automatiserat |
| --- | --- | --- | --- |
| Enhetstest | Utvecklare | CI vid varje push | Ja |
| Integrationstest | Utvecklare | CI vid merge till main | Ja |
| API-test | Utvecklare | CI vid merge till main | Ja |
| E2E-test | [Utvecklare / QA] | CI nightly + inför release | Ja |
| Explorativ test | [Namn / QA] | Inför release | Nej |

---

## 2. Testtyper och verktyg

| Testtyp | Verktyg | Plats i repo | Täckningsmål |
| --- | --- | --- | --- |
| Enhetstest | [JUnit 5 + Mockito / Jest / pytest] | `/src/test/unit` | [X]% instruktioner |
| Integrationstest | [Spring Boot Test + Testcontainers] | `/src/test/integration` | Kritiska flöden |
| API-test | [REST Assured / Postman/Newman] | `/src/test/api` | Alla endpoints |
| E2E-test | [Playwright / Cypress] | `/e2e` | [X] kritiska use cases |

**OBS om täckningsmål:** Procentsats är ett mått, inte ett mål. Fokusera på att testa rätt saker, inte på att maximera täckning.

---

## 3. Definition of Done (DoD)

> En story eller feature är **Done** när samtliga punkter nedan är uppfyllda.

```text
KODKVALITET
☐ Koden är granskad (code review) och godkänd
☐ Inga nya linting-varningar / kompileringsfel
☐ Ingen uppenbar teknisk skuld utan dokumenterat ADR

TESTER
☐ Enhetstester är skrivna för ny affärslogik och passerar
☐ Integrationstester passerar i CI
☐ Alla acceptanskriterier för storyn är verifierade
☐ Testtäckning understiger inte satt miniminivå

DOKUMENTATION
☐ SAD är uppdaterad om arkitekturella förändringar gjorts
☐ API-kontrakt är uppdaterat om endpoints lagts till / ändrats
☐ Datamodell är uppdaterad om schemaförändringar gjorts

DEPLOYMENT
☐ Feature fungerar i staging-miljö
☐ Smoke test passerar i staging
```

---

## 4. Testfall kopplade till krav

> Varje acceptanskriterium ska ha ett motsvarande testfall.  
> Format: `TC-[story-ID]-[löpnummer]`

### TC-001 · FR-001 – [Storytitel]

**Koppling:** AC-001-1  
**Typ:** Enhetstest / Integrationstest / E2E  
**Prioritet:** Kritisk / Hög / Normal

**Förutsättningar:**  
[Vad måste vara sant innan testet körs? Testdata, systeminställningar.]

**Teststeg:**

1. [Steg 1]
2. [Steg 2]
3. [Steg 3]

**Förväntat utfall:**  
[Exakt vad som ska ha hänt efter att stegen körts]

**Automatiserat:** Ja / Nej  
**Placering i repo:** `[filsökväg]`

---

### TC-001-2 · FR-001 – [Felfall / alternativt scenario]

**Koppling:** AC-001-2  
**Typ:** Enhetstest  

**Förutsättningar:**  
[...]

**Teststeg:**

1. [...]

**Förväntat utfall:**  
[...]

---

### TC-NFR-P01 · NFR-P01 – Prestanda svarstid

**Koppling:** NFR-P01  
**Typ:** Lasttest / Prestandatest  
**Verktyg:** [k6 / JMeter / Gatling]

**Testscenario:**  
[X] virtuella användare kör [specificerat flöde] simultant i [Y] minuter.

**Acceptansgräns:**  

- 95th percentile svarstid < [X] ms
- Inga 5xx-fel under testkörningen

---

## 5. Testdata

### Strategi

- [ ] Testdata genereras via fixtures/factories i koden
- [ ] Testmiljön återställs till känd state innan varje testkörning
- [ ] Ingen produktionsdata används i tester

### Testdatakatalog

| Dataset | Syfte | Plats |
| --- | --- | --- |
| `test-users.sql` | 5 användare med olika roller | `/src/test/resources/data/` |
| `test-recipes.sql` | 20 recept i olika kategorier | `/src/test/resources/data/` |
| `empty-state.sql` | Tom databas för edge case-tester | `/src/test/resources/data/` |

---

## 6. Känd testproblematik och undantag

> Dokumentera tester som medvetet hoppas över eller är kända falska negativa.

| ID | Beskrivning | Orsak | Planerad åtgärd |
| --- | --- | --- | --- |
| SKIP-001 | [Test som skippas] | [Varför] | [Version / datum] |

---

*Nästa steg: Producera Runbook när systemet är klart för sin första deployment till staging.*
