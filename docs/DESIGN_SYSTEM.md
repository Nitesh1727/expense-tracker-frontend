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

Palette is warm-neutral (ivory/paper in light, warm charcoal in dark), not
cool gray — matches the Claude app's own palette per explicit user request
("make it look exactly like the Claude app... clean and minimal").

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `background` | `#FAF9F5` | `#262624` | Screen background |
| `surface` | `#FFFFFF` | `#30302E` | Cards, sheets |
| `primary` | `#CC5F3B` (terracotta/orange) | `#E8875F` | Primary actions. Originally a green ("money/finance" association) — swapped to this warm orange per explicit user request (Claude's own accent color). |
| `onPrimary` | `#FFFFFF` | `#2B190E` | Text/icons on primary |
| `textPrimary` | `#2D2A26` | `#F2F0EA` | Main text |
| `textSecondary` | `#7A776D` | `#A8A599` | Secondary/meta text |
| `border` | `#E8E5DD` | `#3E3D38` | Dividers, input borders |
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

## Elevation

Flat, not drop-shadowed. Cards, buttons, and sheets use a hairline `border`
and little-to-no shadow rather than Material's default elevation shadows —
this reads as calm and considered rather than "decorated," matching the
Claude app. The FAB is the one exception (elevation 1, so it still reads as
floating above the content), and bottom sheets are a flat solid surface with
a drag handle — no backdrop blur/glass effect.

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

Bottom nav, 3 tabs in a swipeable `PageView` (not just tappable) — each a
genuinely distinct destination, kept minimal on purpose. Profile is
deliberately **not** a 4th tab: it's a top-right avatar icon in the shared
AppBar, pushed as a normal route, since it's account-management rather than
something reached constantly like the 3 tabs are.

1. **Home** — switchable period total (Today/This week/This month, default
   month) in a rectangular `AmountTile`, quick-add FAB, recent expenses as
   collapsible day-tiles (closed by default, showing date + total; tap to
   expand and lazily load that day's items), paginated by day as you scroll.
   The filter icon opens the full expense history/log screen (category
   filter, edit, delete) — a pushed route, not its own tab, since it's a
   drill-down of Home rather than a separate concern.
2. **Analytics** — period selector (Day/Week/Month/Year) with prev/next
   navigation and a clear "which period" label, total in an `AmountTile`,
   category breakdown list, CSV export (scoped to whatever period is showing,
   or a custom date range). Deliberately no charts — removed per explicit
   user feedback ("keep this simple").
3. **Categories** — list of the user's categories with CRUD (add/edit/delete).

**Profile** (pushed, not a tab) — account info + edit, display settings
(theme mode, text size, font), logout, delete account.

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
