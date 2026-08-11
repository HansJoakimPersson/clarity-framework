# Grafisk profil & Design Tokens

## [Produktnamn]

| | |
| --- | --- |
| **Version** | 0.1 |
| **Status** | Utkast / Under granskning / Godkänd |
| **Datum** | ÅÅÅÅ-MM-DD |
| **Författare** | [Namn] |
| **Token-fil** | `design/tokens.json` |

### Versionshistorik

| Version | Datum | Förändring | Författare |
| --- | --- | --- | --- |
| 0.1 | ÅÅÅÅ-MM-DD | Initial version | [Namn] |

> **När används detta dokument?**
> Grafisk profil är ett ingångsvärde – det ska vara godkänt innan UI-kodning påbörjas. Det gäller alla projekt
> med ett visuellt gränssnitt: webb, iOS/iPadOS, macOS eller annat. Design tokens i DTCG-format gör profilen
> maskinläsbar och möjliggör automatiserad transformation till CSS, Swift, Kotlin och andra målplattformar.

---

## 1. Varumärkesgrunder

### Logotyp

| Variant | Fil | Användning |
| --- | --- | --- |
| Primär (färg) | `design/assets/logo/logo-primary.svg` | Ljus bakgrund |
| Inverterad (vit) | `design/assets/logo/logo-inverted.svg` | Mörk bakgrund |
| Symbol | `design/assets/logo/symbol.svg` | App-ikon, favicon |

**Frizon:** [Beskriv minsta frizon runt logotypen, t.ex. "Minst lika stor som bokstavshöjden på alla sidor"]  
**Minsta storlek:** [t.ex. "32 px bred för digital användning"]  
**Otillåten användning:** [t.ex. Sträckning, rotation, alternativa färger, lågupplöst rendering]

### Färgpalett

Alla färger definieras som design tokens (se avsnitt 3). Dokumentera semantisk avsikt här.

| Roll | Token | Hex (referens) | Användning |
| --- | --- | --- | --- |
| Primär | `color.brand.primary.500` | `#[hex]` | Primära knappar, aktiva element, länkar |
| Primär hover | `color.brand.primary.600` | `#[hex]` | Hover- och fokustillstånd för primära element |
| Sekundär | `color.brand.secondary.500` | `#[hex]` | Sekundära knappar, kompletterande accenter |
| Yta (ljus) | `color.neutral.0` | `#ffffff` | Sidabakgrund, kortar, modaler |
| Yta (mörk) | `color.neutral.900` | `#[hex]` | Mörkt läge – primär bakgrund |
| Text primär | `color.neutral.900` | `#[hex]` | Brödtext och rubriker |
| Text sekundär | `color.neutral.500` | `#[hex]` | Ledtext, metadata, hjälptext |
| Gräns | `color.neutral.200` | `#[hex]` | Dividers, inputramar |
| Framgång | `color.semantic.success` | `#[hex]` | Bekräftelser, framgångsmeddelanden |
| Varning | `color.semantic.warning` | `#[hex]` | Varningsmeddelanden |
| Fel | `color.semantic.error` | `#[hex]` | Felmeddelanden, destruktiva åtgärder |
| Info | `color.semantic.info` | `#[hex]` | Informationsrutor |

**Tillgänglighet:** Alla text–bakgrundskombinationer ska uppfylla WCAG 2.2 AA-kontrastkrav (4,5:1 för normal
text, 3:1 för stor text och UI-komponenter). Dokumentera kontrastkvoter för kritiska kombinationer nedan.

| Kombination | Kvot | WCAG AA |
| --- | --- | --- |
| Text primär på yta (ljus) | [X.X]:1 | ✓ / ✗ |
| Text sekundär på yta (ljus) | [X.X]:1 | ✓ / ✗ |
| Primär knapp (text på brand-500) | [X.X]:1 | ✓ / ✗ |

### Typografi

| Roll | Token | Teckensnitt | Snitt | Storlek | Radavstånd |
| --- | --- | --- | --- | --- | --- |
| Rubrik 1 | `typography.heading.h1` | [Teckensnitt] | Bold | [X]px / [X]rem | [X] |
| Rubrik 2 | `typography.heading.h2` | [Teckensnitt] | SemiBold | [X]px | [X] |
| Rubrik 3 | `typography.heading.h3` | [Teckensnitt] | SemiBold | [X]px | [X] |
| Brödtext | `typography.body.md` | [Teckensnitt] | Regular | [X]px | [X] |
| Liten text | `typography.body.sm` | [Teckensnitt] | Regular | [X]px | [X] |
| Kod | `typography.code` | [Monospace] | Regular | [X]px | [X] |

**Teckensnittsladdning:** [Beskriv hur teckensnitten laddas – systemteckensnitt, Google Fonts, self-hosted, SF Pro
på Apple-plattformar. Dokumentera fallback-stack.]

### Bildspråk och ikonografi

**Fotografi:** [Stil, känslor, motiv som är tillåtna/otillåtna]  
**Illustration:** [Stil om illustration används]  
**Ikoner:** [Ikonbibliotek och variant, t.ex. "Heroicons Outline 24px" eller "SF Symbols 3"]  
**Ikonformat:** [SVG / PNG / SF Symbols. Beskriv storlekar och användningsprinciper]

---

## 2. Komponentprinciper

> Beskriv designsystemets övergripande principer. Länka till Figma, Storybook eller annat komponentbibliotek.

**Designsystem-referens:** [Länk till Figma / Storybook / annat]  
**Komponentbibliotek i kod:** [Länk till repo / paket, om det finns]

### Spacing-system

Alla avstånd baseras på en grundenhet. Token-värden definieras i avsnitt 3.

| Token | Värde | Användning |
| --- | --- | --- |
| `spacing.1` | 4px | Mikroavstånd, interna komponentavstånd |
| `spacing.2` | 8px | Inre padding i täta komponenter |
| `spacing.3` | 12px | — |
| `spacing.4` | 16px | Standard padding och gap |
| `spacing.6` | 24px | Sektionsavstånd |
| `spacing.8` | 32px | Större layoutavstånd |
| `spacing.12` | 48px | Sektionsgap på desktop |
| `spacing.16` | 64px | Hero-avstånd |

### Radier

| Token | Värde | Användning |
| --- | --- | --- |
| `radius.sm` | [X]px | Inputs, tags |
| `radius.md` | [X]px | Knappar, kort |
| `radius.lg` | [X]px | Modaler, paneler |
| `radius.full` | 9999px | Pills, avatarer |

### Skuggor (Elevation)

| Token | Värde | Användning |
| --- | --- | --- |
| `shadow.sm` | `[CSS-värde]` | Subtil elevation, kort |
| `shadow.md` | `[CSS-värde]` | Dropdowns, tooltips |
| `shadow.lg` | `[CSS-värde]` | Modaler, drawer |

### Rörelse och animation

| Token | Värde | Användning |
| --- | --- | --- |
| `motion.duration.fast` | 100ms | Mikrointeraktioner, hover |
| `motion.duration.normal` | 200ms | Standardövergångar |
| `motion.duration.slow` | 400ms | Sidövergångar, modaler |
| `motion.easing.default` | `ease-in-out` | Generell övergång |
| `motion.easing.enter` | `ease-out` | Element som dyker upp |
| `motion.easing.exit` | `ease-in` | Element som försvinner |

**Tillgänglighet:** Respektera `prefers-reduced-motion`. Alla animationer ska inaktiveras eller minskas
avsevärt när användaren begärt reducerad rörelse.

---

## 3. Design Tokens – DTCG-format

> Tokens lagras i `design/tokens.json` (eller den sökväg projektet använder) enligt
> [DTCG Format Module 2025.10](https://www.designtokens.org/TR/2025.10/format/), en stabil
> W3C Community Group-specifikation (inte en W3C Recommendation).
> Filen är källan till sanning för alla visuella värden och ska versioneras i Git.

### Filstruktur

```
design/
├── tokens.json          ← Källfil i DTCG-format (redigeras manuellt eller exporteras från Figma)
├── tokens/              ← Valfritt: uppdelad per kategori för stora projekt
│   ├── color.json
│   ├── typography.json
│   └── spacing.json
└── assets/
    └── logo/
```

### Token-format (DTCG)

Varje token följer strukturen `{ "$value": ..., "$type": ..., "$description": ... }`.
Grupper bildas genom nästlade objekt. Alias-referenser skrivs med klammernotation: `{group.token}`.

```json
{
  "color": {
    "brand": {
      "primary": {
        "500": {
          "$value": { "colorSpace": "srgb", "components": [0.12, 0.31, 0.78] },
          "$type": "color",
          "$description": "Primär varumärkesfärg – används för knappar, länkar och aktiva tillstånd"
        },
        "600": {
          "$value": { "colorSpace": "srgb", "components": [0.08, 0.24, 0.64] },
          "$type": "color",
          "$description": "Hover- och aktivt tillstånd för primärfärgen"
        }
      }
    },
    "neutral": {
      "0":   { "$value": { "colorSpace": "srgb", "components": [1, 1, 1] }, "$type": "color" },
      "100": { "$value": { "colorSpace": "srgb", "components": [0.94, 0.95, 0.97] }, "$type": "color" },
      "200": { "$value": { "colorSpace": "srgb", "components": [0.86, 0.88, 0.91] }, "$type": "color" },
      "500": { "$value": { "colorSpace": "srgb", "components": [0.42, 0.45, 0.5] }, "$type": "color" },
      "900": { "$value": { "colorSpace": "srgb", "components": [0.08, 0.1, 0.14] }, "$type": "color" }
    },
    "semantic": {
      "success": { "$value": { "colorSpace": "srgb", "components": [0.08, 0.55, 0.3] }, "$type": "color" },
      "warning": { "$value": { "colorSpace": "srgb", "components": [0.9, 0.55, 0.05] }, "$type": "color" },
      "error":   { "$value": { "colorSpace": "srgb", "components": [0.78, 0.12, 0.16] }, "$type": "color" },
      "info":    { "$value": "{color.brand.primary.500}", "$type": "color" }
    }
  },
  "font": {
    "family": {
      "sans": { "$value": ["Inter", "system-ui", "sans-serif"], "$type": "fontFamily" },
      "mono": { "$value": ["SFMono-Regular", "Consolas", "monospace"], "$type": "fontFamily" }
    },
    "size": {
      "sm":  { "$value": { "value": 14, "unit": "px" }, "$type": "dimension" },
      "md":  { "$value": { "value": 16, "unit": "px" }, "$type": "dimension" },
      "lg":  { "$value": { "value": 18, "unit": "px" }, "$type": "dimension" },
      "xl":  { "$value": { "value": 24, "unit": "px" }, "$type": "dimension" },
      "2xl": { "$value": { "value": 30, "unit": "px" }, "$type": "dimension" },
      "3xl": { "$value": { "value": 36, "unit": "px" }, "$type": "dimension" }
    },
    "weight": {
      "regular":  { "$value": 400, "$type": "fontWeight" },
      "medium":   { "$value": 500, "$type": "fontWeight" },
      "semibold": { "$value": 600, "$type": "fontWeight" },
      "bold":     { "$value": 700, "$type": "fontWeight" }
    }
  },
  "line": {
    "height": {
      "tight":  { "$value": 1.25, "$type": "number" },
      "normal": { "$value": 1.5,  "$type": "number" },
      "loose":  { "$value": 1.75, "$type": "number" }
    }
  },
  "spacing": {
    "1":  { "$value": { "value": 4, "unit": "px" },  "$type": "dimension" },
    "2":  { "$value": { "value": 8, "unit": "px" },  "$type": "dimension" },
    "3":  { "$value": { "value": 12, "unit": "px" }, "$type": "dimension" },
    "4":  { "$value": { "value": 16, "unit": "px" }, "$type": "dimension" },
    "6":  { "$value": { "value": 24, "unit": "px" }, "$type": "dimension" },
    "8":  { "$value": { "value": 32, "unit": "px" }, "$type": "dimension" },
    "12": { "$value": { "value": 48, "unit": "px" }, "$type": "dimension" },
    "16": { "$value": { "value": 64, "unit": "px" }, "$type": "dimension" }
  },
  "radius": {
    "sm":   { "$value": { "value": 4, "unit": "px" }, "$type": "dimension" },
    "md":   { "$value": { "value": 8, "unit": "px" }, "$type": "dimension" },
    "lg":   { "$value": { "value": 12, "unit": "px" }, "$type": "dimension" },
    "full": { "$value": { "value": 9999, "unit": "px" }, "$type": "dimension" }
  },
  "shadow": {
    "sm": {
      "$value": {
        "color":    "{color.neutral.900}",
        "offsetX":  { "value": 0, "unit": "px" },
        "offsetY":  { "value": 1, "unit": "px" },
        "blur":     { "value": 2, "unit": "px" },
        "spread":   { "value": 0, "unit": "px" }
      },
      "$type": "shadow"
    },
    "md": {
      "$value": {
        "color":    "{color.neutral.900}",
        "offsetX":  { "value": 0, "unit": "px" },
        "offsetY":  { "value": 4, "unit": "px" },
        "blur":     { "value": 6, "unit": "px" },
        "spread":   { "value": -1, "unit": "px" }
      },
      "$type": "shadow"
    }
  },
  "motion": {
    "duration": {
      "fast":   { "$value": { "value": 100, "unit": "ms" }, "$type": "duration" },
      "normal": { "$value": { "value": 200, "unit": "ms" }, "$type": "duration" },
      "slow":   { "$value": { "value": 400, "unit": "ms" }, "$type": "duration" }
    },
    "easing": {
      "default": { "$value": [0.42, 0, 0.58, 1], "$type": "cubicBezier" },
      "enter":   { "$value": [0, 0, 0.58, 1],    "$type": "cubicBezier" },
      "exit":    { "$value": [0.42, 0, 1, 1],    "$type": "cubicBezier" }
    }
  }
}
```

---

## 4. Plattformstransformation

> Token-filen transformeras till plattformsspecifika format via ett byggsteg.
> [Style Dictionary](https://styledictionary.com) (Amazon) är rekommenderat verktyg och stöder DTCG-format.

| Målplattform | Utdataformat | Fil | Verktyg |
| --- | --- | --- | --- |
| Webb (CSS) | Custom properties | `dist/tokens.css` | Style Dictionary |
| Webb (JS/TS) | ES-modul | `dist/tokens.js` | Style Dictionary |
| iOS/iPadOS | Swift Color/Font extensions | `Sources/DesignTokens/` | Style Dictionary |
| macOS | Swift Color/Font extensions | `Sources/DesignTokens/` | Style Dictionary |
| [Övrig plattform] | [Format] | [Sökväg] | [Verktyg] |

**Byggkommando:** `[t.ex. npx style-dictionary build --config sd.config.json]`  
**Kör vid:** Token-ändringar. Genererade filer versioneras [i / inte i] repo.

> Genererade token-filer ska aldrig redigeras manuellt. Redigera alltid `design/tokens.json` och kör om
> transformationen.

---

## 5. Ägarskap och underhållsprocess

**Ägare:** [Namn / roll som äger den grafiska profilen]  
**Designsystem-referens:** [Länk till Figma, Zeplin eller annat designverktyg]

### Hur tokens uppdateras

1. Förändring initieras i designverktyget (t.ex. Figma via Tokens Studio) eller direkt i `design/tokens.json`
2. PR öppnas mot `main` – token-ändringar granskas som vilken kodändring som helst
3. Transformationspipelinen körs och genererade filer uppdateras
4. PR godkänns och mergas
5. Berörda teams informeras om ändringar som påverkar befintliga komponenter

### Breaking changes i tokens

En token-ändring är en breaking change om den:
- Byter namn på eller tar bort en befintlig token
- Ändrar ett värde på ett sätt som kan bryta kontrast- eller layoutkrav

Breaking changes dokumenteras som ADR i `docs/03-sad.md` och kommuniceras explicit.

---

*Clarity Framework v1.5.1 – Grafisk profil & Design Tokens*
