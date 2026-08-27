# HealthMate

AI-powered personal health tracker — Flutter mobile client. Users photograph lab
reports, Gemini OCR extracts the test values, and the app charts them over time
against reference ranges. Data can be shared read-only with other users (e.g. a
doctor). This is a frontend-only app: all data lives behind the deployed
[HealthMate API](../HealthMate-web), a NestJS + Postgres backend shared with the
web version of the product.

**Personal details never leave the phone.** Before a report image is uploaded, it
is scanned on-device and the patient's name, address, contact details, ID
numbers, referring doctor and the lab's letterhead are painted out of the
pixels — see [Privacy](#privacy-on-device-redaction) below and
[`docs/privacy-redaction.md`](docs/privacy-redaction.md) for the full design.

## Setup

```bash
flutter pub get
flutter run                 # requires a connected device or emulator
```

No local backend or `.env` is needed — the app talks directly to the deployed API.

### Running on a physical Android device

1. On the phone: **Settings → About phone**, tap **Build number** seven times,
   then enable **USB debugging** under **Developer options**.
2. Connect over USB and set the connection to **File transfer**, not
   charging-only — charging-only hides the device from `adb`.
3. Accept the *Allow USB debugging?* prompt.
4. `adb devices` should list it; if `adb` is missing from `PATH`, it ships with
   the SDK at `~/Android/Sdk/platform-tools`.
5. `flutter run` (add `-d <device-id>` when more than one target is connected).

The first scan asks for camera and photo permissions. Denying them leaves the
picker returning nothing, so the redaction step is never reached.

## API

Base URL: `https://healthmate-web-7ufp.onrender.com/api` (hardcoded in
`lib/core/api/api_client.dart`). Auth is a JWT sent as a `Bearer` header, stored
with `flutter_secure_storage`.

The API sits behind Render's free tier, which cold-starts after inactivity — the
API client retries transient failures (connection errors, 502/503/504/520) with
backoff, and gives a lone request up to ~40s before giving up. The auth screens
say so explicitly while a request is in flight, because a silent spinner for
eight seconds reads as a hang.

### Test accounts (seeded on the API)

| Username | Password | Notes |
| --- | --- | --- |
| `ismail` | `healthmate123` | 9 reports, a year of history, improving lipids |
| `ayesha` | `healthmate123` | Iron-deficiency picture — values below range |
| `rafiq` | `healthmate123` | Everything within range |
| `dr.karim` | `healthmate123` | Has view access to all three above |

## Commands

```bash
flutter analyze             # static analysis — must be clean
flutter test                # unit + widget tests
flutter build apk --debug   # sanity-build without installing to a device
dart run flutter_launcher_icons   # regenerate launcher icons after changing assets/icon/
```

`flutter analyze` clean and `flutter test` green is the bar for any change, but
neither proves the app *looks* right — verification for UI work means running it
on a device and checking light/dark, a narrow width, and a failure path.

### What the tests cover

| Suite | What it protects |
| --- | --- |
| `test/core/privacy/pii_detector_test.dart` | Every redaction rule: what gets masked, what must never be (result rows, report titles), row expansion across columns, and the invariant that any category the user can't reveal starts out masked |
| `test/core/api/api_client_test.dart` | Error flattening, retry/backoff, `onUnauthorized` firing only for token failures |
| `test/core/utils/formatters_test.dart` | Range status and value/date formatting |
| `test/screens/auth/auth_screens_test.dart` | Login/signup layout at 400×800 and 320×560, validation, password strength labelling |

The PII detector is deliberately pure Dart over plain data types rather than ML
Kit's classes, so its rules are testable with synthetic report layouts — no
device, no plugin, no photograph. The auth widget tests exist because layout
can't be eyeballed from CI; they catch `RenderFlex` overflows at small widths.

## Privacy: on-device redaction

Uploading a lab report photo to an LLM means uploading everything printed on it.
The scan flow therefore runs a redaction pipeline **before** any network call:

```
pick → crop → prepare → on-device OCR → detect → user confirms → burn pixels → upload
                └──────────── all offline, nothing uploaded ────────────┘
```

- **Prepare** (`core/privacy/image_redactor.dart`) re-encodes the photo from
  scratch, which destroys EXIF — GPS coordinates, device serial, capture
  timestamp — whether or not anything is masked.
- **OCR** (`core/privacy/text_scanner.dart`) uses Google ML Kit's bundled model.
  It runs locally; no network call is involved in reading the image.
- **Detect** (`core/privacy/pii_detector.dart`) classifies each recognised line.
  A guard runs first so a test result can never be masked.
- **Confirm** (`screens/capture/redaction_screen.dart`) is mandatory. The user
  can always hide *more* by dragging a box; identifying categories cannot be
  revealed.
- **Burn** overwrites the pixels with opaque black before encoding, so nothing
  remains in the file to recover — unlike blur or pixelation, which are
  reversible transforms of the original pixels.

`CaptureProvider` keeps the picked photo in `originalImagePath` (never uploaded)
and the redacted copy in `sanitizedImagePath`, which is the only path handed to
`ReportRepository`. Both `extract()` and `_analyze()` refuse to run without it.

Since `POST /reports/extract` stores the exact bytes it receives, the redacted
image is also what the server retains and what anyone the report is shared with
can see.

Full design, detection rules, tuning and known limitations:
[`docs/privacy-redaction.md`](docs/privacy-redaction.md).

## Architecture

```
lib/
  main.dart, app.dart        entry point, theme, MultiProvider + go_router wiring
  core/
    api/                     ApiClient (Bearer auth, retry/backoff, error flattening)
    privacy/                 on-device PII detection and image redaction
    storage/                 TokenStorage (flutter_secure_storage)
    theme/                   Material 3 theme + the shared chart palette
    router/                  go_router config, auth-gated redirects
    app_dependencies.dart    wires repositories/services as a single Provider
  models/                    API request/response shapes, hand-mirrored from the API
  repositories/              one per API resource — the only layer that calls ApiClient
  providers/                 ChangeNotifier state per feature (auth, reports, trends, ...)
  screens/                   one folder per feature area
  widgets/                   shared UI (status pill, avatar, brand mark, empty/error states)
assets/
  icon/                      launcher-icon sources (build-time only, not bundled)
  images/                    runtime assets — the in-app logo
tool/
  make_icons.py              regenerates assets/icon/ from the source logo
docs/                        design notes
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

There are **no barrel files**. Every import names the file it wants; a symbol
collision through a re-exporting barrel is what broke an earlier attempt at this
app.

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
- `isSelf`/`isOwner` and derived fields like `age`/`bmi` are decided by the
  server. Never recompute them client-side by comparing usernames.

## Design

Material 3, seeded from the brand green, full light/dark support. The chart
palette (`core/theme/chart_palette.dart`) is shared with the web app and was
validated for colour-vision-deficiency separation and contrast in both themes;
light-mode amber falls under 3:1 contrast on white, so an out-of-range reading
is never shown by colour alone — it always carries a text label
(`widgets/status_pill.dart`), and every chart is paired with a data table below
it. The same rule governs the signup password meter, which labels itself *Weak /
Fair / Strong* rather than relying on the bar colour.

Form fields carry a visible outline (`outlineVariant`, thickening to `primary`
on focus) over a `surfaceContainerLowest` fill. An earlier borderless variant
put a `surfaceContainerLow` fill on a `surface` background — two near-identical
near-whites — which left inputs findable only by their floating label.

### Branding

The launcher icon and the in-app brand mark come from one source image,
`assets/icon/app_icon_source.png`. `tool/make_icons.py` derives two padded
1024px variants from it:

| File | Padding | Used for |
| --- | --- | --- |
| `assets/icon/app_icon.png` | artwork at 80%, white ground | legacy Android mipmaps, iOS |
| `assets/icon/app_icon_foreground.png` | artwork at 73%, transparent | Android adaptive foreground |

73% is not arbitrary. `flutter_launcher_icons` wraps the foreground in
`android:inset="16%"` of its own, so the drawable renders at 68% of the canvas.
Pre-applying safe-zone padding on top of that compounds the two and leaves the
artwork visibly undersized; 0.73 × 0.68 puts it at ~50% of the canvas, a ~64%
diagonal, just inside the 66.7% circle a round launcher mask cuts.

After editing either source: `dart run flutter_launcher_icons`. Launcher icons
are baked into the APK, so a fresh install is needed to see a change — and
Android caches them aggressively, so `adb uninstall com.example.healthmate`
first if the old one persists.

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `flutter devices` doesn't list the phone | USB set to charging-only, or the debugging prompt wasn't accepted |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | A build with a different signature is installed — `adb uninstall com.example.healthmate` |
| Old launcher icon after an update | Launcher icon cache; reinstall, or restart the launcher |
| "Values were not read from your image" | The API's Gemini quota is exhausted and it fell back to `StubProvider`; the numbers shown are placeholders |
| Sign-in hangs for several seconds | Render free-tier cold start — expected on the first request after inactivity |
| Redaction misses a name | Usually a layout the detector can't associate, or Bangla-script text (ML Kit reads Latin only). See `docs/privacy-redaction.md` |
