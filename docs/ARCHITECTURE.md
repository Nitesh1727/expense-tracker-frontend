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
│   │   └── presentation/          # home screen, history/log screen, add/edit sheet, expense card
│   ├── categories/
│   │   ├── data/
│   │   ├── domain/                # Category model
│   │   └── presentation/          # category list + add/edit sheet (icon+color pickers)
│   ├── analytics/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/          # period selector, category breakdown list, export
│   └── export/
│       └── presentation/          # export action + share sheet trigger, lives in Profile
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
| `dio` | HTTP client | Interceptor support for attaching the JWT and centralizing error handling, without needing code generation. |
| `flutter_secure_storage` | JWT persistence | Keychain/Keystore-backed — plain `SharedPreferences` for an auth token is a bad practice both stores' reviewers can flag. |
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

## Navigation

Plain `Navigator`/`MaterialPageRoute` — no routing package. `go_router` was
the original plan (see git history), dropped during implementation: this app
has no deep-linking requirement, so its redirect-based auth gating would add
a real class of timing bugs (redirect evaluated against a stale/loading auth
state) for no payoff here. Instead `lib/app.dart` holds an `AuthGate` that
watches `authControllerProvider` and swaps between `WelcomeScreen` and
`RootShell` inside an `AnimatedSwitcher`. `RootShell` is 3 bottom-nav tabs
(Home, Analytics, Categories) in a `PageView` (swipeable, not just tappable)
plus a top-right avatar that pushes `ProfileScreen` — Profile is deliberately
not a 4th tab, see `docs/DESIGN_SYSTEM.md`.

**The auth flow's navigation depth matters and has already broken once.**
`WelcomeScreen` is `AuthGate`'s content; email login/signup pushes just
`EmailAuthScreen` — one level deep — while signup pushes `VerifySignupScreen` on top of it (two deep) and the forgot-password flow pushes
`ForgotPasswordScreen` then `ResetPasswordScreen` **on top of that** — three
levels deep from the root. (A now-removed phone+OTP flow was the original
two-levels-deep case this lesson was learned from — see git history / backend's
still-intact `/auth/otp/*` routes.) When `AuthController`'s state flips to
logged-in, `AuthGate` swaps its content to `RootShell` *underneath* whichever
screen is on top — invisibly, since that screen is still the active route.
Every screen that can end up stacked here must clear itself off after a
successful login/signup so the swapped-in `RootShell` becomes visible (or,
for `_logout`/`deleteAccount` on the *pushed, not-a-tab* `ProfileScreen`,
after the auth state flips back to logged-out — same underlying issue,
opposite direction). **Use `Navigator.of(context).popUntil((route) =>
route.isFirst)`, never a plain `pop()`** — a single `pop()` only removes one
level, which is exactly what shipped originally and broke phone login:
verifying successfully appeared to loop back to "enter your phone number"
forever, because popping the verify screen only revealed the phone-entry
screen still sitting above the (already-swapped) `RootShell`.
`popUntil(isFirst)` is correct regardless of how many screens are stacked,
so this can't silently regress again if a future screen gets inserted into
any of these flows.

Every drill-down/sheet elsewhere (History, expense/category forms, Profile
edit) uses plain `Navigator.push`/`showModalBottomSheet` — this depth
concern is specific to the auth flow's relationship with `AuthGate`, not a
general rule.

## Networking + auth

`api_client.dart` wraps a single `dio` instance. A request interceptor reads
the JWT from `secure_storage.dart` and attaches
`Authorization: Bearer <token>`. A response interceptor catches 401s and
routes to the login screen (token expired/invalid) in one place, rather than
handling that per-screen.

## Data modes

The data layer is four interfaces with cloud and local (SQLite) implementations, selected at build time — see `docs/DATA_MODES.md`. Dependencies added for it: `sqflite` (on-device SQLite), `path` (DB file path), `excel` (on-device xlsx writer); `sqflite_common_ffi` is dev-only for tests.

## Animation approach

Favor Flutter's built-in implicit animations (`AnimatedContainer`,
`AnimatedSwitcher`, `Hero`) and `flutter_animate` for list/entrance polish,
over hand-rolled `AnimationController`s. Reach for an explicit
`AnimationController` only when an interaction genuinely needs one (e.g. a
custom gesture-driven transition) — most of the "smooth app" feel comes from
consistent, well-tuned durations/curves (see `core/theme/motion.dart`) applied
everywhere, not from bespoke animation code per screen.
