# Plan: [kort namn]

> **Syfte:** Arbetsorder för en agent som inte deltog i planeringen.  
> **Livslängd:** Transient. Skapas, konsumeras, raderas när ändringen är mergad.  
> **Placering:** `docs/plans/ÅÅÅÅ-MM-DD-kort-namn.md`

| | |
| --- | --- |
| **Skapad** | ÅÅÅÅ-MM-DD |
| **Gren** | `[branch-namn]` |
| **Status** | Utkast / Godkänd / Under bygge / Klar |
| **Grindprofil** | interaktiv / halvautomatisk / obevakad |
| **Rapportbudget** | Kritik 40 rader · Verifiering: ett svar per DoD-villkor + 10 rader avvikelser |
| **Körjournal** | `docs/plans/ÅÅÅÅ-MM-DD-kort-namn.run.md` (om automatiserat flöde används) |

> **Grindprofil** avgör var flödet stannar för dig. `interaktiv` stannar vid omfattning, commit,
> merge och avslut. `halvautomatisk` stannar vid omfattning och merge. `obevakad` stannar bara vid
> merge – och kräver att varje villkor under Definition of Done går att kontrollera med ett
> kommando. Merge-grinden finns i alla tre. Välj efter risk, inte efter otålighet.

---

## Mål

[En mening. Vad ska vara sant när det här är klart?]

---

## Omfattning

**Ingår:**

- [Konkret beteende eller yta som ska byggas eller ändras]
- [...]

**Ingår inte:**

- [Explicit avgränsning – vad som INTE ska röras, även om det ser frestande ut]
- [...]

> Det här avsnittet är auktoritativt. Byggagenten planerar inte om. Om planen visar sig fel eller
> ofullständig ska den stanna och rapportera, inte improvisera vidare.

---

## Kontext att läsa först

| Dokument | Varför |
| --- | --- |
| `AGENTS.md` | Gäller i sin helhet – stil, säkerhet, testkrav |
| `CLAUDE.md` | Projektspecifika avvikelser efter `@AGENTS.md`-importen, om filen finns |
| `docs/03-sad.md` § [avsnitt] | [Vilket arkitekturbeslut som styr den här ändringen] |
| `docs/04-datamodell-api.md` | [Om ändringen rör datamodell eller API-kontrakt] |
| `docs/09-grafisk-profil.md` | [Om ändringen rör något visuellt] |

---

## Steg

1. **[Vad]** i `sökväg/till/fil.ext`  
   [Konkret beskrivning – tillräckligt för att bygga utan att gissa]  
   Verifiering: `[kommando]`

2. **[Vad]** i `sökväg/till/fil.ext`  
   [...]  
   Verifiering: `[kommando]`

---

## Öppna frågor

- [ ] **BLOCKERANDE:** [Måste besvaras av en människa innan bygget startar]
- [ ] Antag [X] och fortsätt – notera antagandet i rapporten

> Blockerande frågor stoppar bygget. Övriga besvaras med ett dokumenterat antagande.

---

## Definition of Done

- [ ] [Kontrollerbart villkor – inte "fungerar bra" utan "kommando X ger utfall Y"]
- [ ] Tester gröna
- [ ] Berörda Clarity Framework-dokument uppdaterade

> Villkoren granskas ett i taget mot diffen, med krav på konkret bevis per villkor. Ett villkor som
> inte går att belägga med en filväg, ett symbolnamn eller ett kommandoutfall går inte att verifiera
> – då är det formulerat som en bedömning, inte som ett villkor. Vid `obevakad` grindprofil är det
> ett hårt krav, inte en rekommendation.

---

## Vid avslut

Besvaras innan planen raderas. "Inget" är ett giltigt svar – uteblivet svar är det inte.

- [ ] Vilka beslut från bygget hör hemma i `docs/03-sad.md`?
- [ ] Vad ska in i `docs/08-andringshantering.md`?
- [ ] Vad var fel i planen? En mening – den gör nästa plan bättre.

> Planen raderas här. Utan de här svaren raderas lärdomen med den.

---

*Clarity Framework v1.5.1 – Planmall*
