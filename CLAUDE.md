# CLAUDE.md

## Clarity Framework – AI-instruktioner för detta repo

> Läses automatiskt av Claude Code och Claude Cowork.  
> Gäller förvaltning av ramverket självt – inte för projekt som använder det.

---

## Vad detta repo är

Clarity Framework är ett metodagnostiskt dokumentationsramverk för mjukvaruutveckling. Fungerar för alla skalor – från ett personligt sidoprojekt till ett team på 20 personer. AI-assistans är ett valfritt lager, inte en förutsättning.

**Tre kärnprinciper:** Just enough documentation · Dokumentation som kod · Klarhet framför fullständighet

**Nuvarande version:** 1.3.0

**Repo-struktur:**

```text
/framework/    – Ramverkets egna dokument (guide, CHANGELOG, instruktioner)
/templates/    – Mallar att kopiera till ett projekts /docs
/agents/       – AGENTS.md-starters per stack
/skills/       – Skills att kopiera till ett projekts .claude/skills
```

---

## Språkkonvention

Regeln avgörs av vem som är primär läsare, inte av filtyp:

| Innehåll | Språk | Varför |
| --- | --- | --- |
| `agents/*.md`, `skills/*/SKILL.md` | Engelska | Läses primärt av en AI-agent som exekverar instruktionerna, inte av dig löpande. Engelska ger mindre tvetydighet för modellen och matchar hur skill-beskrivningar tolkas av agentkörtider. |
| `templates/*.md`, ramverkets egna guider (`framework/`, `README.md`, `CLAUDE.md`) | Svenska | Läses och godkänns av dig eller andra människor – planen i `templates/plan.md` visas t.ex. explicit för användaren innan bygge startar. |

En skill eller starter som byter primär läsare (blir ett dokument du själv fyller i och godkänner) byter språk med den. Filnamnet `SKILL.md`/`AGENTS.md` avgör inte språket – syftet gör.

---

## Commit-disciplin

Solo direkt på `main`. En commit = en meningsfull, komplett enhet av förändring.

**Format:** `[typ] Kort beskrivning i imperativ form`

| Typ | När |
| --- | --- |
| `patch` | Korrigeringar, stavfel, förtydliganden |
| `minor` | Ny sektion, ny mall, nytt dokument |
| `major` | Breaking change – befintliga ifyllda dokument påverkas |
| `docs` | Ändringar i `/framework` som inte är mallar |
| `chore` | Repo-underhåll, skriptjusteringar |

**En commit är inte klar om:**

- CHANGELOG saknar entry för förändringen
- Berörda mallar och guide inte är konsekvent uppdaterade

**Vad som alltid committas tillsammans:**

| Förändring | Måste inkludera |
| --- | --- |
| Mallförändring | Mall + eventuell guidejustering |
| `templates/plan.md` | Även `skills/planstyrt-bygge/plan-mall.md` – skillen bär en egen kopia eftersom den kopieras ut ensam |
| Ny mall | Ny fil + README + CHANGELOG-entry |
| Riktlinjeändring i guiden | Guiden + berörda mallar |
| Release | CHANGELOG + versionsnummer i alla berörda filer + Git-tagg |

**I slutet av varje session:** sammanfatta förändrade filer, gruppera logiskt, föreslå commit-meddelanden – vänta på godkännande innan commit körs.

---

## Releasestrategi

Explicita, manuellt taggade releases – aldrig automatiska.

```text
MAJOR.MINOR.PATCH
  │     │     └── Korrigeringar (bakåtkompatibelt)
  │     └──────── Nya mallar, sektioner, tillägg (bakåtkompatibelt)
  └────────────── Breaking changes (kräver migrering av ifyllda dokument)
```

**När användaren triggar en release:**

1. Verifiera `git status` är rent
2. Uppdatera `framework/CHANGELOG.md` med ny entry
3. Uppdatera versionsnummer i: `README.md`, `CLAUDE.md`, `framework/dokumentationsguide.md`, `templates/00-ai-context.md`
4. `git add . && git commit -m "[minor|major|patch]: Release vX.Y.Z"`
5. `git tag -a vX.Y.Z -m "Clarity Framework vX.Y.Z – beskrivning"`
6. `git push origin main --tags`

---

*Clarity Framework v1.3.0*
