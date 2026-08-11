# AI Usage Guide

## Clarity Framework – Valfritt accelerationslager

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
| Design | Grafisk profil | Strukturerar tokens i DTCG-format, räknar kontrastvärden, föreslår skalor för spacing och typografi | Kan inte fatta varumärkesbeslut – färgval och uttryck kräver en människa |
| Design | Datamodell & API | Genererar scheman, föreslår API-struktur, skriver OpenAPI-spec | Kan inte avgöra rätt domänmodell utan djup domänkunskap |
| Driftsättning | Deployment View | Genererar docker-compose, CI/CD-pipelines, infrastrukturdiagram | Kan inte verifiera att konfigurationen fungerar i din miljö |
| Implementation | — | Skriver kod utifrån dokumenten som kontext | Kod utan dokumentkontext tenderar att avvika från arkitekturen |
| Test | Testdokumentation | Genererar testfall från acceptanskriterier, skriver testkod | Kan inte identifiera edge cases den inte känner till |
| Drift | Runbook | Felsöker baserat på loggar och symptom, föreslår åtgärder | Kan inte observera ditt system direkt |

---

## 3. AI Context Document

### Vad är det?

AI Context Document är en komprimerad projektöversikt designad specifikt för att **klistras in i en ny AI-session**. Det destillerar all väsentlig information från projektets övriga dokument till en enda fil som ger en AI omedelbar förståelse för projektet utan att den behöver läsa allt.

### När används det?

- I början av varje ny AI-session där du vill ha hjälp med projektet
- Som onboarding-dokument för en ny teammedlem (mänsklig eller AI)
- Som en löpande "state of the project"-sammanfattning

### Mall

Mallen finns i `templates/00-ai-context.md` och kopieras därifrån. Den återges inte här – en kopia i två filer glider isär, och mallen är den som gäller.

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

## 5. Flera agenter – orchestrator, reasoning och implementation

Att dela upp arbetet mellan flera AI-agenter (till exempel Claude Code och Codex) är valfritt. Om du gör det finns bara en fråga som spelar roll:

**Agenterna delar ingen kontext.** Separata sessioner, separat minne, separata resonemangskedjor. Allt som inte är skrivet till fil finns inte vid överlämningen. Hela integrationen reduceras därför till: *vad är överlämningsartefakten, och var ligger den?*

### Nivåer

Rollerna beskrivs som nivåer av resonemang och capability, inte som specifika modeller – vilken agent som fyller en nivå är ett projektbeslut, inte ett ramverksbeslut.

| Nivå | Ansvar | Får inte |
| --- | --- | --- |
| **Orchestrator** | Sekvenserar flödet, håller sin egen kontext minimal, presenterar destillat för dig, äger godkännande-grindarna | Läsa hela kodbasen eller diffen själv, skriva produktionskod |
| **Reasoning** | Djup kontext in (dokument, kod, diff), destillat ut: en plan med `BLOCKERANDE`-frågor, eller ett pass/fail per Definition of Done-villkor | Godkänna sitt eget arbete, prata direkt med dig, fatta scope-beslut |
| **Implementation** | Bygger en redan godkänd, konkret plan i full omfattning | Planera om – stannar vid blockerande fråga |

Reasoning och Implementation kan vara samma agent i olika lägen eller två separata – men båda ska köras under ett **annat CLI eller konto än orchestratorn**. Det är inte bara kontextisolering, det är kostnadsfördelning: en Claude-subagent (Task-verktyget) delar abonnemang med orchestratorn och löser därför inte problemet den här uppdelningen finns för, även om den isolerar kontexten. Se `skills/planstyrt-bygge/` för en konkret implementation.

Nivåerna definieras per projekt i `docs/00-ai-context.md`. Ett projekt som använder en enda agent hoppar över avsnittet.

### Planen som artefakt

Planen är en **arbetsorder, inte projektdokumentation**. Den skapas, konsumeras och raderas när ändringen är mergad. Den ska aldrig samlas till ett arkiv av inaktuella planer – det bryter mot *klarhet framför fullständighet*. Det som var värt att behålla har redan flyttat till `03-sad.md` eller `08-andringshantering.md`.

Mall: `templates/plan.md`. Placering: `docs/plans/ÅÅÅÅ-MM-DD-kort-namn.md`.

Två fält gör mest nytta: **Ingår inte** och **BLOCKERANDE**. Agentdrift och tyst gissande är de vanligaste felen vid överlämning, och det är dessa två fält som adresserar dem.

### Praktiska begränsningar

- En molnbaserad agent ser bara det som är **committat och pushat**. Planen måste ligga i repot – inte i en chatt.
- Planen måste vara mer explicit än en plan du skriver åt dig själv. Implementation-agenten har noll tyst kontext.
- När planen visar sig fel mitt i bygget kan implementation-agenten inte planera om bra – den vet inte *varför* planen såg ut som den gjorde. Därför regeln att stanna och rapportera.
- Reasoning-nivån levererar ett destillat, inte ett transkript. Om orchestratorn ändå läser hela diffen eller hela källdokumenten "för säkerhets skull" är kostnadsfördelningen bara skenbar – disciplinen ligger i att faktiskt lita på destillatet, med stickprov vid behov, inte i att läsa allt två gånger.

### Vad vinsten faktiskt är

Inte att en viss modell är bättre på att planera. Vinsten är att:

- Planen blir en **granskningspunkt innan kod finns** – den billigaste platsen att ingripa på.
- Granskningen blir **objektiv**: stämmer diffen mot planen? Det är en skarpare fråga än "är koden bra".
- Reasoning-nivån delar inte implementation-agentens resonemangskedja och ser därför andra fel.
- Orchestratorns egen kontext – och räkning – hålls liten genom hela flödet, oavsett hur stor kodbasen eller diffen är.

Nivådelningen tvingar fram disciplinen. Du får merparten av värdet även med en enda agent som skriver planen till fil först.

### Automatisera flödet

`skills/planstyrt-bygge/` är en färdig skill för Claude Code som kör hela kedjan: dispatchar planen och den efterföljande diffgranskningen till en reasoning-nivå (ett annat CLI eller konto, read-only), stannar för ditt godkännande av omfattningen, och dispatchar sedan bygget till en implementation-nivå. Kopiera den till projektets `.claude/skills/` när flödet behövs.

Stoppunkten före bygget är inte en artighet – den är hela poängen. En automatisering som hoppar över den ger dig ett bygge du inte har godkänt omfattningen på.

### Verktygsdetektion – komplement som får användas om de finns

Långkörande automatiserade flöden ska inte kräva kompletterande verktyg, men får dra nytta av dem om de redan finns. Principen är detektion, inte beroende: kontrollera om verktyget finns, använd det om det gör det, fortsätt fungera om det inte gör det.

**Limit-failover.** Ett bygge som når ett abonnemangs- eller tokenlimit mitt i ska inte bara tappa arbetet om ett alternativ finns. En multiplexer som [aimux](https://github.com/Digital-Threads/aimux) kan, om den redan är installerad och konfigurerad med fler profiler, fortsätta samma session under ett annat CLI eller konto via en sammanfattningsöverlämning. `skills/planstyrt-bygge/` känner av detta och beskriver det konkreta flödet under "If the build hits a subscription/usage limit mid-run".

**Kontextkomprimering och terse-svar.** Verktyg som komprimerar verktygsoutput innan den når kontexten, eller gör agentens egna svar kortare (t.ex. hooks-baserade plugins), verkar under agentens körlager. De kräver ingen integration i skills eller `AGENTS.md` – de är på eller av oberoende av vad ramverket säger, och nämns här enbart så att ingen skill råkar motverka dem.

---

## 6. Vad AI inte kan ersätta

| Aktivitet | Varför det kräver människa |
| --- | --- |
| Intressentintervjuer | Kräver tillit, relationsbyggande och förmåga att läsa mellan raderna |
| MoSCoW-prioritering | Kräver affärsbeslut och kunskap om resurser och strategi |
| Godkännande av Vision & Scope | Kräver formellt ägarskap och ansvar |
| Post-mortem efter incident | Kräver organisatoriskt lärande och kulturell reflektion |
| Definition of Done | Kräver teamöverenskommelse och gemensamt ansvar |
| Användarvalidering | Kräver faktiska användare – AI kan inte ersätta användartester |

---

*Detta dokument är en del av Clarity Framework v1.3.0*
*Nästa steg: Skapa `00-ai-context.md` för ditt specifika projekt*
