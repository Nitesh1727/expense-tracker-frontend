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
| `primary` | `#CC5F3B` (terracotta/orange) | `#E8875F` | Primary actions. Originally a green ("money/finance" association) — swapped to this warm orange per explicit user request (Claude's own accent color). Now the *default* of a user-selectable accent — see below. |
| `onPrimary` | `#FFFFFF` | `#20201D` | Text/icons on primary — a shared warm near-black works in dark mode across every accent option below since each dark variant is deliberately a light pastel tint, not hue-tuned individually. |
| `textPrimary` | `#2D2A26` | `#F2F0EA` | Main text |
| `textSecondary` | `#7A776D` | `#A8A599` | Secondary/meta text |
| `border` | `#E8E5DD` | `#3E3D38` | Dividers, input borders |
| `error` | `#DC2626` | `#F87171` | Validation errors, delete actions |

**Accent color** is user-selectable in Settings → Appearance (curated swatches,
not a free color wheel — same reasoning as category colors below: every
option is pre-checked to stay legible rather than letting a choice wash out
the UI). `AppTheme.light()`/`.dark()` take a plain `Color primary` rather
than the enum itself, so `core/theme/` never has to import the settings
feature — `app.dart` resolves `AccentColorOption` to a `Color` first. See
`AccentColorOption` in `features/settings/domain/app_settings.dart`.

| Name | Light | Dark |
|------|-------|------|
| Terracotta (default) | `#CC5F3B` | `#E8875F` |
| Blue | `#2563EB` | `#93C5FD` |
| Green | `#15803D` | `#86EFAC` |
| Purple | `#7C3AED` | `#C4B5FD` |
| Pink | `#DB2777` | `#F9A8D4` |
| Teal | `#0F766E` | `#5EEAD4` |
| Yellow | `#CA8A04` | `#FDE047` | was an amber/brown tone that read too close to the default terracotta accent — shifted to a true yellow hue in both modes. |
| Black & white | `#44403C` | `#D6D3D1` | for anyone who doesn't want a color accent — renders as warm-toned grey instead of a hue. |

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

`google_fonts`. Two distinct fonts, not one:

- **Body/UI font** — user-selectable in Settings from a curated set: Inter
  (default), Manrope, Poppins, Nunito, DM Sans, Plus Jakarta Sans, Work Sans,
  Outfit. See `AppFontOption` in `features/settings/domain/app_settings.dart`.
- **Heading font** — fixed, not user-configurable: **Source Serif 4**,
  applied to `headlineLarge`/`headlineMedium`/`headlineSmall` only (AppBar
  titles, screen/sheet headers like "Track your spending" or "Add expense").
  Matches the Claude app's own look (a serif set against an otherwise
  sans-serif UI) per explicit user request — this was a "make it match by
  default" ask, not a pickable option, hence it stays fixed while the body
  font stays curated. `displayLarge`, `titleLarge`, and `titleMedium` are
  deliberately left in the body font since they're used for numbers
  (AmountTile totals, day-tile amounts) as well as text — numerals should
  stay in the legible sans font regardless of heading treatment. Two call
  sites that use a headline-level style for a genuinely numeric input (the
  OTP code entry field, the amount field in the add/edit expense sheet)
  explicitly opt back out to a sans style rather than inheriting the serif.
  See `AppTheme.headingStyle()` for the one-off case (the splash screen's
  "SpendWise" wordmark, which intentionally uses `displayLarge`'s size but
  wants the serif).

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
   Today) as a vertically swipeable card (`SwipeableAmountTile`) — swipe up/
   down to cycle periods, wrapping around at either end. Went through a few
   iterations per user feedback: a dropdown ("wasn't looking good"), then a
   small pill switcher, then a compact scroll-wheel, before landing on "the
   whole tile should visibly scroll, not just its label." The card treatment
   itself also iterated: a frosted-glass version (blur + translucency) barely
   read as different from the page background, because backdrop blur only
   looks like "glass" over a detailed/colorful background — against this
   app's flat page color it has nothing to blur. Replaced with a bold
   gradient card built from the user's selected accent color (a "hero stat
   card" in the style of Cash App/Revolut/Apple Wallet's primary balance
   card), a colored ambient shadow, and a thin light-catching rim border —
   this is a **deliberate, scoped exception** to the flat/bordered card style
   used everywhere else in the app (see Elevation above), specifically
   because the user wanted this one interactive element to read as bold and
   premium rather than flat. The next/previous period's card peeks in at the
   top/bottom edge as the swipe affordance (an earlier version added arrow
   icons on top of this; removed per feedback — the peeking card alone is
   enough), plus a one-time nudge animation on first render so the tile's
   interactivity isn't purely undiscoverable. Quick-add FAB, recent expenses
   as
   collapsible day-tiles (closed by default, showing date + total; tap to
   expand and lazily load that day's items), paginated by day as you scroll.
   The search icon opens the Search screen (a pushed route, not its own tab,
   since it's a drill-down of Home rather than a separate concern) — text
   search by description/amount, plus a Filters button for category
   (multi-select) and time period, including custom ranges. Used to be two
   separate icons/screens (Search and Filter) doing almost the same thing;
   merged into one per explicit user feedback. See "Component notes" below.
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
- **Custom date range picking** (Search's Filters sheet, Analytics'
  custom-range CSV export) uses `pickFriendlyDateRange`
  (`core/utils/friendly_date_range_picker.dart`) — a custom two-step dialog
  (start date, then end date, each a `CalendarDatePicker`, the same widget
  `showDatePicker` uses internally), not Flutter's built-in
  `showDateRangePicker`. The stock range picker's calendar view requires
  knowing you tap twice on one grid to define a range, and its "switch to
  typing" pencil icon is easy to land on by accident, after which you're
  stuck typing a date in a strict format instead of picking one visually —
  replaced per explicit user feedback that customers found it hard to use.
  Each step says explicitly what step it is and what happens next ("you'll
  pick an end date next"), and the end-date step has a **Back** button to
  revisit the start date without cancelling the whole flow and starting
  over — also explicit feedback: people need to be able to change their
  mind mid-flow, not just restart. Built as one dialog with internal step
  state rather than two independent `showDatePicker` calls specifically to
  make that Back button possible.
- **Search's Filters sheet category picker is multi-select** (`FilterChip`,
  not `ChoiceChip`) — pick any number of categories, not just one or all.
  "All" is its own chip that clears the whole selection rather than being
  one more toggle among many. The backend's `GET /expenses` and
  `GET /expenses/daily-summary` both gained a `categoryIds` query param
  (comma-separated, matched with `$in`) alongside the existing singular
  `categoryId`, which other call sites (e.g. DayTile's per-day fetch) still
  use unchanged.
- **`HistoryPeriodPreset`** (the quick period chips in Search's Filters
  sheet — see `expense_history_filter.dart`) includes **Last month**
  alongside All time/Today/This week/This month/Custom, added per explicit
  request as "the most commonly used" period beyond the current one. Adding
  a case to that one enum is enough for it to appear wherever the preset
  chips are used, by construction.
- **Search screen** (`ExpenseSearchScreen`) is Home's sole entry point for
  browsing/filtering/searching expenses — it used to be two separate
  screens (a Search screen with only a date filter, and a History screen
  with category+period filters), each with its own icon on Home, doing
  almost the same thing. Merged per explicit user feedback. The category+
  period Filters sheet (`ExpenseHistoryFilterSheet`) is reused as-is inside
  Search rather than duplicated; its state lives in
  `expenseHistoryFilterProvider` so it works the same regardless of which
  screen opens it. Results view: no text query shows the same grouped
  day-tiles Home uses (reuses `DayTile` directly), scoped to whatever
  category/period filter is active, plus a "Total" footer (the grand total
  across every matching day, not just the ones loaded — see
  `DailySummaryResult.totalAmount`); a text query shows a flat list of
  matches with the same running total instead — see the screen's own doc
  comment for why. Both views are paginated with "load more" on scroll
  (20 expenses / 15 days per page, matching Home's day-tile page size) —
  per explicit user feedback that a single unbounded fetch wouldn't scale
  for someone with a lot of history.
- **Filters sheet defaults to nothing selected**, not "All"/"All time"
  pre-highlighted — per explicit user feedback that pre-checking those
  looked like a choice had already been made, and pressing Apply against
  those defaults appeared to do nothing (`filter.isActive` alone can't
  distinguish "untouched" from "explicitly chose All/All time", so a
  sibling provider, `expenseFiltersEverAppliedProvider`, tracks whether
  Apply has actually been pressed at least once). The sheet's own draft
  state (`_categoryIds`/`_period` in `expense_history_filter_sheet.dart`)
  is nullable for the same reason — `null` renders with no chip
  highlighted; pressing Apply with nothing touched defaults both to "All".
- **Pagination loading state is a field on the result, not derived from
  `hasMore`** (`DailySummaryResult.isLoadingMore` / `ExpenseListResult.
  isLoadingMore`, used by Home's day-tile feed and both of Search's
  results views) — `hasMore` stays true the whole time more pages *exist*,
  whether or not one is currently being fetched, which was the actual
  cause of a reported jank: scrolling into blank space at the bottom
  before the next page arrived, then the list visibly jumping once it
  did. Setting `isLoadingMore: true` before a `loadMore()` fetch and
  false after means the loading row appears exactly when a fetch starts —
  well before the user reaches genuinely blank space, since the scroll
  listener triggers loadMore() 300px before the true bottom — and doubles
  as a re-entrancy guard against firing overlapping fetches for the same
  next page during fast/continuous scrolling.
