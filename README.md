# HealthMate

AI-powered personal health tracker — Flutter mobile client. Users photograph lab
reports, Gemini OCR extracts the test values, and the app charts them over time
against reference ranges. Data can be shared read-only with other users (e.g. a
doctor). This is a frontend-only app: all data lives behind the deployed
[HealthMate API](../HealthMate-web), a NestJS + Postgres backend shared with the
web version of the product.

## Setup

```bash
flutter pub get
flutter run                 # requires a connected device or emulator
```

No local backend or `.env` is needed — the app talks directly to the deployed API.

## API

Base URL: `https://healthmate-web-7ufp.onrender.com/api` (hardcoded in
`lib/core/api/api_client.dart`). Auth is a JWT sent as a `Bearer` header, stored
with `flutter_secure_storage`.

The API sits behind Render's free tier, which cold-starts after inactivity — the
API client retries transient failures (connection errors, 502/503/504/520) with
backoff, and gives a lone request up to ~40s before giving up.

### Test accounts (seeded on the API)

| Username | Password | Notes |
| --- | --- | --- |
| `ismail` | `healthmate123` | 9 reports, a year of history, improving lipids |
| `ayesha` | `healthmate123` | Iron-deficiency picture — values below range |
| `rafiq` | `healthmate123` | Everything within range |
| `dr.karim` | `healthmate123` | Has view access to all three above |

## Commands

```bash
flutter analyze             # static analysis — should be clean
flutter test                # unit tests (formatters, API client error mapping)
flutter build apk --debug   # sanity-build without installing to a device
```

## Architecture

```
lib/
  main.dart, app.dart        entry point, theme, MultiProvider + go_router wiring
  core/
    api/                     ApiClient (Bearer auth, retry/backoff, error flattening)
    storage/                 TokenStorage (flutter_secure_storage)
    theme/                   Material 3 theme + the shared chart palette
    router/                  go_router config, auth-gated redirects
    app_dependencies.dart    wires repositories/services as a single Provider
  models/                    API request/response shapes, hand-mirrored from the API
  repositories/              one per API resource — the only layer that calls ApiClient
  providers/                 ChangeNotifier state per feature (auth, reports, trends, ...)
  screens/                   one folder per feature area
  widgets/                   shared UI (status pill, avatar, empty/error/loading states)
```

State management is `provider` (`ChangeNotifier`) throughout — not Riverpod, not
Bloc. Routing is `go_router`, with a `StatefulShellRoute` bottom-nav shell for the
five primary destinations (Dashboard, Reports, Trends, Connections, Profile).
Screens reachable from more than one place (Reports, Trends) accept an optional
`username` query parameter to view someone else's data read-only, and get a
fresh, per-route `ChangeNotifierProvider` rather than a shared app-wide one — the
bottom-nav tabs stay alive via `IndexedStack`, so a shared provider would let a
pushed "someone else's reports" view clobber the state of your own Reports tab
underneath it.

### Gotchas worth knowing before touching the API layer

- `PATCH /users/me` and `POST /users/me/avatar` return only the bare profile
  fields (no `stats`/`isSelf`/`age`/`bmi`) — `UserRepository` returns `void` for
  both and callers refetch `GET /users/me` afterwards rather than trying to
  parse a full profile out of the response.
- The manual-entry test picker uses `GET /tests` (the full catalogue). `GET
  /trends/tests` is a different, narrower endpoint — only tests the requested
  user already has readings for — used by the Trends screen's test picker.
- `provider: "stub"` in an extract response means OCR was unavailable and the
  values are fabricated placeholders. That flag is threaded through the whole
  capture flow and shown as a prominent warning — never let a stub reading be
  mistaken for a real one.
- The QR code encodes `healthmate:user/{username}` (matching the web app's
  scheme), not a bare username — the People screen's scanner parses both that
  scheme and a bare username for robustness.

## Design

Material 3, seeded from the brand green, full light/dark support. The chart
palette (`core/theme/chart_palette.dart`) is shared with the web app and was
validated for colour-vision-deficiency separation and contrast in both themes;
light-mode amber falls under 3:1 contrast on white, so an out-of-range reading
is never shown by colour alone — it always carries a text label
(`widgets/status_pill.dart`), and every chart is paired with a data table below it.
