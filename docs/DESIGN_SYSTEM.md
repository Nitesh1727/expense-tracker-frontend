# Design System

Design is the #1 priority on this project — smooth, minimal, spacious, high
production quality. This doc is the source of truth for tokens so the app
looks like one coherent system instead of per-screen improvisation. Every
value here becomes a constant in `lib/core/theme/` — screens consume tokens,
never hardcoded values.

This is a first-pass starting point, tunable without restructuring anything —
treat the actual values as a draft to refine visually once real screens
exist, not as locked-in decisions.

## Color

Light and dark mode both required (this is standard on modern polished apps
and low-cost to do if tokens are used consistently from the start).

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `background` | `#FAFAFA` | `#121212` | Screen background |
| `surface` | `#FFFFFF` | `#1E1E1E` | Cards, sheets |
| `primary` | `#16A34A` (green) | `#22C55E` | Primary actions, positive/expense-saved states — green reads as "money/finance" without being a bank-navy cliché |
| `onPrimary` | `#FFFFFF` | `#0B1F14` | Text/icons on primary |
| `textPrimary` | `#111827` | `#F5F5F5` | Main text |
| `textSecondary` | `#6B7280` | `#A1A1AA` | Secondary/meta text |
| `border` | `#E5E7EB` | `#2A2A2A` | Dividers, input borders |
| `error` | `#DC2626` | `#F87171` | Validation errors, delete actions |

**Category colors** — each of the 7 fixed categories gets a distinct accent
used for its chip/icon/chart segment, chosen for distinctness + accessible
contrast, not literal meaning:
`Food` amber, `Transport` blue, `Shopping` violet, `Bills` red-orange,
`Entertainment` pink, `Health` teal, `Other` gray. Exact hex values to be
finalized in `core/theme/colors.dart` alongside `core/constants/categories.dart`
so each category's color lives next to its icon/label.

## Typography

`google_fonts` — recommend **Inter** or **Manrope** (both are the current
default choice for clean fintech/consumer apps; pick by eye once a screen is
up, this is a cheap decision to change later since it's one config line).

| Style | Size | Weight | Use |
|-------|------|--------|-----|
| `displayLarge` | 32 | 700 | Big numbers — e.g. total spend on analytics screen |
| `headline` | 22 | 600 | Screen titles |
| `title` | 17 | 600 | Card/section titles |
| `body` | 15 | 400 | Default text |
| `bodyStrong` | 15 | 600 | Emphasized body (e.g. amount in a list row) |
| `caption` | 13 | 400 | Secondary/meta text (dates, category labels) |

## Spacing scale

4px base unit — every margin/padding in the app is one of these, no
arbitrary numbers:

```
xs = 4   sm = 8   md = 16   lg = 24   xl = 32   xxl = 48
```

"Spacious" comes from generous use of `lg`/`xl` between sections and
consistent `md` internal padding — not from one-off large numbers per screen.

## Radius

```
sm = 8    (chips, small buttons)
md = 16   (cards, input fields)
lg = 24   (bottom sheets, modals)
full = 999 (pills, avatar)
```

## Motion

Consistency here is what actually reads as "smooth premium app" — not any
single flashy animation.

| Token | Duration | Curve | Use |
|-------|----------|-------|-----|
| `fast` | 150ms | `easeOut` | Micro-interactions (button press, chip select) |
| `standard` | 250ms | `easeInOut` | Screen element transitions, expand/collapse |
| `emphasized` | 400ms | `easeInOutCubic` | Page transitions, bottom sheet open/close |

Rules of thumb:
- List items animate in with a subtle staggered fade+slide on first load
  (`flutter_animate`), not on every rebuild.
- Numbers (totals, analytics) animate when they change value rather than
  snapping — reinforces the "alive" feel.
- Bottom sheets (add/edit expense) slide up with `emphasized`, dismiss with
  `standard`.
- Never animate for animation's sake — if a transition doesn't help the user
  understand what changed, it's noise.

## Component notes

- **Add expense** is a bottom sheet, not a full-screen route — keeps it fast
  (one thumb-reachable tap to open, swipe down to dismiss) and matches the
  "minimal fields, quick entry" goal.
- **Expense list rows**: category icon (colored per the token above) +
  description + amount, date as secondary text. No visual clutter beyond
  that — resist adding a second line of metadata unless asked.
- **Analytics**: period selector as a segmented control (Day/Week/Month/Year),
  total as the largest element on screen (`displayLarge`), category breakdown
  as a simple horizontal bar list or donut chart (`fl_chart`) below it.
