# Körjournal: [kort namn]

> **Syfte:** Flödets tillstånd, utanför orchestratorns kontext.  
> **Livslängd:** Följer planen. Raderas när planen raderas.  
> **Placering:** `docs/plans/ÅÅÅÅ-MM-DD-kort-namn.run.md` – committas tillsammans med planen.
>
> Den här filen är mallen och ligger kvar i skillen. Kopiera den – redigera den aldrig på plats.
>
> Uppdateras **efter varje steg, före nästa dispatch**. En orchestrator som avbryts mitt i ett flöde
> – vid en tokengräns, ett sessionsslut eller ett byte av CLI – lämnar ingenting efter sig utom den
> här filen. Den som tar vid ska kunna svara på "var är vi?" genom att läsa den, och ingenting annat.

| | |
| --- | --- |
| **Plan** | `docs/plans/ÅÅÅÅ-MM-DD-kort-namn.md` |
| **Gren** | `[branch-namn]` |
| **Grindprofil** | interaktiv / halvautomatisk / obevakad |
| **Orchestrator** | [CLI och konto som kör flödet just nu] |
| **Råutdata** | `docs/plans/.runs/ÅÅÅÅ-MM-DD-kort-namn/` (lokal, gitignorerad) |

---

## Steg

| # | Steg | Status | Nivå / profil | Artefakt |
| --- | --- | --- | --- | --- |
| 1 | Plan | ☐ | reasoning | `<plan>` |
| 2 | Kritik | ☐ | granskning / reasoning | `.runs/.../kritik.md` |
| 3 | Revidering + scope-grind | ☐ | orchestrator | — |
| 4 | Bygge | ☐ | implementation | `.runs/.../bygge.log` |
| 5 | Verifiering | ☐ | reasoning | `.runs/.../verifiering.md` |
| 6 | Commit | ☐ | orchestrator | — |
| 7 | Merge-grind | ☐ | människa | — |
| 8 | Avslut | ☐ | orchestrator | — |

Status: ☐ ej påbörjat · ▶ pågår · ☑ klart · ✗ stoppat (se Avvikelser)

---

## Fakta nästa steg behöver

| | |
| --- | --- |
| **Godkänd vid commit** | `[SHA]` – steg 5 diffar mot denna |
| **Bygg-PID / exit** | `[PID]` / `[exit-kod, eller "kör"]` |
| **Nästa steg** | [Stegnummer och vad som konkret ska hända] |
| **Väntar på människa** | [Vilken fråga, eller "nej"] |

---

## Avvikelser

- [Vad som gick fel, vilket steg, och vad som gjordes åt det. Tomt är ett giltigt utfall.]
- [Om ett fallback användes – `codex exec` utan profil, `reasoning` istället för `granskning`,
  en `aimux handoff` – skriv det här. Fallback som inte är noterat ser ut som att separationen skedde.]

---

## Budgetutfall

Orchestratorns egen läsning per steg, i rader. Fylls i löpande – det är den enda datan på om
flödet faktiskt håller vad det lovar.

| Steg | Läst artefakt | Rader | Över budget? |
| --- | --- | --- | --- |
| 1 | Planen | | |
| 2 | Kritik (tak 40) | | |
| 4 | Bygglogg (tak 30, endast vid fel) | | |
| 5 | Verifiering (tak: DoD-villkor + 10) | | |

> Konsekvent överskridande betyder att flödet inte sparar det det påstår. Då är svaret att skärpa
> dispatch-prompternas takbegränsningar, inte att höja taken.

---

*Clarity Framework – Körjournal för planstyrt bygge*
