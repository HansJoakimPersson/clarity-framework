# Visual Profile & Design Tokens

## [Product name]

| | |
| --- | --- |
| **Version** | 0.1 |
| **Status** | Draft / Under review / Approved |
| **Date** | YYYY-MM-DD |
| **Author** | [Name] |
| **Token file** | `design/tokens.json` |

## 1. Brand foundations

### Logo

| Variant | File | Usage |
| --- | --- | --- |
| Primary | `design/assets/logo/logo-primary.svg` | Light backgrounds |
| Inverted | `design/assets/logo/logo-inverted.svg` | Dark backgrounds |
| Symbol | `design/assets/logo/symbol.svg` | App icon, favicon |

**Clear space:** [Minimum clear space]
**Minimum size:** [Minimum size]
**Prohibited use:** [Stretching, rotation, alternate colors, low-resolution rendering]

### Color

| Role | Token | Reference value | Usage |
| --- | --- | --- | --- |
| Primary | `color.brand.primary.500` | `#[hex]` | Primary actions and links |
| Secondary | `color.brand.secondary.500` | `#[hex]` | Supporting accents |
| Surface | `color.neutral.0` | `#[hex]` | Main surface |
| Text | `color.neutral.900` | `#[hex]` | Body text and headings |
| Success | `color.semantic.success` | `#[hex]` | Success messages |
| Warning | `color.semantic.warning` | `#[hex]` | Warnings |
| Error | `color.semantic.error` | `#[hex]` | Errors |

All text/background combinations must meet WCAG 2.2 AA. Record critical contrast ratios here.

## 2. Typography and layout

| Role | Token | Font | Weight | Size | Line height |
| --- | --- | --- | --- | --- | --- |
| Body | `type.body` | [Font] | [Weight] | [Size] | [Line height] |
| Heading | `type.heading` | [Font] | [Weight] | [Size] | [Line height] |

| Token | Value | Usage |
| --- | --- | --- |
| `spacing.1` | 4px | [Usage] |
| `spacing.2` | 8px | [Usage] |
| `spacing.4` | 16px | Standard padding and gaps |
| `radius.md` | [Value] | [Usage] |
| `shadow.md` | [Value] | [Usage] |

## 3. Motion, imagery, and iconography

**Motion:** [Durations, easing, and reduced-motion behavior]
**Photography:** [Allowed style, mood, and subjects]
**Icons:** [Library, variant, size, and usage rules]

Respect `prefers-reduced-motion`; reduce or disable non-essential animation when requested.

## 4. DTCG token source

Store tokens in `design/tokens.json` or the project's chosen source path. The source is versioned in
Git and is the single source of truth. Generated platform files must never be edited manually.

```json
{
  "color": {
    "brand": {
      "primary": {
        "500": {
          "$value": "#000000",
          "$type": "color",
          "$description": "Primary brand color"
        }
      }
    }
  }
}
```

## 5. Transformation and ownership

| Target | Output | Tool |
| --- | --- | --- |
| Web CSS | `dist/tokens.css` | [Tool] |
| Web JS/TS | `dist/tokens.js` | [Tool] |
| iOS/iPadOS | `Sources/DesignTokens/` | [Tool] |
| macOS | `Sources/DesignTokens/` | [Tool] |

**Owner:** [Name / role]
**Design reference:** [Figma / Storybook link]
**Update trigger:** Token changes; generated files are [committed / not committed].

## 6. Visual UX verification (required)

Tokens compiling is not visual validation. Every meaningful UI change must be inspected in the
running product at supported viewport sizes and interaction states.

Check initial, loading, empty, error, success, disabled, focused, hovered, and keyboard-navigation
states as relevant. Check responsive layout, typography, spacing, alignment, overflow, hierarchy,
keyboard access, focus visibility, contrast, reduced motion, and screen-reader landmarks.

Attach screenshots or an equivalent rendered comparison for every changed surface. Record viewport,
device/browser, date, journey, reviewer, and unresolved differences. Automated tests and accessibility
scans support but do not replace human inspection.

## 7. Definition of Done

- [ ] Visual profile is approved before UI implementation.
- [ ] Tokens are the source of truth and generated outputs are reproducible.
- [ ] Contrast and reduced-motion requirements are documented.
- [ ] Every UI change includes rendered visual evidence and human review.

---

*Clarity Framework v3.1.0 – Visual Profile & Design Tokens*
