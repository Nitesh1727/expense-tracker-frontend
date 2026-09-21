# Data modes: cloud and local

One codebase, two ways to store data. Chosen at build time with
`--dart-define=DATA_MODE=cloud|local` (default `cloud`).

| | cloud | local |
|---|---|---|
| Data lives in | Node/MongoDB backend | on-device SQLite (`spendwise.db`) |
| Login | email + password, emailed code | none, opens straight into the app |
| Network | yes | never (the local Android build has no INTERNET permission) |
| Profile | server account | name + avatar in SharedPreferences |

## How it works

The UI depends only on four abstract interfaces, each with two implementations
chosen in one provider (`AppConfig.isLocal`):

| Interface | Cloud | Local |
|---|---|---|
| `ExpenseApi` | `RemoteExpenseApi` (Dio) | `LocalExpenseApi` |
| `CategoryApi` | `RemoteCategoryApi` | `LocalCategoryApi` |
| `AnalyticsApi` | `RemoteAnalyticsApi` | `LocalAnalyticsApi` |
| `ExportApi` | `RemoteExportApi` | `LocalExportApi` (`xlsx_builder.dart`) |

Screens, providers and models are shared and unchanged. Anything that changes
what an API returns must change **both** implementations, and the parity tests
below will fail if they drift.

## Local database

`lib/core/local/local_database.dart`. Two tables, `categories` and `expenses`,
indexes on `expenses(date)` and `expenses(category_id, date)`. Default
categories are seeded on creation (mirror of the backend's list).

- `date` is UTC epoch milliseconds; IST (fixed UTC+5:30) day buckets are
  `(date + 19800000) / 86400000`. Range/week/month/year logic is in
  `lib/core/local/ist.dart` (mirror of the backend's `dateRange.util.js`;
  weeks start Monday, ranges are `[start, end)`).
- Search matches a lowercased description substring (`description_lc` +
  `instr`, so no LIKE wildcards to escape and Unicode-aware) OR an exact amount.
- Category names are unique case-insensitively via a lowercased `name_key`.
- Filtering, totals, grouping and pagination all run in SQL.
- Error messages/status codes match the backend's so screens show the same text.

## Differences in local mode (deliberate, and only these)

1. No Welcome/login/signup/verify/forgot-password screens.
2. Profile: no "Log out"; "Delete account" is "Erase all data" (wipes expenses
   and categories, re-seeds defaults, resets the profile, stays in the app).
3. Settings hub hides Notifications and Account (email-only features).
4. Excel export: same workbook, except the top three rows are not frozen (the
   `excel` package cannot freeze panes).

## Running and building

```
./run_dev.sh            # cloud (needs the backend running)
./run_dev.sh local      # local, no backend

flutter build apk --release --flavor cloud --dart-define=DATA_MODE=cloud --dart-define=API_BASE_URL=<url>
flutter build apk --release --flavor local --dart-define=DATA_MODE=local
```

Android flavors: `cloud` = `com.example.frontend` / "SpendWise" (unchanged);
`local` = `com.example.frontend.local` / "SpendWise Local" and its own manifest
removes the INTERNET permission. Both can be installed side by side. Output
files are named per flavor (`app-local-release.apk`). No iOS flavors/schemes
are set up yet, and iOS has not been tested.

## Fonts

All selectable fonts and weights are bundled in `assets/google_fonts/` so
`google_fonts` never downloads at runtime (local mode has no network).
`test/fonts_bundled_test.dart` fails if a used family/weight is missing. To add
a font or weight, add the `Family-Weight.ttf` file (the same file
`google_fonts` would fetch) and extend that test.

## Tests

- `flutter test`: unit + parity tests.
- `test/parity/`: loads a real cloud account's dataset (`fixtures.json`) into
  SQLite and compares 305 recorded cloud API answers plus 3 Excel files.
  Re-record with
  `dart run tool/capture_parity_fixture.dart <apiBaseUrl> <email> <password>`
  (read-only against the cloud).
- `test/local/`: rules the cloud dataset can't cover (IST 23:30/00:15 edges,
  Monday weeks, leap years, decimals, category rules, error messages, Excel
  styling) and a 50,000-row speed check.
- `flutter test --dart-define=DATA_MODE=local`: also runs the local-mode app boot test.

## Not built yet

- Backup/sync of the local database to Google Drive / iCloud (the single
  `spendwise.db` file makes a backup/restore feature straightforward).
- Moving data between cloud and local modes.
