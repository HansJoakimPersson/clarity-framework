# Plan: [kort namn]

> **Syfte:** Arbetsorder för en agent som inte deltog i planeringen.  
> **Livslängd:** Transient. Skapas, konsumeras, raderas när ändringen är mergad.  
> **Placering:** `docs/plans/ÅÅÅÅ-MM-DD-kort-namn.md`

| | |
| --- | --- |
| **Skapad** | ÅÅÅÅ-MM-DD |
| **Gren** | `[branch-namn]` |
| **Status** | Utkast / Godkänd / Under bygge / Klar |

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

---

*Clarity Framework v1.2.0 – Planmall*
