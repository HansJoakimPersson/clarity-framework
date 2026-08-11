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
| `ios-springboot.md` | Projektet har en Spring Boot-backend och en native iOS/iPadOS-app i Swift |
| `r-shiny.md` | Projektet är en R/Shiny-app, med eller utan plumber-API |
| `vanilla-web-spa.md` | Projektet är en byggsstegssfri webbapp i ren HTML/CSS/JS |
| `shell-dotfiles.md` | Du arbetar med shellskript, aliases eller dotfiles |
| `macos-swift.md` | Projektet är en macOS-app i Swift |
| `electron-desktop.md` | Projektet är en Electron-baserad desktop-app som ska kännas native |

---

## Hur du använder en starter

1. Kopiera relevant fil till projektets rot och döp om den till `AGENTS.md`
2. Committa filen som vilken annan dokumentationsfil som helst

Det är hela proceduren. **Redigera inte den kopierade filen.**

Varje starter villkorar sina egna avsnitt vid läsning – `java-application.md` säger till exempel
"Add **Maven** when the project uses Maven" i sin *How To Use*. Agenten avgör alltså själv vilka
profiler som gäller, och en profil för något projektet inte använder kostar ingenting. Att radera
den i förväg tillför inget och gör filen omöjlig att uppdatera maskinellt.

`AGENTS.md` ägs därmed av ramverket och ersätts i sin helhet när projektet uppdateras till en ny
ramverksversion. Det som är projektspecifikt hör hemma i projektets `CLAUDE.md`, som ramverket
aldrig rör – och som enligt prioritetsordningen nedan ändå tar över.

---

## Integrering med Clarity Framework

Alla starters refererar till Clarity Frameworks standardsökvägar (`docs/00-ai-context.md`, `docs/03-sad.md` osv.). De sökvägarna är standard – ett projekt som avviker från dem noterar avvikelsen i sin `CLAUDE.md` istället för att redigera `AGENTS.md`.

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
4. Ta med sektionen *When You Are a Dispatched Agent* – den gäller oavsett stack och är det som
   håller en agent inom planens omfattning när den anropas av en orchestrator istället för av dig
5. Lägg till en rad i tabellen ovan
6. Lägg till en entry i `framework/CHANGELOG.md`

---

*Clarity Framework – Agents*
