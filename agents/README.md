# Agents – AI-beteendeinstruktioner per stack

Den här katalogen innehåller fördefinierade `AGENTS.md`-filer för vanliga projektyper. De är startpunkter att kopiera och anpassa – inte normerande standarder.

---

## Vad är AGENTS.md?

`AGENTS.md` är en instruktionsfil som placeras i roten av ett projekt och berättar för AI-agenter (Claude, Codex m.fl.) **hur** de ska arbeta i just det projektet. Den kompletterar Clarity Frameworks övriga dokumentation:

| Dokument | Svarar på |
| --- | --- |
| `docs/00-ai-context.md` | Vad är projektet? |
| `docs/01-vision-scope.md` | Varför byggs det? |
| `docs/03-sad.md` | Hur är det arkitekturerat? |
| `AGENTS.md` | Hur ska agenten arbeta här? |

Tillsammans ger de en AI-agent tillräcklig kontext för att fatta lokala beslut utan att gissa.

---

## Tillgängliga starters

| Fil | Passar när... |
| --- | --- |
| `java-application.md` | Projektet är en Java-applikation, med eller utan Spring Boot |
| `r-shiny.md` | Projektet är en R/Shiny-app, med eller utan plumber-API |
| `vanilla-web-spa.md` | Projektet är en byggsstegssfri webbapp i ren HTML/CSS/JS |
| `shell-dotfiles.md` | Du arbetar med shellskript, aliases eller dotfiles |
| `macos-swift.md` | Projektet är en macOS-app i Swift |

---

## Hur du använder en starter

1. Kopiera relevant fil till projektets rot och döp om den till `AGENTS.md`
2. Ta bort profiler och sektioner som inte gäller ditt projekt
3. Justera dokumentreferenserna om ditt projekt använder andra sökvägar
4. Committa filen som vilken annan dokumentationsfil som helst

---

## Integrering med Clarity Framework

Alla starters refererar till Clarity Frameworks standardsökvägar (`docs/00-ai-context.md`, `docs/03-sad.md` osv.). Om ditt projekt placerar dokumentation på andra sökvägar, uppdatera referenserna i den kopierade `AGENTS.md`.

Prioritetsordning när en agent läser instruktioner:

```text
Lokalt CLAUDE.md / AGENTS.md i projektroten
  ↓ tar alltid över
Clarity Framework-dokument i docs/
  ↓ ger arkitektur- och kravkontext
Stack-specifika regler (från denna starter)
```

---

## Lägga till en ny starter

Om du lägger till en ny stack:

1. Namnge filen `[stack].md` med gemener och bindestreck
2. Följ samma struktur: *How To Use*, *Core Rules*, valfria profiler, *Definition of Done*
3. Referera till Clarity Framework-dokument i Workflow-steget
4. Lägg till en rad i tabellen ovan
5. Lägg till en entry i `framework/CHANGELOG.md`

---

*Clarity Framework – Agents*
