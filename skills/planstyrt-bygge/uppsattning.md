# Uppsättning – planstyrt bygge

Engångsuppsättning per maskin. `SKILL.md` förutsätter att det här är gjort och läser inte den här
filen under körning.

> **Verifiera flaggor och konfignycklar mot din installerade version** innan du litar på dem i ett
> obevakat flöde. Både Codex och Claude Code har ändrat namn på flaggor och settings-nycklar mellan
> versioner. Kör `codex exec --help` och testa en kort dispatch först. Ramverket ska inte påstå
> något det inte har provat – och en felaktig approval-flagga upptäcks som en hängd körning mitt i
> ett bygge.

---

## 1. Profiler som separerar konton

Poängen med nivåuppdelningen är att flytta tokenförbrukning bort från den interaktiva sessionen. Det
kräver **separata konton**, inte bara separata processer. En `codex exec` utan profilprefix landar på
vilket konto som redan är inloggat på maskinen – ofta samma som orchestratorn.

```bash
aimux profile add reasoning      --cli codex && aimux auth login reasoning
aimux profile add implementation --cli codex && aimux auth login implementation
aimux profile add granskning     --cli codex && aimux auth login granskning   # valfri
aimux profile list
```

Varje profil kan få en egen modell: `aimux profile update implementation -m <modell>`. Bygget är den
körning som oftast är lång nog att motivera en snabbare eller billigare modell, eftersom omfattningen
redan är beslutad när det startar.

`granskning` är valfri. Finns den körs steg 2 under ett annat konto än det som skrev planen, vilket
tar bort blindfläcken i att en nivå granskar sig själv. Saknas den faller flödet tillbaka på
`reasoning` och noterar det i körjournalen.

Skillens dispatch-kommandon sätter `CODEX_HOME="$HOME/.aimux/profiles/<profil>"` direkt istället för
att gå via `aimux run`, så att det komponerar med en bakgrundskörning. Det är aimux egen mekanism –
en config-katalogvariabel per CLI (`CLAUDE_CONFIG_DIR` / `CODEX_HOME` / `GEMINI_CLI_HOME`).

---

## 2. Permissionsmodellen

**Grindar ska ligga på beslut, inte på verktygsanrop.** De mänskliga besluten i det här flödet är
fyra: omfattningen (steg 3), merge (steg 7), release, och radering av planen (steg 8). Allt annat är
verktygsanrop inuti en sandbox och ska gå igenom utan att fråga. Ett flöde som stannar för att fråga
om lov att köra `git status` har grindat fel sak – och en agent som frågar om allt tränar bort
uppmärksamheten på de frågor som faktiskt betyder något.

### Codex – sätt alltid båda dimensionerna

Sandbox och approval är två oberoende inställningar. Skillens dispatcher satte tidigare bara sandbox
och lämnade approval på default, vilket är den vanligaste orsaken till att en dispatch stannar och
frågar mitt i en obevakad körning.

| Nivå | Flaggor |
| --- | --- |
| Reasoning, granskning | `-s read-only -a never` |
| Implementation | `-s workspace-write -a never` |

`--full-auto` är en genväg för `workspace-write` plus en mildare approval-policy – dugligt, men sätt
hellre båda flaggorna explicit så att det syns i kommandot vad som gäller.

### Codex som orchestrator

Det här är specialfallet, och orsaken till att Codex "bråkar om permissions" när den ska orkestrera:
orchestratorn startar subprocesser som behöver **nätverk** för att nå modell-API:t, och under
`workspace-write` är nätet blockerat som standard. Dispatchen dör då, eller eskalerar till en
approval-fråga. En egen profil i `~/.codex/config.toml`:

```toml
[profiles.orchestrator]
approval_policy = "never"
sandbox_mode    = "workspace-write"

[profiles.orchestrator.sandbox_workspace_write]
network_access = true
```

Kör sedan `codex --profile orchestrator`. Notera att en Codex-profil (`--profile`) och en
aimux-profil är olika saker: Codex-profilen styr beteende, aimux-profilen styr vilket konto som
betalar. De utesluter inte varandra.

`danger-full-access` löser samma sak trubbigare genom att ta bort sandboxen helt. Använd det inte som
standardläge – hela poängen med att låta implementation köra utan att fråga är att sandboxen står
kvar.

### Claude Code som orchestrator

Kopiera `settings.exempel.json` till projektets `.claude/settings.json` (eller slå ihop med en
befintlig) så att flödets egna kommandon inte grindas ett i taget.

`allow`-listan täcker dispatch, de git-kommandon flödet faktiskt kör, och läsning av plankatalogen –
ingenting annat. Att all dispatch går genom `dispatch.sh` är vad som gör den matchbar: ett
env-prefixat, bakgrundskört sammansatt kommando är svårt att skriva en pålitlig prefixregel för, ett
skript med stabil sökväg är det inte.

`deny`-listan är den intressanta halvan. Den gör budgeten till mekanism istället för disciplin:

| Regel | Varför |
| --- | --- |
| `Bash(git diff:*)`, `Bash(git show:*)` | Orchestratorn ska aldrig läsa diffen – det är steg 5:s uppgift. Utan regeln är det bara en instruktion, och instruktioner om att avstå från information är de som viker sig först när något ser konstigt ut |
| `Read(…/prompts/**)` | Prompterna ligger i filer just för att hålla dem utanför orchestratorns kontext. En regel som hindrar läsning är billigare än en instruktion som ber om att låta bli |

Behöver du undantagsvis se en hunk – ett högriskbygge, en rapport som ser fel ut – ta bort regeln
medvetet för den körningen istället för att ha den avstängd som standard.

Filen ligger här och inte i `.claude/` eftersom den katalogen är gitignorerad i ramverksrepot. I ditt
eget projekt är `.claude/settings.json` däremot värd att versionera – den är en del av hur projektet
byggs.

### Om du redigerar prompterna

`prompts/*.txt` innehåller var för sig en rad som säger åt den dispatchade agenten att ignorera
eventuella orkestreringsskills den hittar i repot och aldrig anropa `codex` som subprocess. Tar du
bort den raden kan en dispatchad agent som hittar den kopierade `SKILL.md` försöka köra flödet själv
och spawna nästlade processer. Observerat i skarpt bruk – behåll raden.

---

## 3. Projektets `.gitignore`

```gitignore
docs/plans/.runs/
```

Råutdata från dispatcherna – kritik, byggloggar, verifieringsrapporter – är lokalt arbetsmaterial.
Körjournalen (`docs/plans/*.run.md`) är däremot committad: den är överlämningsytan, och en molnagent
ser bara det som är pushat.

---

## 4. Verifiera uppsättningen

```bash
aimux profile list
CODEX_HOME="$HOME/.aimux/profiles/reasoning" codex exec -s read-only -a never \
  "Answer with one word: ok"
```

Går den igenom utan att fråga om lov är approval-policyn rätt satt. Frågar den – eller hänger – är
det den frågan som annars hade stoppat ett obevakat bygge klockan tre på natten.

---

*Clarity Framework – Uppsättning för planstyrt bygge*
