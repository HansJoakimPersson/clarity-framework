# AI Usage Guide

## Clarity Framework – Valfritt accelerationslager

> **Viktigt:** Detta dokument är en del av *ramverket*, inte av projektdokumentationen.  
> AI-assistans är ett **valfritt lager** ovanpå Clarity Framework. Ramverket fungerar fullt ut utan AI – för ett team av människor, en soloutvecklare, eller en kombination. AI accelererar processen men ersätter inte beslut, intressentdialoger eller ansvar.

---

## 1. Principer för AI-assistans i Clarity Framework

**AI äger inga beslut.**  
Arkitekturval, prioriteringar och scope-avgränsningar fattas alltid av en människa. AI kan föreslå, ifrågasätta och generera utkast – aldrig bestämma.

**Dokumenten är AI:ns minne.**  
En AI har ingen minneskontinuitet mellan sessioner. Clarity Framework-dokumenten fyller den funktionen – de är den kontext som gör att AI:n förstår projektet även i en ny konversation.

**Garbage in, garbage out.**  
En AI som matas med ett vagt Vision & Scope-dokument producerar vaga krav. Kvaliteten på AI:ns bidrag är direkt proportionell mot kvaliteten på dokumentationen den får som underlag.

**AI är bra på att generera, dålig på att validera.**  
AI kan snabbt producera ett utkast till en SAD eller en lista med NFR – men den kan inte avgöra om de speglar *din* verklighet. Validering mot faktiska användare och intressenter är alltid ett mänskligt ansvar.

---

## 2. AI:ns roller per fas

| Fas | Dokument | AI:ns primära roll | AI:ns begränsning |
| --- | --- | --- | --- |
| Initiering | Vision & Scope | Samtalspartner – ställer klargörande frågor, hjälper formulera vision | Kan inte känna till ditt affärssammanhang utan att du berättar |
| Krav | Kravdokumentation | Formulerar stories, skriver acceptanskriterier, identifierar saknade NFR | Kan inte prioritera åt dig – MoSCoW kräver affärsbeslut |
| Design | SAD | Föreslår arkitekturmönster, skriver ADR-utkast, ifrågasätter beslut | Känner inte till teamkompetens, budget eller befintliga beroenden |
| Design | Datamodell & API | Genererar scheman, föreslår API-struktur, skriver OpenAPI-spec | Kan inte avgöra rätt domänmodell utan djup domänkunskap |
| Driftsättning | Deployment View | Genererar docker-compose, CI/CD-pipelines, infrastrukturdiagram | Kan inte verifiera att konfigurationen fungerar i din miljö |
| Implementation | — | Skriver kod utifrån dokumenten som kontext | Kod utan dokumentkontext tenderar att avvika från arkitekturen |
| Test | Testdokumentation | Genererar testfall från acceptanskriterier, skriver testkod | Kan inte identifiera edge cases den inte känner till |
| Drift | Runbook | Felsöker baserat på loggar och symptom, föreslår åtgärder | Kan inte observera ditt system direkt |

---

## 3. AI Context Document

### Vad är det?

AI Context Document är en komprimerad projektöversikt designad specifikt för att **klistras in i en ny AI-session**. Det destillerar all väsentlig information från projektets 8 dokument till en enda fil som ger en AI omedelbar förståelse för projektet utan att den behöver läsa allt.

### När används det?

- I början av varje ny AI-session där du vill ha hjälp med projektet
- Som onboarding-dokument för en ny teammedlem (mänsklig eller AI)
- Som en löpande "state of the project"-sammanfattning

### Mall: `00-ai-context.md`

```markdown
# AI Context – [Produktnamn]
## Projektöversikt för ny session

**Senast uppdaterad:** ÅÅÅÅ-MM-DD  
**Ramverksversion:** Clarity Framework v1.0.0

---

### Vad är detta?
[2–3 meningar. Vad produkten gör och vilket problem den löser.]

### Teknisk stack
- Backend: [teknologi]
- Frontend: [teknologi]
- Databas: [teknologi]
- Hosting: [teknologi]
- CI/CD: [teknologi]

### Arkitektur i korthet
[3–5 meningar om arkitekturmönster och de viktigaste komponenterna.]

### Viktigaste NFR
- Prestanda: [konkret krav]
- Tillgänglighet: [konkret krav]
- [Övriga kritiska NFR]

### Aktuell status
- **Fas:** Initiering / Krav / Design / Implementation / Drift
- **Senaste release:** [version eller "ej releasad"]
- **Pågående arbete:** [vad som är aktivt just nu]

### Öppna arkitekturella frågor
- [Fråga eller beslut som ännu inte är fattat]
- [...]

### Känd teknisk skuld
- [TD-001: kort beskrivning]
- [...]

### Viktiga avgränsningar (out of scope)
- [Vad som medvetet exkluderats]
- [...]

### Dokument att läsa för djupare kontext
- Vision & Scope: `docs/01-vision-scope.md`
- SAD: `docs/03-sad.md`
- API-kontrakt: `docs/04-datamodell-api.md`
```

### Hur håller man det uppdaterat?

AI Context Document uppdateras när någon av dessa händelser inträffar:

- Vision & Scope ändras
- Ett nytt ADR godkänns
- En ny NFR läggs till eller ändras
- Projektets fas förändras
- Teknisk skuld läggs till eller åtgärdas

Det är det enda dokumentet i `/docs` som är designat för att vara *kort* – aldrig mer än en sida.

---

## 4. Praktiska mönster per arbetsform

### Soloutvecklare med AI

AI fungerar som både bollplank, medförfattare och kodgenerator. Clarity Framework ger strukturen som håller projektet sammanhängande när du arbetar i korta sessioner med långa pauser emellan.

**Rekommenderat arbetsflöde:**

1. Börja varje session med att klistra in `00-ai-context.md`
2. Tala om för AI:n vad du vill åstadkomma i sessionen
3. Låt AI:n generera utkast – granska och justera alltid själv
4. Uppdatera relevant dokument när sessionen producerat ett beslut eller förändring
5. Uppdatera `00-ai-context.md` om projektets status förändrats

### Litet team med AI-stöd

AI används som ett gemensamt verktyg som hela teamet kan konsultera. Dokumenten är källan till sanning – inte AI:ns senaste svar.

**Viktiga principer:**

- Beslut fattas i teamet, inte av AI
- AI-genererade utkast granskas av minst en människa innan de accepteras
- `00-ai-context.md` ägs av en specifik person i teamet och hålls uppdaterad

### Team utan AI

Clarity Framework fungerar fullt ut. AI Usage Guide och `00-ai-context.md` är valfria – hoppa över dem utan att förlora något av kärnramverkets värde.

---

## 5. Vad AI inte kan ersätta

| Aktivitet | Varför det kräver människa |
| --- | --- |
| Intressentintervjuer | Kräver tillit, relationsbyggande och förmåga att läsa mellan raderna |
| MoSCoW-prioritering | Kräver affärsbeslut och kunskap om resurser och strategi |
| Godkännande av Vision & Scope | Kräver formellt ägarskap och ansvar |
| Post-mortem efter incident | Kräver organisatoriskt lärande och kulturell reflektion |
| Definition of Done | Kräver teamöverenskommelse och gemensamt ansvar |
| Användarvalidering | Kräver faktiska användare – AI kan inte ersätta användartester |

---

*Detta dokument är en del av Clarity Framework v1.0.0*  
*Nästa steg: Skapa `00-ai-context.md` för ditt specifika projekt*
