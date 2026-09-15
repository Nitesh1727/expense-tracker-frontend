# Frontend Architecture

Flutter, feature-first structure. State management: **Riverpod**.

## Why feature-first, not layer-first

Grouping by feature (`features/expenses/`, `features/auth/`) instead of by
type (`screens/`, `widgets/`, `providers/` each holding every feature) keeps
everything related to one flow in one place. For an app this size it also
just maps better to how you'll actually navigate the code — "I need to change
how expenses are added" means one folder, not four.

## Why Riverpod

Chosen over Provider/Bloc/GetX: less boilerplate than Bloc for an app this
size, compile-time safety Provider doesn't give you, and `AsyncNotifier`
maps cleanly onto "fetch from API, show loading/error/data" which is most of
this app's state. Revisit only if the app's async complexity actually grows
past what Riverpod handles comfortably — don't switch preemptively.

## Folder structure (target)

```
frontend/lib/
├── main.dart                  # entrypoint, ProviderScope wrapper
├── app.dart                    # MaterialApp/CupertinoApp, theme + router wiring
├── core/
│   ├── theme/
│   │   ├── colors.dart         # design system color tokens — see docs/DESIGN_SYSTEM.md
│   │   ├── typography.dart     # text style tokens
│   │   ├── spacing.dart        # spacing scale constants
│   │   └── motion.dart         # animation duration/curve tokens
│   ├── router/
│   │   └── app_router.dart     # go_router config, route definitions
│   ├── network/
│   │   ├── api_client.dart     # dio instance, base URL, JWT interceptor
│   │   └── api_exception.dart
│   ├── storage/
│   │   └── secure_storage.dart # flutter_secure_storage wrapper for JWT
│   ├── widgets/                # shared, reusable, feature-agnostic widgets
│   │   ├── app_button.dart
│   │   ├── app_text_field.dart
│   │   ├── app_card.dart
│   │   └── empty_state.dart
│   └── constants/
│       └── categories.dart     # fixed category list: id, label, icon, color
├── features/
│   ├── auth/
│   │   ├── data/                # api calls (signup, login, otp request/verify)
│   │   ├── domain/               # User model
│   │   └── presentation/         # screens + widgets + riverpod providers/notifiers
│   ├── expenses/
│   │   ├── data/
│   │   ├── domain/                # Expense model
│   │   └── presentation/          # list screen, add/edit sheet, expense card
│   ├── analytics/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/          # period filter tabs, charts (fl_chart)
│   └── export/
│       └── presentation/          # export action + share sheet trigger
└── test/
```

Each `features/<x>/presentation/` folder holds screens, feature-local
widgets, and the Riverpod providers/notifiers for that feature — kept
together rather than split into separate top-level `screens/`/`providers/`
folders.

## Key dependencies (planned)

| Package | Purpose | Why this one |
|---------|---------|---------------|
| `flutter_riverpod` | State management | See above. |
| `go_router` | Routing | Official, supports the animated transitions and deep-link structure a polished app needs. |
| `dio` | HTTP client | Interceptor support for attaching the JWT and centralizing error handling, without needing code generation. |
| `flutter_secure_storage` | JWT persistence | Keychain/Keystore-backed — plain `SharedPreferences` for an auth token is a bad practice both stores' reviewers can flag. |
| `fl_chart` | Analytics charts | Lightweight, customizable, good animation support out of the box. |
| `flutter_animate` | Declarative micro-animations | Gets Blinkit-tier polish (fades, slides, staggered list entrances) with minimal code — fits the "smooth but simple" goal. |
| `google_fonts` | Typography | One line to get a polished typeface instead of the system default. |
| `csv` | CSV generation | Client-side CSV building for export (or backend-generated — see below). |
| `share_plus` | Native share sheet | Export flow shares the CSV via the OS share sheet rather than writing to shared storage — avoids Android storage permission complications. |
| `intl` | Date/number formatting | |

Don't add a package outside this list without a reason — every dependency is
something that can break on a Flutter/Xcode/Gradle upgrade later.

## CSV export flow

Backend generates the CSV (`GET /api/export/csv`, see backend API docs) and
the app writes the response to a temp file, then opens the native share sheet
(`share_plus`) so the user can save to Files, Drive, email it, or open
directly in Sheets. Client never needs raw storage-write permissions.

## Networking + auth

`api_client.dart` wraps a single `dio` instance. A request interceptor reads
the JWT from `secure_storage.dart` and attaches
`Authorization: Bearer <token>`. A response interceptor catches 401s and
routes to the login screen (token expired/invalid) in one place, rather than
handling that per-screen.

## Animation approach

Favor Flutter's built-in implicit animations (`AnimatedContainer`,
`AnimatedSwitcher`, `Hero`) and `flutter_animate` for list/entrance polish,
over hand-rolled `AnimationController`s. Reach for an explicit
`AnimationController` only when an interaction genuinely needs one (e.g. a
custom gesture-driven transition) — most of the "smooth app" feel comes from
consistent, well-tuned durations/curves (see `core/theme/motion.dart`) applied
everywhere, not from bespoke animation code per screen.
