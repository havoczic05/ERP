# Design

Visual system for the ERP. Register: **product** (internal tool — design serves
the task). Strategy: **Restrained**. Source of truth is
`app/assets/stylesheets/app.css`; this document explains the intent.

## Theme

Sober, calm, precise — "a well-organized desk," not a flashy dashboard. Pure
white content surface with a **botanical-green** brand identity and a semantic
state palette. Warmth and life come from the brand color, typography, and
spacing — **never** from gray mush or harsh spreadsheet gridlines (the two
anti-references). Light mode only for now.

## Color (OKLCH)

The brand green reads as *confirmed / financial / trustworthy* — apt for a system
that handles money. White carries legibility; green carries identity.

| Role | Token | Value | Use |
| --- | --- | --- | --- |
| Brand | `--brand` | `oklch(0.46 0.110 160)` | primary actions, links, active, chart bars |
| Brand hover | `--brand-hover` | `oklch(0.40 0.110 160)` | hover/pressed |
| Brand weak | `--brand-weak` | `oklch(0.96 0.030 160)` | row hover, focus ring, selection |
| Background | `--bg` | `oklch(1 0 0)` | content surface (pure white) |
| Surface | `--surface` / `--surface-2` | `0.985 / 0.967 …160` | zebra rows, header, panels |
| Ink | `--ink` | `oklch(0.24 0.012 160)` | body text (~13:1 on white) |
| Ink soft | `--ink-soft` | `oklch(0.40 0.012 160)` | strong secondary, labels |
| Muted | `--muted` | `oklch(0.50 0.014 160)` | captions, table headers |
| Lines | `--line` / `--line-strong` | `0.915 / 0.845 …160` | soft dividers |

**Semantic states** — each has a fill, a weak tint (badge/pill bg), and an ink
(text on the tint). Mapped to domain states:

| State | Maps to | Tokens |
| --- | --- | --- |
| Success | confirmada, pagada | `--success`, `--success-weak`, `--success-ink` |
| Danger | anulada, cuota vencida | `--danger`, `--danger-weak`, `--danger-ink` |
| Warning | bajo stock, pendiente | `--warning`, `--warning-weak`, `--warning-ink` |
| Info | neutral info | `--info`, `--info-weak`, `--info-ink` |

Color is never the only signal — pair with a label/icon (a11y).

## Typography

One sans family (`system-ui` stack) for everything — headings, labels, body,
data. No display/body pairing. **Fixed rem scale** (ratio ~1.2), not fluid —
product UI is viewed at consistent DPI.

- Scale: `--text-xs 12` · `sm 13` · `base 15` · `md 17` · `lg 20` · `xl 24` · `2xl 32`.
- Weights: 400 body · 500 medium (labels, buttons, nav) · 600 semibold (headings).
- Line height: 1.55 body, 1.25 headings. `text-wrap: balance` on headings.
- **Tabular figures** (`font-variant-numeric: tabular-nums`) on all numeric/money
  data so columns align — a core requirement for a financial tool.

## Spacing & shape

- 4px base scale: `--sp-1…8` (4, 8, 12, 16, 24, 32, 48px).
- Radii: `--r-sm 4` · `--r 6` · `--r-lg 10`. Shadows are restrained (`--shadow-sm/-`).
- Content container: max-width `1100px`, centered.

## Components

- **Header / nav**: top bar on `--surface-2`, medium-weight links, admin-only
  items gated in the view. Logout pushed right (`.nav-spacer`).
- **Tables** (core UI): uppercase micro headers, soft lines, zebra rows, hover,
  tabular figures. Add `.num` to right-align currency columns.
- **Forms**: one control vocabulary; brand focus ring (`box-shadow` + border).
- **Buttons**: filled `--brand` primary (white text); `.btn--ghost` neutral;
  `.btn--danger` for destructive actions (e.g. Annul). `button_to` forms inherit.
- **Badges** (`.badge` + `--success/danger/warning/info`): weak tint + ink text,
  for status pills (document status, installment state).
- **Flash**: `.flash-notice` (success tint) / `.flash-alert` (danger tint).
- **Charts**: inline SVG bars filled with `--brand` (`rect.bar`).

## Motion & accessibility

Target **WCAG AA**. Transitions 150ms, state-only (hover/focus) — no decorative
choreography. `prefers-reduced-motion` honored globally. `:focus-visible` ring on
all interactive elements.

## Bans (this project)

No side-stripe accent borders, no gradient text, no glassmorphism, no harsh
black gridlines (the "Excel" anti-reference), no flat-gray-everything (the
"government form" anti-reference).
