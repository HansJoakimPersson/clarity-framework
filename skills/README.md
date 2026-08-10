# Skills – återanvändbara arbetsflöden för Claude Code

Den här katalogen innehåller färdiga skills att kopiera in i ett projekt när flödet behövs. De är
startpunkter att anpassa – inte normerande standarder.

---

## Vad är en skill?

En skill är ett namngivet arbetsflöde som Claude Code kan anropa. Den skiljer sig från övriga
Clarity Framework-dokument i vad den svarar på:

| Dokument | Svarar på |
| --- | --- |
| `docs/00-ai-context.md` | Vad är projektet? |
| `AGENTS.md` | Hur ska agenten arbeta här, alltid? |
| `.claude/skills/*/SKILL.md` | Hur körs det här specifika flödet, när det körs? |

`AGENTS.md` gäller varje uppgift. En skill gäller bara när den anropas.

---

## Tillgängliga skills

| Katalog | Passar när... |
| --- | --- |
| `planstyrt-bygge/` | Uppgiften är stor nog att omfattningen behöver godkännas innan kod skrivs, och du vill att Claude Code planerar medan Codex bygger |

---

## Så använder du en

1. Kopiera katalogen till projektets `.claude/skills/`:

   ```bash
   cp -r skills/planstyrt-bygge /sökväg/till/projektet/.claude/skills/
   ```

2. Anpassa `SKILL.md` efter projektet – kommandon, verktyg och sökvägar skiljer sig åt.
3. Anropa den i Claude Code med `/planstyrt-bygge`.

Skills versioneras i projektrepot som all annan dokumentation som kod.

---

## Vad som gäller före vad

Samma prioritetsordning som för `agents/`:

1. Uttrycklig instruktion från användaren i sessionen
2. Projektets `AGENTS.md`
3. Skillens `SKILL.md`
4. Projektets `docs/`

En skill som motsäger projektets `AGENTS.md` ska anpassas, inte följas.

---

*Clarity Framework v1.3.0*
