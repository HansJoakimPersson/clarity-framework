# Den ultimata guiden till mjukvarudokumentation

## Clarity Framework v1.1.0

### Kravställning · Utveckling · Drift · Produktion

> **Målgrupp:** Alla skalor – från en ensam utvecklare med ett sidoprojekt till ett team på 20. Ramverket skalas med projektet.  
> **Metodik:** Metodagnostisk – principerna gäller oavsett om du kör Scrum, Kanban, vibe coding eller ad hoc  
> **Filosofi:** *Just enough documentation* – varje dokument ska tillföra värde, inte skapa byråkrati  
> **AI-assistans:** Ett valfritt accelerationslager. Ramverket fungerar fullt ut med eller utan AI.

---

## Innehållsförteckning

1. [Dokumenthierarki och livscykel](#1-dokumenthierarki-och-livscykel)
2. [Vision & Scope](#2-vision--scope)
3. [Kravdokumentation](#3-kravdokumentation)
4. [System Architecture Document (SAD)](#4-system-architecture-document-sad)
5. [Datamodell & API-kontrakt](#5-datamodell--api-kontrakt)
6. [Driftsättningsvy (Deployment View)](#6-driftsättningsvy-deployment-view)
7. [Testdokumentation](#7-testdokumentation)
8. [Driftdokumentation (Runbook)](#8-driftdokumentation-runbook)
9. [Ändringshantering och versionshistorik](#9-ändringshantering-och-versionshistorik)
10. [Grafisk profil & Design Tokens](#10-grafisk-profil--design-tokens)
11. [Dokumentationsprocess – hur produceras vad och när](#11-dokumentationsprocess--hur-produceras-vad-och-när)
12. [AI-assistans – valfritt accelerationslager](#12-ai-assistans--valfritt-accelerationslager)

---

## 1. Dokumenthierarki och livscykel

### Varför en hierarki?

Dokument tjänar olika syften i produktens livscykel. Att förstå vilket dokument som svarar på vilken fråga förhindrar att information dupliceras, motsäger sig själv eller hamnar på fel ställe.

```text
PROJEKTKONTEXT (valfritt AI-lager)
└── AI Context Document (00-ai-context.md)

VARFÖR bygger vi det?
└── Vision & Scope

VAD ska byggas?
└── Kravdokumentation (funktionella krav + NFR)

HUR ska det se ut? (obligatorisk om projektet har UI)
└── Grafisk profil & Design Tokens

HUR är det byggt?
├── System Architecture Document (SAD)
├── Datamodell & API-kontrakt
└── Driftsättningsvy

HUR verifieras det?
└── Testdokumentation

HUR driftas och underhålls det?
└── Driftdokumentation (Runbook)
```

### Skalning efter projektstorlek

Clarity Framework skalas med projektet. Använd det som passar – hoppa inte över Vision & Scope, men anpassa detaljnivån efter behov.

| Projektstorlek | Minsta dokumentationsuppsättning | Valfritt |
| --- | --- | --- |
| **Personligt projekt / hobby** | Vision & Scope, README, AI Context | Övriga dokument vid behov |
| **Sidoprojekt med lansering** | + Kravdokumentation, SAD (förenklad) | Deployment View, Runbook |
| **Litet team (2–5 pers)** | Alla 8 kärnmallar | AI Usage Guide |
| **Större team (5–20 pers)** | Alla 8 kärnmallar + striktare DoD | Formell releaseprocess |

### Dokumentens karaktär

| Dokument | Karaktär | Uppdateras |
| --- | --- | --- |
| Vision & Scope | Strategisk snapshot | Vid större pivotar |
| Kravdokumentation | Levande backlog | Kontinuerligt |
| Grafisk profil & Design Tokens | Levande visuell standard (UI-projekt) | Vid varumärkes- eller tokenändringar |
| SAD | Levande arkitektur | Vid designbeslut |
| Datamodell & API | Levande kontrakt | Vid schemaändringar |
| Deployment View | Levande infrastruktur | Vid infrastrukturförändringar |
| Testdokumentation | Levande testsuite | Vid varje feature/buggfix |
| Runbook | Operationell referens | Vid drifthändelser och releaser |

### Förvaring och versionshantering

- Alla dokument versioneras i samma Git-repo som koden, under `/docs`
- Dokumentnamn följer mönstret `[typ]-[produktnamn].md`, t.ex. `sad-investezy.md`
- Bilder och diagram lagras i `/docs/assets`
- Använd Pull Requests för att granska dokumentändringar på samma sätt som kodändringar

---

## 2. Vision & Scope

### Syfte

Vision & Scope är produktens konstitution. Det svarar på *varför* produkten existerar och sätter gränser för vad som är inom och utanför scope. Dokumentet riktar sig till intressenter, produktägare och nya teammedlemmar.

### När produceras det?

Innan något annat skrivs. Inga krav, ingen arkitektur – utan ett godkänt Vision & Scope-dokument.

### Vad ska det innehålla?

**Produktvision (1–3 meningar)**  
En enkel, inspirerande beskrivning av vad produkten är och vilket problem den löser. Ska kunna läsas av en icke-teknisk person.

**Problembeskrivning**  

- Vilket problem löses?
- Vem har problemet?
- Vad är konsekvensen av att problemet inte löses?

**Målgrupp och intressenter**  

- Primär användare (den som faktiskt använder systemet)
- Sekundär användare / intressenter (den som berörs av resultatet)
- Teknisk operatör (den som driftar)

**Mål och framgångskriterier**  
Konkreta, mätbara mål. Undvik vaga formuleringar som "systemet ska vara snabbt". Skriv istället: "Svarstiden för sökning ska understiga 300 ms vid normal belastning."

**Scope – In och Out**  
En explicit lista över vad som ingår respektive inte ingår i produkten. Out-of-scope är lika viktigt som in-scope – det förhindrar scope creep.

| In scope | Out of scope |
| --- | --- |
| Användarregistrering och login | SSO / SAML-integration |
| Recepthantering | Nutritionsberäkning |

**Antaganden och beroenden**  
Vad tas för givet? Vilka externa system eller beslut är produkten beroende av?

**Kända risker och begränsningar**  
Tidigt identifierade risker som kan påverka leverans eller design.

### Kvalitetskriterier

- Dokumentet ska rymmas på 1–2 sidor
- Alla intressenter ska ha läst och godkänt det (signatur eller dokumenterad bekräftelse)
- Det ska inte innehålla tekniska implementationsdetaljer

### Hur produceras det?

1. Håll ett kick-off-möte med alla intressenter
2. Författa ett utkast baserat på mötet
3. Cirkulera för kommentarer och justera
4. Formellt godkännande innan kravarbetet startar

---

## 3. Kravdokumentation

### Syfte

Kravdokumentationen fångar *vad* systemet ska göra och under vilka villkor. Den är bryggan mellan Vision & Scope och det faktiska designarbetet. Dokumentet ägs av produktägaren men produceras tillsammans med teamet.

### Kravtyper

**Funktionella krav**  
Beskriver beteenden och funktioner – vad systemet ska *göra*.

**Icke-funktionella krav (NFR)**  
Beskriver systemets egenskaper – hur systemet ska *vara*. NFR är ofta mer avgörande för arkitekturen än de funktionella kraven och måste fångas tidigt.

Viktiga NFR-kategorier:

- **Prestanda** – svarstider, genomströmning, concurrency
- **Tillgänglighet** – SLA, planerat underhållsfönster
- **Skalbarhet** – förväntad tillväxt i data och användare
- **Underhållbarhet** – kodbas, loggning, felsökning
- **Portabilitet** – plattformskrav, browserkompatibilitet
- **Säkerhet** – autentisering, auktorisering, dataskydd (även om compliance hålls utanför)

### Format för funktionella krav

#### User Stories (rekommenderas för produktorienterad mjukvara)

```text
Som [roll]
vill jag [funktion/möjlighet]
så att [affärsnytta/värde]
```

Varje story kompletteras med **acceptanskriterier** i Given/When/Then-format:

```text
Givet att [förutsättning]
När [händelse/åtgärd]
Så ska [förväntat utfall]
```

**Exempel:**

```text
Story: Som inloggad användare vill jag kunna spara ett recept till min veckoplan
så att jag snabbt kan bygga en komplett matsedel.

Acceptanskriterium 1:
  Givet att användaren är inloggad och tittar på ett recept
  När användaren klickar "Lägg till i veckoplan" och väljer en dag
  Så ska receptet visas i veckoplanen för den valda dagen

Acceptanskriterium 2:
  Givet att en dag redan har tre recept
  När användaren försöker lägga till ett fjärde
  Så ska systemet visa ett varningsmeddelande (ej blockera)
```

#### Use Cases (rekommenderas för systemintegration och komplexa flöden)

Används när interaktionen involverar flera system eller aktörer, eller när ett flöde har många alternativa sceenarios.

Struktur:

- **ID och titel**
- **Primär aktör**
- **Förutsättningar**
- **Normflöde** (steg-för-steg)
- **Alternativa flöden** (felfall, undantag)
- **Eftervillkor**

### Prioritering – MoSCoW

Varje krav tilldelas en prioritet:

| Nivå | Beskrivning |
| --- | --- |
| **M** – Must have | Kritiskt för MVP. Utan detta levereras inte produkten. |
| **S** – Should have | Viktig funktion men workarounds finns. |
| **C** – Could have | Önskvärd om tid finns. |
| **W** – Won't have (this time) | Medvetet exkluderat nu, möjligt i framtida iteration. |

### Kravhygien

- Varje krav ska ha ett unikt ID (t.ex. `FR-012`, `NFR-003`)
- Krav ska vara **testbara** – om du inte kan skriva ett acceptanskriterium är kravet för vagt
- Undvik ord som "snabbt", "enkelt", "intuitivt" utan kvantifiering
- Krav ska vara **atomära** – ett krav, ett syfte
- Spåra krav till SAD-komponenter och testfall (traceability)

### Metoder för kravfångst

**Intervjuer**  
Prata med faktiska användare och intressenter. Ställ öppna frågor. Undvik att föreslå lösningar under intervjun.

**Observation / Contextual Inquiry**  
Observera hur användaren löser problemet idag (manuellt, med befintliga verktyg). Avslöjar implicita krav som aldrig skulle uttryckas i en intervju.

**Story Mapping**  
Lägg ut user stories längs en horisontell "användarresa". Dela sedan in dem vertikalt i releaser. Ger en visuell bild av MVP vs. future releases.

**Prototyping**  
Skapa enkla wireframes eller klickbara mockups för att validera förståelsen av krav innan implementation börjar. Billigaste sättet att hitta missförstånd.

**Event Storming (för domänkomplexitet)**  
Workshop-format där man identifierar domänhändelser, kommandon och aggregat. Passar system med komplex affärslogik.

### Hur produceras det?

1. Genomför kravfångst (intervjuer, observationer, workshops)
2. Formulera stories/use cases med acceptanskriterier
3. Fånga NFR explicit i ett separat avsnitt
4. Prioritera med MoSCoW
5. Granska tillsammans med intressenter – justiera och godkänn
6. Underhåll kravdokumentet löpande som en prioriterad backlog

---

## 4. System Architecture Document (SAD)

### Syfte

SAD dokumenterar de arkitekturella besluten – *hur* systemet är uppbyggt och *varför* det är uppbyggt på det sättet. Dokumentet riktar sig till utvecklare, tekniska granskare och framtida underhållare.

Ett SAD är inte en detaljerad teknisk specifikation av varje klass eller funktion. Det beskriver systemet på en nivå där en ny utvecklare kan förstå helheten och fatta lokala beslut i linje med den övergripande designen.

### När produceras det?

Initialt utkast skapas parallellt med de tidiga kraven, innan implementation börjar. Uppdateras löpande när arkitekturella beslut fattas.

### Vad ska det innehålla?

#### 4.1 Arkitekturöversikt

En kort (½–1 sida) sammanfattning av systemets övergripande struktur. Ska kunna läsas fristående.

- Vilket arkitekturmönster används? (t.ex. monolitisk MVC, layered architecture, microservices, event-driven)
- Vilka är de primära teknologierna och varför valdes de?
- Vilka är systemets viktigaste kvalitetsattribut (t.ex. underhållbarhet framför prestanda)?

#### 4.2 Kontextvy (Context View)

Ett diagram som visar systemet som en svart låda och dess relationer till externa aktörer och system.

```text
[Extern aktör / Användare]
        ↓
  [Ditt system]
        ↓
[Externt system / Databas / API]
```

Verktyg: C4 Model (Context-nivå), draw.io, Mermaid.

#### 4.3 Komponentvy (Component View)

Visar systemets interna uppdelning i moduler, tjänster eller lager och hur de kommunicerar.

- Rita varje komponent som en namngiven låda
- Visa beroenden med pilar (riktning = beroenderiktning, inte dataflöde)
- Inkludera en kort beskrivning av varje komponents ansvar

**Anti-pattern att undvika:** "Spaghetti-diagram" där alla komponenter pekar på alla. Om det ser ut så är det ett tecken på att arkitekturen behöver ses över, inte att diagrammet är fel.

#### 4.4 Dataflödesvy

Visar hur data flödar genom systemet för de viktigaste use cases. Behövs inte för alla flöden – välj de 2–3 mest centrala.

#### 4.5 Teknologival

En tabell eller lista med de viktigaste teknologivalen och motivering:

| Komponent | Teknologi | Motivering |
| --- | --- | --- |
| Backend | Java / Spring Boot | Teamkompetens, ekosystem |
| Frontend | React + Tailwind | Komponentbaserat, snabb styling |
| Databas | PostgreSQL | Relationell data, ACID, open source |
| Autentisering | JWT + OAuth2 | Stateless, standardiserat |

**Viktigt:** Dokumentera alternativ som *övervägdes men valdes bort* och varför. Detta sparar tid vid framtida diskussioner.

#### 4.6 Arkitekturella beslut (ADR – Architecture Decision Records)

Varje betydande arkitekturellt beslut dokumenteras som ett kort ADR:

```text
ADR-001: Val av databastyp
Status: Godkänd
Datum: 2025-01-15

Kontext:
Systemet behöver lagra strukturerad data med komplexa relationer
mellan recept, ingredienser och veckoplaner.

Beslut:
Vi väljer PostgreSQL som primär databas.

Konsekvenser:
+ Stöd för komplexa JOIN-queries
+ Starka ACID-garantier
- Kräver schemamigrationer vid förändring
- Mer rigid än dokumentdatabas för ostrukturerad data

Alternativ som övervägdes:
- MongoDB (valdes bort – relationsstrukturen är central)
- SQLite (valdes bort – skalbarhet vid fler samtidiga skrivningar)
```

#### 4.7 Kvalitetsattribut och arkitekturella taktiker

Koppla NFR:erna från kravdokumentet till konkreta arkitekturlösningar:

| NFR | Taktik |
| --- | --- |
| Svarstid < 300 ms | Caching av ofta lästa recept, indexering av databas |
| Tillgänglighet 99.5% | Hälsokontroll-endpoint, automatisk omstart via Docker |
| Underhållbarhet | Tydlig lagerarkitektur, DI-container, loggning på rätt nivå |

### Kvalitetskriterier

- En ny teammedlem ska kunna läsa SAD:en och förstå systemet utan att ställa grundläggande frågor
- Varje diagram ska ha en förklarande text – diagram utan text är otillräckliga
- SAD:en ska inte innehålla kodsnuttar (det hör hemma i kodkommentarer eller separat teknisk spec)
- Alla ADR:er ska ha status: Föreslagen / Under granskning / Godkänd / Föråldrad

### Hur produceras det?

1. Skissa arkitekturen i ett whiteboard-möte (fysiskt eller digitalt)
2. Fatta och dokumentera de viktigaste besluten som ADR:er
3. Rita kontextvy och komponentvy
4. Dokumentera teknologival med motivering
5. Granska SAD mot kraven – täcker arkitekturen alla NFR?
6. Uppdatera vid varje större arkitekturellt beslut under projektet

---

## 5. Datamodell & API-kontrakt

### Syfte

Dokumenterar strukturen på data och kontrakten för kommunikation. Kritiskt för att undvika missförstånd mellan frontend/backend, eller mellan ditt system och externa integrationer.

### Vad ska det innehålla?

#### 5.1 Domänmodell / Konceptuell datamodell

Ett diagram som visar domänens entiteter och deras relationer på en begriplig nivå – utan databastekniska detaljer.

- Entiteter (substantiv i domänen): Recept, Ingrediens, Veckoplan, Användare
- Relationer: "En veckoplan innehåller många recept"
- Kardinalitet: 1:1, 1:N, M:N

#### 5.2 Fysisk datamodell / Databasschema

Det faktiska databasschema med tabeller, kolumner, datatyper, primary keys, foreign keys och index.

Dokumenteras antingen som:

- SQL DDL-skript (alltid källkontrollerat)
- ER-diagram genererat från faktisk databas (t.ex. via DBeaver, dbdiagram.io)

**Migrationsstrategi:** Beskriv hur schemaförändringar hanteras (t.ex. Flyway, Liquibase, manuella script).

#### 5.3 API-kontrakt

Alla externa och interna API:er dokumenteras med:

- **Endpoint:** `GET /api/v1/recipes/{id}`
- **Beskrivning:** Hämtar ett recept med givet ID
- **Autentisering:** Bearer token krävs
- **Request-parametrar:** Tabell med namn, typ, obligatorisk/valfri, beskrivning
- **Request body:** JSON-schema eller exempel
- **Response:** HTTP-statuskoder med body-exempel för varje fall (200, 400, 401, 404, 500)
- **Sidoeffekter:** Vad förändras i systemet?

**Verktyg:** OpenAPI/Swagger (genereras helst från kod med annotationer). Swagger UI ger automatisk interaktiv dokumentation.

**API-versionshantering:** Dokumentera strategin – URL-versionshantering (`/v1/`, `/v2/`) eller header-baserad.

### Kvalitetskriterier

- Domänmodellen ska vara förståelig för en icke-teknisk person
- API-kontraktet ska vara tillräckligt detaljerat för att en frontend-utvecklare ska kunna integrera utan att fråga om detaljer
- Alla felkoder ska vara dokumenterade med tydliga felmeddelanden
- Schema-filer ska versioneras i Git

### Hur produceras det?

1. Börja med domänmodellen direkt från kravarbetet – entiteterna framgår av user stories
2. Förfina till fysisk datamodell under design-fasen
3. Definiera API-kontrakt *innan* implementation (contract-first approach)
4. Generera Swagger/OpenAPI från koden och validera mot det definierade kontraktet
5. Uppdatera vid varje schema- eller API-förändring

---

## 6. Driftsättningsvy (Deployment View)

### Syfte

Beskriver hur systemet driftsätts i olika miljöer – vilken infrastruktur som används, hur komponenter körs och hur kod når produktion. Riktar sig till den som ansvarar för drift och CI/CD.

### Miljöer

Definiera alltid miljöer explicit och dokumentera vad som skiljer dem åt:

| Miljö | Syfte | Uppdateras |
| --- | --- | --- |
| **Lokal (dev)** | Individuell utveckling | Av varje utvecklare |
| **Test/Staging** | Integration och QA | Vid varje merge till main |
| **Produktion** | Skarp drift | Vid godkänd release |

### Vad ska det innehålla?

#### 6.1 Infrastrukturdiagram

Visar fysisk/virtuell infrastruktur – servrar, containers, moln, nätverksgränser.

- Applikationsserver(ar)
- Databas(er) – primär, eventuell replica
- Reverse proxy / load balancer (t.ex. Nginx, Traefik)
- Externta beroenden (API:er, tjänster)
- Nätverkszoner (om relevant)

#### 6.2 Container- och orkestreringsmodell

Om Docker används:

- `docker-compose.yml` eller Kubernetes-manifests versioneras i repo
- Beskriv vilka images som används och varifrån de hämtas
- Dokumentera volymer, nätverk och port-mapping

#### 6.3 CI/CD-pipeline

Beskriv hela flödet från lokal förändring till publicerad release. Dokumentationen ska skilja på
repository-arbetsflöde, verifiering och release/publicering.

**Repository-arbetsflöde**

- Ange branchstrategi, namnkonvention och om direkt push till `main` är tillåten
- Använd kortlivade branches och pull requests som normalflöde; avvikelser för soloprojekt dokumenteras explicit
- Håll commits atomiska och skriv commitmeddelanden i imperativ form
- Pusha inte kod som innehåller hemligheter, lokala konfigurationsfiler eller genererade artefakter som inte ska versioneras
- Definiera vilka statuskontroller och godkännanden som krävs innan merge
- Dokumentation, tester och implementation som hör till samma förändring ingår i samma pull request

**Verifieringsflöde**

```text
Lokal commit → Push till branch → Pull request
             → Bygg → Enhetstester → Integrationstester
             → Statisk kodanalys → Granskning → Merge till main
             → Deploy till staging → Smoke test
```

- Vilket CI/CD-verktyg används? (GitHub Actions, GitLab CI, Jenkins)
- Vilka workflow-filer ansvarar för CI, release och deployment?
- Vilka händelser triggar dem (`pull_request`, push till `main`, versionstagg eller manuell körning)?
- Vilka steg är automatiska respektive manuellt godkända?
- Vilka behörigheter, secrets, environments och branch protection-regler krävs?
- Hur undviks att samma commit byggs på olika sätt i staging och produktion?

**Releaseflöde**

En produktionsrelease ska utgå från en identifierbar commit och skapa reproducerbara, spårbara artefakter:

```text
Godkänd commit på main → Version fastställs → Annoterad Git-tagg
                       → Release-workflow verifierar byggd artefakt
                       → Samma oföränderliga artefakt publiceras
                       → GitHub Release med releasenoter skapas
                       → Deploy till produktion → Smoke test
```

- Dokumentera versionsstrategi, normalt Semantic Versioning, och vem som beslutar versionsnumret
- Ange om releasen triggas av versionstagg eller `workflow_dispatch`; merge till `main` bör inte ensam skapa en produktionsrelease
- Bygg artefakten en gång och främja samma checksummeidentifierade artefakt mellan miljöer
- Git-taggen, GitHub-releasen, container-imagen och deploymenten ska kunna kopplas till samma commit och version
- Releasen ska inte betraktas som klar förrän releasenoter, deploymentresultat och eventuell rollback är dokumenterade
- Hur hanteras rollback?

#### 6.4 Konfigurationshantering

- Hur hanteras miljöspecifik konfiguration? (environment variables, config-filer, secrets manager)
- Vad lagras i repo vs. utanför repo? (Aldrig plaintext-hemligheter i Git)
- Namnkonvention för environment variables

#### 6.5 Övervaknings- och loggningsstrategi

- **Loggning:** Format (strukturerad JSON rekommenderas), nivåer (DEBUG/INFO/WARN/ERROR), destination (fil, stdout, aggregeringstjänst)
- **Hälsokontroll:** `/health`-endpoint – vad kontrolleras?
- **Alerting:** Vad triggar en avisering och till vem?
- **Metrics:** CPU, minne, diskutrymme, applikationsspecifika mätvärden

### Kvalitetskriterier

- En ny teammedlem ska kunna sätta upp en lokal miljö enbart baserat på Deployment View + README
- CI/CD-pipelinen ska vara definierad som kod (inte klick-konfigurerat i UI)
- Repository-, CI- och releaseflöden ska ha namngivna triggers, ansvariga workflow-filer och skyddsregler
- Varje produktionsrelease ska vara spårbar från GitHub Release till tagg, commit, byggartefakt och deployment
- Inga hemligheter i klartext i dokumentation eller repo

### Hur produceras det?

1. Designa infrastrukturen parallellt med SAD
2. Dokumentera miljöer och konfigurationer innan första deployment
3. Automatisera CI/CD-pipeline och dokumentera den i samma pull request som konfigurationsfilerna
4. Uppdatera vid varje infrastrukturförändring

---

## 7. Testdokumentation

### Syfte

Testdokumentation säkerställer att systemet beter sig som förväntat och ger förtroende för förändringar. För ett litet team är det viktigaste inte ett formellt testdokument utan en tydlig teststrategi och automatiserade tester nära koden.

### Teststrategi

Definiera tidigt:

- Vilka testtyper används?
- Vad är täckningsmålet (om kvantitativt mål används)?
- Vad testas manuellt vs. automatiskt?

**Testpyramiden som riktlinje:**

```text
        /\
       /  \    E2E-tester (få, långsamma, dyra)
      /----\
     /      \  Integrationstester (måttligt antal)
    /--------\
   /          \ Enhetstester (många, snabba, billiga)
```

### Vad ska det innehålla?

#### 7.1 Testtyper och ansvar

| Testtyp | Syfte | Verktyg (exempel) | Automatiserat |
| --- | --- | --- | --- |
| Enhetstest | Isolerad affärslogik | JUnit, pytest, Jest | Ja – CI |
| Integrationstest | Komponentinteraktion, databas | Spring Boot Test, Testcontainers | Ja – CI |
| API-test | Kontraktvalidering | REST Assured, Postman/Newman | Ja – CI |
| E2E-test | Kritiska användarflöden | Playwright, Cypress | Ja – Nightly |
| Manuell explorativ test | Nya features, edge cases | — | Nej |

#### 7.2 Testfall kopplade till krav

Varje acceptanskriterium i kravdokumentationen ska ha ett motsvarande automatiserat eller manuellt testfall. Traceability: `AC-012 → TC-012`.

#### 7.3 Testdata och miljö

- Hur genereras testdata? (fixtures, factories, anonymiserad produktionsdata)
- Är testmiljön isolerad från produktion?
- Hur återställs testmiljön mellan körningar?

#### 7.4 Definition of Done (DoD)

Definiera explicit vad som krävs för att ett krav ska anses klart:

```text
En story är klar (Done) när:
✓ Koden är granskad och mergad till main
✓ Enhetstester är skrivna och passerar
✓ Integrationstester passerar i CI
✓ Acceptanskriterier är verifierade (automatiserat eller manuellt)
✓ Ingen ny teknisk skuld är introducerad utan dokumentation
✓ SAD/datamodell är uppdaterad om arkitekturella förändringar gjorts
```

### Hur produceras det?

1. Skriv teststrategi i tidigt skede, parallellt med kravarbetet
2. Skriv tester parallellt med kod (helst TDD)
3. Koppla testfall till acceptanskriterier
4. Granska testtäckning regelbundet – fokusera på kvalitet, inte bara procent

---

## 8. Driftdokumentation (Runbook)

### Syfte

Runbooken är den operationella handboken. Den ska göra det möjligt att drifta, övervaka, felsöka och återställa systemet – även av någon som inte var med och byggde det.

### Vad ska det innehålla?

#### 8.1 Systemöversikt (driftperspektiv)

En kortfattad beskrivning av systemet ur driftsynpunkt:

- Vilka processer körs?
- Vilka portar lyssnar på vad?
- Vilka externa beroenden finns?

#### 8.2 Uppstart och nedstängning

Steg-för-steg-instruktioner för:

- Normal uppstart
- Planerad nedstängning
- Omstart vid fel

Inkludera faktiska kommandon, inte bara beskrivningar.

```bash
# Starta systemet
docker compose -f docker-compose.prod.yml up -d

# Kontrollera status
docker compose ps
curl -f http://localhost:8080/health

# Graciös nedstängning
docker compose down --timeout 30
```

#### 8.3 Vanliga driftuppgifter

- Hur roteras loggar?
- Hur triggas en manuell backup?
- Hur skalas systemet upp/ned?
- Hur körs en schemamigrering?

#### 8.4 Felsökningsguide

Dokumentera kända problem och deras lösningar löpande:

```text
SYMPTOM: Applikationen svarar med HTTP 503
MÖJLIGA ORSAKER:
  1. Databasen är otillgänglig → kontrollera: docker compose ps db
  2. Minnesproblem → kontrollera: docker stats
  3. Diskutrymme fullt → kontrollera: df -h
ÅTGÄRD: ...
```

#### 8.5 Incident- och återställningsrutiner

- Vem kontaktas vid en incident?
- Hur klassificeras allvarlighetsgrad?
- Steg för återställning från backup
- Post-mortem-process: Vad hände? Varför? Vad görs annorlunda?

#### 8.6 Releaseprocess

- Förberedelsechecklist inför release
- Hur version och releasekandidat väljs
- Kommandon eller workflow för att skapa och pusha tagg
- Hur GitHub Release och releasenoter skapas, verifieras och vid behov rättas
- Steg för att rulla ut en ny version
- Rollback-procedur om release misslyckas
- Smoke test-checklist efter deployment
- Var releaseutfall, kända problem och rollbackbeslut dokumenteras

### Kvalitetskriterier

- Alla kommandon ska vara testade och fungerande
- Inga "se källkoden" eller "fråga [person]" – information ska vara självständig
- Runbooken ska uppdateras direkt efter varje drifthändelse som avslöjade en lucka

### Hur produceras det?

1. Grundstruktur skapas vid första deployment till staging
2. Byggs ut löpande under projektet
3. Efter varje incident: uppdatera felsökningsguiden med nytt ärende och lösning
4. Granska runbooken inför varje produktionsrelease

---

## 9. Ändringshantering och versionshistorik

### Syfte

Säkerställer att dokumentation håller sig aktuell och att förändringar är spårbara.

### Principer

**Dokumentation är kod**  
Alla dokumentförändringar görs via pull requests i samma repo som koden. Detta ger granskning, historik och koppling till den kod som förändringen gäller.

**Atomic commits**  
En PR som ändrar arkitekturen ska också uppdatera SAD. En PR som lägger till en endpoint ska också uppdatera API-kontraktet. Dokumentuppdateringar ska vara en del av definition of done.

**Releasedokumentation**

GitHub Release är den publicerade sammanfattningen för en specifik version och ska länka till tagg, ändringar,
artefakter och kända begränsningar. `CHANGELOG.md` är den kumulativa versionshistoriken, Runbook beskriver hur
releasen genomförs och återställs, och releasehistoriken registrerar utfall och produktionsdatum. Dokumenten har
olika syften och ska länka till varandra i stället för att ersätta varandra.

**Versionshistorik i dokumenthuvud**  
Varje dokument bär en enkel historiktabell längst upp:

```markdown
| Version | Datum      | Förändring                    | Författare     |
| --------- | ------------ | ------------------------------- | ---------------- |
| 1.0     | 2025-01-15 | Initial version               | Joakim Persson |
```

**Föråldrade beslut**  
När ett arkitekturellt beslut ändras, markera det gamla ADR:et som `Status: Föråldrad` och referera till det nya. Ta aldrig bort ett ADR – historiken har värde.

---

## 10. Grafisk profil & Design Tokens

### Syfte

Den grafiska profilen dokumenterar det visuella språket: färger, typografi, spacing, radier, skuggor och rörelse.
Den är ett **ingångsvärde** – ska vara godkänd innan UI-kodning påbörjas – inte en efterhandsbeskrivning av vad
som råkade hamna i koden.

Design tokens i DTCG-format (W3C Design Token Community Group) gör profilen maskinläsbar. Det innebär att
token-filen kan transformeras automatiskt till CSS custom properties, Swift-extensions, Kotlin-resurser och andra
målformat via verktyg som Style Dictionary.

### När produceras det?

**Obligatorisk om projektet har ett visuellt gränssnitt** – webb, iOS/iPadOS, macOS eller annat. Skapas parallellt
med kravarbetet och godkänns innan implementation av UI påbörjas.

Projekt utan UI (rena backend-tjänster, CLI-verktyg, bibliotek) behöver inte detta dokument.

### Vad ska det innehålla?

**Varumärkesgrunder**
Logotyp med varianter och frizon, färgpalett med semantiska roller, typografisystem med skalor och teckensnittsval,
bildspråk och ikonografistil.

**WCAG-kontrastkrav**
Alla kritiska färgkombinationer dokumenteras med uppmätta kontraskvoter mot WCAG 2.1 AA (4,5:1 för normal text,
3:1 för stor text och UI-komponenter).

**Design tokens (DTCG-format)**
En JSON-fil i W3C DTCG-format som definierar alla visuella värden: färg, typografi, spacing, radier, skuggor och
animationstider. Filen är källan till sanning och versioneras i Git. Genererade plattformsfiler redigeras aldrig
manuellt.

**Plattformstransformation**
Dokumentation av hur token-filen transformeras till respektive målplattform och vilket byggkommando som kör
transformationen.

**Ägarskap och underhållsprocess**
Vem äger profilen, hur förändras tokens, och vad räknas som en breaking change.

### Kvalitetskriterier

- Alla färgkombinationer som används i UI uppfyller WCAG 2.1 AA
- Token-filen är giltig DTCG-JSON och transformationspipelinen körs utan fel
- Inga visuella hårdkodade värden (hex, px-värden, fontnamn) förekommer i kod när tokens finns dokumenterade
- Genererade token-filer redigeras aldrig manuellt

### Hur produceras det?

1. Samla in befintliga varumärkesriktlinjer eller besluta om dem i ett designmöte
2. Definiera semantiska roller för färger (primär, sekundär, semantiska tillstånd)
3. Fatta beslutet om token-taxonomi och namngivning innan filen skapas – det är svårt att ändra i efterhand
4. Skapa `design/tokens.json` i DTCG-format och sätt upp transformationspipeline
5. Granska mot WCAG-kontrastkrav och justera vid behov
6. Godkänn dokumentet innan UI-kodning påbörjas

---

## 11. Dokumentationsprocess – hur produceras vad och när

### Faser och aktiviteter

```text
┌─────────────────────────────────────────────────────────────────┐
│ FAS 1: INITIERING                                               │
│                                                                 │
│  → Producera: Vision & Scope                                    │
│  → Aktivitet: Kick-off, intressentintervjuer                    │
│  → Output: Godkänt V&S-dokument                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ FAS 2: KRAV & DESIGN                                            │
│                                                                 │
│  → Producera: Kravdokumentation, SAD (utkast), Datamodell       │
│               Grafisk profil & Design Tokens (om UI finns)      │
│  → Aktivitet: Kravworkshops, arkitekturskisser, ADR-sessioner,  │
│               token-taxonomibeslut, WCAG-granskning             │
│  → Output: Prioriterad backlog, godkänd arkitektur,             │
│            godkänd grafisk profil (innan UI-kodning startar)    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ FAS 3: IMPLEMENTATION                                           │
│                                                                 │
│  → Producera: API-kontrakt, Deployment View, Teststrategi       │
│  → Aktivitet: Sprint/iteration-arbete, löpande SAD-uppdatering  │
│  → Output: Fungerande mjukvara med aktuell dokumentation        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ FAS 4: DRIFTSÄTTNING                                            │
│                                                                 │
│  → Producera: Runbook (fullständig), CI/CD-dokumentation        │
│  → Aktivitet: Staging-deployment, smoke tests, release-review   │
│  → Output: Produktionssatt system med operationell dokumentation│
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ FAS 5: FÖRVALTNING (löpande)                                    │
│                                                                 │
│  → Underhåll: Alla levande dokument                             │
│  → Aktivitet: Post-mortems, nya ADR:er, backlog-refinement      │
│  → Output: Kontinuerligt aktuell dokumentation                  │
└─────────────────────────────────────────────────────────────────┘
```

### Dokumentationsreview-checklist (inför release)

```text
KRAVDOKUMENTATION
☐ Alla stories för releasen har acceptanskriterier
☐ NFR:er är verifierade mot implementation

ARKITEKTUR (SAD)
☐ Nya komponenter är dokumenterade
☐ Ändrade teknologival har ADR
☐ Diagram är uppdaterade

GRAFISK PROFIL & DESIGN TOKENS (om projektet har UI)
☐ Inga hårdkodade visuella värden i ny kod – tokens används
☐ Nya tokens är tillagda i tokens.json och transformationspipelinen körs utan fel
☐ Breaking token-ändringar är dokumenterade och kommunicerade
☐ WCAG-kontrastkrav är verifierade för nya färgkombinationer

DATAMODELL & API
☐ Schemamigrationer är dokumenterade
☐ Nya/ändrade endpoints är dokumenterade i Swagger/OpenAPI

DEPLOYMENT
☐ Infrastrukturförändringar är reflekterade
☐ CI/CD-pipeline är uppdaterad

RUNBOOK
☐ Releaseprocess är uppdaterad
☐ Ny konfiguration är dokumenterad
☐ Felsökningsguide är uppdaterad vid behov
```

### Minsta dokumentationsuppsättning för MVP

Om resurser är knappa, prioritera i denna ordning:

1. **Vision & Scope** – utan detta vet ingen vad som ska byggas
2. **Kravdokumentation** (user stories + NFR) – utan detta vet ingen *hur väl* det ska byggas
3. **README.md** (i repot) – snabb onboarding, hur man kör projektet lokalt
4. **SAD** (minst kontextvy + komponenter + ADR:er) – utan detta är arkitekturen osynlig
5. **Runbook** (minst uppstart/nedstång + rollback) – utan detta är drift ett hasardspel

För ett personligt projekt eller hobby-projekt är Vision & Scope + README + SAD ofta tillräckligt för att hålla projektet sammanhängande.

---

## 12. AI-assistans – valfritt accelerationslager

> Se även det separata dokumentet `09-ai-usage-guide.md` för fullständiga riktlinjer.

AI-assistans är ett lager ovanpå Clarity Framework – inte en förutsättning. Ramverket fungerar lika bra för ett team som arbetar utan AI som för en soloutvecklare som använder Claude som kodpartner.

### Vad AI tillför

- **Snabbare utkast** – AI kan generera ett första utkast på ett SAD, en lista med NFR eller ett API-kontrakt på minuter. Granska och justera alltid.
- **Klargörande frågor** – En AI kan hjälpa identifiera luckor i kravdokumentationen genom att ställa frågor du inte tänkt på.
- **Kontextbärare** – Genom att läsa `00-ai-context.md` i varje ny session kan en AI omedelbart förstå projektet och ge relevanta svar utan att du behöver repetera bakgrunden.
- **Kodgenerering i linje med arkitekturen** – Kod som genereras med SAD och datamodellen som kontext tenderar att hålla sig till den valda arkitekturen.

### Vad AI inte ersätter

Intressentdialoger, prioriteringsbeslut, formellt godkännande och användarvalidering kräver alltid en människa. Se `09-ai-usage-guide.md` för fullständig lista.

### AI Context Document

`00-ai-context.md` är den enda filen som är designad primärt för att läsas av en AI. Den destillerar projektets alla dokument till max en sida och klistras in i början av en ny session. Se mallen i ramverket.

---

*Clarity Framework v1..0 | Uppdaterad: 2026-04*
