# On-device redaction of personal information

## Why this exists

The scan flow uploads a photograph of a lab report to `POST /reports/extract`,
which stores the file **and** forwards it to Gemini. A lab report carries far
more than test values: the patient's name, address, phone number, patient ID,
national ID, the referring doctor, and the letterhead of the clinic they
attended. Uploading the raw photo hands all of that to a third-party model and
leaves it in the API's storage.

The requirement is that identifying details are removed **before** the image is
sent anywhere.

This is implemented entirely in the Flutter app. The API is finished and
off-limits, and it exposes no "upload without OCR" endpoint — but because
`extract` stores exactly the bytes it receives, redacting client-side solves
both halves at once:

- Gemini only ever sees a masked image.
- The copy retained server-side, and shown to anyone the report is shared with
  (a doctor, say), is masked too.

The original photograph never leaves the device.

## Design principles

1. **Never a silent leak.** A detector miss must be recoverable by the user, so
   the review step is mandatory rather than a silent best-effort pass.
2. **Never a silent corruption.** Masking a test result would break the app's
   core function and pollute the shared test catalogue upstream, so the
   "this is a result" guard runs before every other rule.
3. **Identity is not a user preference.** Anything that names, locates or
   numbers a person cannot be revealed by the user. The people most at risk are
   the least likely to make that judgement call correctly.
4. **Destroy, don't cover.** Pixels are overwritten before encoding.

## The pipeline

```
pick → crop → prepare → OCR → detect → review (mandatory) → redact → upload
              └─────────── all on-device, no network ───────────┘
```

### 1. Prepare — `prepareReportImage()` in `core/privacy/image_redactor.dart`

Runs in a `compute()` isolate so a 10-megapixel photo doesn't freeze the UI.

`decodeImage` → `bakeOrientation` → downscale longest edge to ≤2000px →
`encodeJpg(quality: 90)` → write to the temp directory.

Three things depend on this step:

- **EXIF is destroyed.** GPS latitude/longitude, device serial and capture time
  are gone, because the pixels are written into a brand-new JPEG and none of
  that metadata is carried across. This happens **even when nothing is masked**,
  which is why the prepared file is used as the upload in that case too.
- **Orientation is baked into the pixels.** ML Kit honours the EXIF rotation
  flag; the `image` package does not apply it on decode. Without baking it in,
  boxes computed from OCR would land sideways on rotated camera photos.
- **One canonical file.** OCR, the review screen and the redactor all work on
  the same file, so a box at pixel (120, 340) means the same thing to all three.

### 2. Read the text — `core/privacy/text_scanner.dart`

Google ML Kit's text recognition model is bundled in the APK and runs on the
device. No network call is involved in inspecting the image — which is the whole
point, since the image has to be examined *before* it is allowed onto the
network.

Output is immediately converted into `OcrLine` / `OcrPage`
(`core/privacy/ocr_line.dart`) — our own plain types. This is what keeps the
detector unit-testable against synthetic layouts with no device and no plugin.
`text_scanner.dart` is the only file in the app that imports ML Kit.

### 3. Detect — `core/privacy/pii_detector.dart`

Per recognised line, in this order:

**a. The guard.** Skip the line if it reads as a measurement: it matches a
canonical name from the test catalogue, or pairs a digit with a known unit
(`11.8 g/dL`), or is the results-table header row. Ordering matters — blacking
out `Haemoglobin 11.8 g/dL` breaks extraction, whereas over-masking a header
line costs nothing.

**b. High-confidence standalone patterns.** Email, Bangladeshi mobile numbers,
10/13/17-digit NIDs, honorific-prefixed names (`Md. Rafiq`), `Dr.`/`Prof.`
These are specific enough to be trusted even past the guard.

The phone pattern carries digit lookarounds (`(?<!\d) … (?!\d)`) for a concrete
reason: without them it matches a slice out of the middle of `14000000000` — a
WBC count in full notation — and blacks out a result row.

**c. Labelled fields.** ~60 label variants across six categories, matched either
at the start of a line or immediately before a colon mid-line. A hit masks the
**whole line**, which is both safer and handles dot-leader layouts
(`Name ......... Md. Rafiq`).

All matching categories are collected, not just the first. A line carrying two
labels (`Name : Ayesha   Age : 32`) resolves to the stricter one — otherwise it
would inherit age's visible-by-default behaviour and leak the name.

**d. Letterhead.** An explicit facility word (`hospital`, `diagnostic`,
`laboratory`, `centre`, `www.`) anywhere, or a line in the top 15% of the page
set noticeably larger than the body text — which is what a clinic banner looks
like without knowing what it says.

Two exemptions keep that size heuristic honest: dates (the collection date is
printed at the top of most reports) and report/department titles
(`COMPLETE BLOOD COUNT`, `Haematology Report`). The title exemption matters
because facility boxes cannot be revealed — masking the title would silently
cost the analysis its most useful line of context.

**e. Row expansion — `_expandAcrossRow()`.** This is the fix for the most
dangerous class of miss. On a two-column or dot-leader layout, OCR returns
`Name` and `Rafiqul Islam` as *separate* lines, and the value alone matches
nothing: no label, no honorific, nothing numeric. Masking only the matched line
blacks out the word "Name" and leaves the patient's name perfectly legible.
Phone numbers and IDs survived this because they match a standalone pattern
wherever they sit; names have no such signature.

So a label match grows across its row:

- absorb every line overlapping its vertical band by ≥40% and starting to its
  right (this also catches a long name split into two boxes);
- **stop** at any line that opens a new field, so `Age :` in the next column is
  not swallowed;
- **stop** at anything that reads as a result;
- if the label has no value of its own *and* nothing was recognised beside it,
  extend to the page edge and take in the line directly below — covering both
  "OCR failed to read a faint or stamped value" and "the layout stacks the value
  underneath".

The blind sweep is gated on the label having no trailing value; otherwise every
labelled field would mask the column next to it.

**f. Merge.** Overlapping same-category boxes collapse into one, so a two-line
address is a single rectangle and a single chip.

### 4. Review — `screens/capture/redaction_screen.dart`

Mandatory. `CaptureProvider.extract()` refuses to run until it has a sanitized
path, and "Extract values" stays disabled until then.

| Category | Masked by default | User can reveal |
| --- | --- | --- |
| Name, address, phone/email, ID numbers, doctor, lab letterhead | yes | **no** |
| Age / DOB / sex | no | yes |
| Boxes the user drew | yes | yes (tap deletes) |

Age and sex stay visible by default because reference ranges are read
differently by age and sex, so hiding them costs the analysis real accuracy.
They are the only detected category the user can toggle. Tapping a locked box
explains why instead of silently ignoring the tap.

Adding boxes is always available — the user can hide more, never less.

If ML Kit throws or finds no text, the screen shows a banner and requires an
explicit acknowledgement checkbox before continuing. There is no path that
uploads an unprocessed original.

### 5. Redact — `redactReportImage()`

```dart
img.fillRect(image, x1: left, y1: top, x2: right, y2: bottom, color: black);
```

Filled before `encodeJpg` runs, so the covered pixels are gone from the file
rather than hidden behind an overlay. This is the difference from blurring or
pixelating, which are reversible transforms of the original data and can remain
legible to a vision model.

With no boxes to draw, the prepared file is used as-is — it was already
re-encoded from scratch, so its EXIF is gone regardless.

### 6. Upload

`CaptureProvider` holds `originalImagePath` (device-only) and
`sanitizedImagePath`. Only the latter is ever passed to `ReportRepository`, and
both `extract()` and `_analyze()` hard-return with an error if it is null — so a
later refactor cannot upload the original by accident.

## Tuning

Every keyword and regex lives in `core/privacy/pii_patterns.dart`; the detector
itself is rules over plain data. To adjust behaviour:

| Goal | Where |
| --- | --- |
| Catch a label the detector misses | add a fragment to `labelKeywords` |
| Stop masking something it shouldn't | add to `reportTitlePattern`, `unitTokens`, or the catalogue |
| Change what starts out hidden | `PiiCategoryDisplay.maskedByDefault` |
| Change what the user may reveal | `PiiCategoryDisplay.canReveal` |

Keywords are regex fragments matched against a lowercased, whitespace-collapsed
line, so `ref(?:erred)?\.? ?by` covers the spellings real labs use.

Add a case to `test/core/privacy/pii_detector_test.dart` with any change. Its
fixtures are synthetic `OcrPage`s, so a new report layout can be reproduced as a
test in a few lines without a photograph.

## Known limitations

- **Latin script only.** ML Kit's recogniser does not read Bangla, so
  `রোগীর নাম` is never auto-detected. The letterhead rule and the user's own
  boxes are the backstop. Adding Bangla would mean Tesseract with `ben`
  traineddata — heavier, lower quality, and it would require changes to the
  Android build.
- **Handwriting** recognises poorly, which is why a bare label sweeps its whole
  row rather than trusting that OCR found everything on it.
- **The follow-up chat** sends whatever the user types, verbatim. The field
  carries a warning; nothing enforces it.
- **Detection is heuristic.** The mandatory review step is the mitigation, not
  an admission that it can be skipped once the rules are good enough.

## Verifying a change

1. `flutter analyze` clean, `flutter test` green.
2. On a device, sign in as `ismail` and photograph a real lab report. Check the
   boxes land on name / ID / phone / letterhead, and that **no result row** is
   covered.
3. Save, then open the report's detail screen and confirm the stored image is
   the redacted one — that proves the server never received the original.
4. Confirm the Gemini analysis text does not name the patient.
5. Failure paths: a blank or blurry image (manual-only banner plus
   acknowledgement), and a landscape photo (checks the orientation baking).
6. `exiftool` the uploaded file, or compare it against the original, to confirm
   the GPS and device tags are gone.
