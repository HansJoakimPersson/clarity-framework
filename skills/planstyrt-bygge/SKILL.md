---
name: planstyrt-bygge
description: Planstyrt arbetsflöde där Claude Code skriver en plan enligt Clarity Frameworks planmall, låter Codex CLI granska den mot koden, och efter godkännande låter Codex bygga den. Använd när en uppgift är stor nog att omfattningen behöver godkännas innan kod skrivs.
---

# Planstyrt bygge

Du planerar och granskar. **Codex bygger.** Du skriver ingen produktionskod i det här flödet.

## Förutsättningar

Kontrollera innan du börjar. Saknas något: rapportera det och stanna, improvisera inte förbi.

- `codex` finns i PATH (`command -v codex`)
- `AGENTS.md` finns i projektroten
- Repot är rent (`git status --porcelain` tomt) och du står på rätt gren

Rent repo är inte formalia: Codex skriver direkt i arbetsträdet, och är det smutsigt när bygget
startar går det inte längre att se vad Codex gjorde och vad som redan låg där. Är det smutsigt –
rapportera vad som ligger oincheckat och låt användaren avgöra. Committa, stasha eller återställ
aldrig åt användaren utan att fråga.

Planmallen ligger i skillen som `plan-mall.md` och följer med när skillen kopieras. Leta inte efter
`templates/plan.md` – den sökvägen finns i ramverksrepot, inte i projekt som använder ramverket.

## Steg 1 – Skriv planen

Läs `docs/00-ai-context.md` och därifrån bara det uppgiften faktiskt berör.

Kopiera `plan-mall.md` från den här skillkatalogen till `docs/plans/ÅÅÅÅ-MM-DD-kort-namn.md` och
fyll i kopian. Använd dagens faktiska datum. Redigera aldrig mallen på plats – då finns ingen mall
till nästa plan.

Planen ska kunna byggas av en agent som inte deltagit i konversationen och inte kan fråga
användaren. Det ställer krav:

- **Omfattning** – `Ingår` och `Ingår inte` ska vara konkreta beteenden eller ytor, inte teman.
  `Ingår inte` är det fält som hindrar drift; hoppa aldrig över det.
- **Steg** – faktiska filsökvägar och ett körbart `Verifiering:`-kommando per steg.
- **Öppna frågor** – är något oklart nog att bygget skulle gissa fel, skriv det som
  `BLOCKERANDE`. Anta inte åt användaren.
- **Definition of Done** – kontrollerbara villkor, inte omdömen.

Bygg ingenting i det här steget.

## Steg 2 – Låt Codex granska planen

Kör read-only så att Codex inte kan ändra planen den granskar:

```bash
codex exec -s read-only -o /tmp/codex-plangranskning.md "Läs AGENTS.md och docs/plans/<planfil>. Granska planen mot koden — bygg ingenting och ändra inga filer. Stämmer filsökvägarna? Finns funktionerna och modulerna planen förutsätter? Går verifieringskommandona att köra som de står? Räcker stegen för att bygga utan att gissa? Ligger något under Ingår som redan finns? Svara med konkreta invändningar och föreslagna planändringar, inte ett omdöme."
```

Läs `/tmp/codex-plangranskning.md`.

## Steg 3 – Revidera och stanna

Skriv in de invändningar du håller med om i planen. Motivera kort de du avfärdar — tyst
avfärdande döljer att granskningen skedde.

Sätt `Status: Godkänd`.

Visa användaren: målet, `Ingår` / `Ingår inte`, alla `BLOCKERANDE`-frågor, och vad
granskningen ändrade.

**Stanna här.** Att godkänna omfattningen innan kod skrivs är hela poängen med flödet.
Gå inte vidare utan klartecken. Blockerande frågor besvaras av användaren, inte av dig.

## Steg 4 – Låt Codex bygga

Efter klartecken: committa planen först, så att det går att se vilken version som byggdes.

Kör bygget **i bakgrunden**. Ett bygge överskrider regelmässigt förgrundstimeouten, och en
dödad Codex-process lämnar halva ändringen på disk.

```bash
codex exec -s workspace-write "Läs AGENTS.md och docs/plans/<planfil>, i den ordningen. Bygg planen. Omfattningsavsnittet är auktoritativt — planera inte om, och bygg inget som inte står under Ingår. Visar sig planen fel eller ofullständig: stanna och rapportera, improvisera inte vidare. Kör verifieringen efter varje steg."
```

## Steg 5 – Granska diffen mot planen

Läs `git diff` och jämför mot planens Definition of Done, ett villkor i taget.

Rapportera vad som är klart och vad som inte är det. Peka ut allt Codex byggde som ligger
utanför `Ingår`.

**Bygg inte klart själv om Codex stannade.** Rapportera varför den stannade och låt
användaren avgöra. Att ta över är det tysta felet som gör hela flödet meningslöst — då har
användaren betalat för orkestreringen utan att få den.

## Steg 6 — Committa resultatet

Lämna aldrig bygget oincheckat. Ett smutsigt arbetsträd blockerar nästa körning av det här flödet,
och då går det inte längre att skilja förra varvets ändringar från nästa varvs.

Föreslå en commit och vänta på godkännande — committa inte självmant om inte projektet säger annat.
Följer projektet Clarity Frameworks commit-disciplin ska berörda `docs/` med i samma commit.

Krävs fler varv för att bli klar stannar planen kvar i repot tills allt är byggt.

## Städa

Planen är transient. Radera den när ändringen är mergad, i en egen commit. Det som var värt att
behålla har redan flyttat till `docs/03-sad.md` eller `docs/08-andringshantering.md`.

`plan-mall.md` stannar i skillkatalogen och raderas aldrig — den är mallen, inte en plan.

## Att veta

- `-s workspace-write` låter Codex ändra filer utan att fråga användaren. Du ser resultatet
  först när det är klart. Det är rätt avvägning när planen är granskad och omfattningen snäv,
  fel avvägning när planen är vag — då är det bättre att låta användaren köra Codex själv.
- Flödet kostar två modeller på samma uppgift plus din granskning. För en ändring användaren
  kan överblicka på fem minuter är det inte värt det. Säg det istället för att köra flödet.
- Ska en annan byggagent användas är det bara kommandot i steg 2 och 4 som byts. Rollerna,
  planen och stoppunkten är oberoende av verktyg.
