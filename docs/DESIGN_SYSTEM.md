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

**Category colors & icons** — categories are user-CRUD-able (see
`backend/docs/DATABASE.md`), so color and icon are a *curated pick*, not a
free picker — keeps every user's category list visually consistent instead
of ending up with clashing custom colors. The create/edit category sheet
shows a fixed swatch grid and a fixed icon grid; the user picks from each.

Curated color palette (10 swatches, used for both category colors and chart
segments):

| Name | Hex |
|------|-----|
| amber | `#F59E0B` |
| blue | `#3B82F6` |
| violet | `#8B5CF6` |
| red-orange | `#EF4444` |
| pink | `#EC4899` |
| teal | `#14B8A6` |
| gray | `#6B7280` |
| green | `#22C55E` |
| indigo | `#6366F1` |
| brown | `#92400E` |

Curated icon set (Material icon keys — the app maps each key to an
`IconData` in `core/constants/categories.dart`; the backend only ever stores
the string key, never an icon asset):

`restaurant`, `directions_car`, `shopping_bag`, `receipt_long`, `movie`,
`favorite`, `category`, `home`, `flight`, `school`, `fitness_center`,
`pets`, `local_grocery_store`, `sports_esports`, `local_hospital`, `coffee`.

Default seeded categories (created for every new user at signup — see
backend DATABASE.md) use the same icon/color values listed there: Food
(amber/restaurant), Transport (blue/directions_car), Shopping
(violet/shopping_bag), Bills (red-orange/receipt_long), Entertainment
(pink/movie), Health (teal/favorite), Other (gray/category, not deletable).

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

## Navigation

Bottom nav, 4 tabs — each a genuinely distinct destination, kept minimal on
purpose:

1. **Home** — today's total, quick-add entry point, recent expenses grouped
   into `Today` / `Yesterday` / `Earlier this week` sections. "View all"
   from here opens the full expense history/log screen (filters, edit,
   delete) — that history list is a pushed route, not its own tab, since it's
   a drill-down of Home rather than a separate concern.
2. **Analytics** — period selector (Day/Week/Month/Year), total, pie/donut
   chart by category, trend chart over the period.
3. **Categories** — list of the user's categories with CRUD (add/edit/delete).
4. **Profile** — account info, logout, delete account, CSV export action.

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
