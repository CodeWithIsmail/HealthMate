import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/core/privacy/ocr_line.dart';
import 'package:healthmate/core/privacy/pii_detector.dart';
import 'package:healthmate/core/privacy/pii_patterns.dart';

/// Builds a page of stacked lines, 30 px tall each, the way OCR would report a
/// portrait report photo. [bigFirst] makes line 0 taller, which is how a
/// letterhead banner looks to the detector.
OcrPage pageOf(List<String> texts, {bool bigFirst = false, double width = 1000}) {
  final lines = <OcrLine>[];
  var top = 0.0;
  for (var i = 0; i < texts.length; i++) {
    final height = bigFirst && i == 0 ? 60.0 : 30.0;
    lines.add(OcrLine(text: texts[i], box: Rect.fromLTWH(20, top, width - 40, height)));
    top += height + 10;
  }
  return OcrPage(lines: lines, imageSize: Size(width, top < 800 ? 800 : top));
}

Iterable<String> matchedTexts(List<PiiFinding> findings) => findings.map((f) => f.matchedText);

bool hasMatch(List<PiiFinding> findings, String needle) =>
    findings.any((f) => f.matchedText.toLowerCase().contains(needle.toLowerCase()));

void main() {
  const catalogue = ['Haemoglobin', 'Total WBC Count', 'ESR', 'Platelet Count', 'Serum Creatinine'];
  final detector = PiiDetector(catalogueNames: catalogue);

  group('labelled personal fields', () {
    test('finds name, address, phone and patient id', () {
      final findings = detector.detect(
        pageOf([
          'Patient Name : Md. Rafiq Islam',
          'Address : House 12, Road 4, Dhanmondi, Dhaka',
          'Mobile : 01712-345678',
          'Patient ID : HM-2024-99120',
        ]),
      );

      expect(hasMatch(findings, 'Rafiq'), isTrue);
      expect(hasMatch(findings, 'Dhanmondi'), isTrue);
      expect(hasMatch(findings, '01712'), isTrue);
      expect(hasMatch(findings, 'HM-2024-99120'), isTrue);
      expect(findings.every((f) => f.masked), isTrue);
    });

    test('classifies the referring doctor as a clinician', () {
      final findings = detector.detect(pageOf(['Ref. by : Dr. Karim Uddin, MBBS']));

      expect(findings, hasLength(1));
      expect(findings.single.category, PiiCategory.clinician);
      expect(findings.single.masked, isTrue);
    });

    test('dot-leader layouts still match', () {
      final findings = detector.detect(pageOf(['Name ................ Ayesha Siddiqua']));
      expect(hasMatch(findings, 'Ayesha'), isTrue);
    });
  });

  group('the value belongs to its label, even in another column', () {
    // On a two-column or dot-leader layout OCR returns the label and its value
    // as separate lines. The value alone matches nothing — no label, no
    // honorific, nothing numeric — so without row expansion the mask covers
    // the word "Name" and leaves the patient's name perfectly legible.
    OcrPage row(List<(String, double, double)> cells, {double width = 1000}) => OcrPage(
      lines: [
        for (final (text, left, right) in cells)
          OcrLine(text: text, box: Rect.fromLTRB(left, 100, right, 130)),
      ],
      imageSize: Size(width, 800),
    );

    test('a name in the next column is covered by the label', () {
      final findings = detector.detect(row([('Patient Name', 20, 200), ('Rafiqul Islam', 260, 560)]));

      expect(findings, hasLength(1));
      expect(findings.single.category, PiiCategory.identity);
      expect(findings.single.masked, isTrue);
      expect(findings.single.rect.right, greaterThanOrEqualTo(560));
    });

    test('a bare label with nothing readable beside it covers the rest of the row', () {
      // OCR missed the value — faint print, a stamp, handwriting. Assuming the
      // row is empty is exactly the assumption that leaks a name.
      final findings = detector.detect(row([('Name ...............', 20, 320)]));

      expect(findings, hasLength(1));
      expect(findings.single.rect.right, 1000);
    });

    test('expansion stops at the next field so age is not swallowed', () {
      final findings = detector.detect(
        row([('Name', 20, 160), ('Rafiqul Islam', 240, 540), ('Age : 32', 620, 780)]),
      );

      final identity = findings.firstWhere((f) => f.category == PiiCategory.identity);
      expect(identity.rect.right, greaterThanOrEqualTo(540));
      expect(identity.rect.right, lessThan(620));
      expect(findings.any((f) => f.category == PiiCategory.ageSex), isTrue);
    });

    test('expansion never swallows a result printed on the same row', () {
      final findings = detector.detect(
        row([('Name', 20, 160), ('Haemoglobin 11.8 g/dL', 300, 700)]),
      );

      expect(findings, hasLength(1));
      expect(findings.single.rect.right, lessThan(300));
    });

    test('a name OCR split into two boxes is covered end to end', () {
      final findings = detector.detect(
        row([('Name : Rafiqul', 20, 320), ('Islam Chowdhury', 360, 620)]),
      );

      expect(findings, hasLength(1));
      expect(findings.single.rect.right, greaterThanOrEqualTo(620));
    });

    test('a stacked layout covers the value printed under the label', () {
      final findings = detector.detect(
        OcrPage(
          lines: const [
            OcrLine(text: 'Patient Name', box: Rect.fromLTRB(20, 100, 200, 130)),
            OcrLine(text: 'Rafiqul Islam Chowdhury', box: Rect.fromLTRB(20, 134, 380, 164)),
          ],
          imageSize: Size(1000, 800),
        ),
      );

      expect(findings, hasLength(1));
      expect(findings.single.rect.bottom, greaterThanOrEqualTo(164));
    });

    test('a stacked label does not reach down into the results table', () {
      final findings = detector.detect(
        OcrPage(
          lines: const [
            OcrLine(text: 'Name', box: Rect.fromLTRB(20, 100, 160, 130)),
            OcrLine(text: 'Haemoglobin 11.8 g/dL', box: Rect.fromLTRB(20, 134, 480, 164)),
          ],
          imageSize: Size(1000, 800),
        ),
      );

      expect(findings, hasLength(1));
      // The label box (100–130) plus its 4 px pad, and nothing of the result
      // line that starts at 134.
      expect(findings.single.rect.bottom, lessThanOrEqualTo(134));
    });

    test('a label that already has its value does not black out the whole row', () {
      // The blind sweep to the page edge is only for a bare label — otherwise
      // every labelled field would mask the column beside it.
      final findings = detector.detect(row([('Name : Rafiqul Islam', 20, 400)]));

      expect(findings.single.rect.right, lessThan(1000));
    });
  });

  group('result rows are never masked', () {
    test('catalogue tests and values with units survive', () {
      final findings = detector.detect(
        pageOf([
          'Haemoglobin 11.8 g/dL 13.0 - 17.0',
          'Total WBC Count 14000000000 /cumm',
          'ESR 20 mm/hr',
          'Serum Creatinine 0.9 mg/dL',
        ]),
      );

      expect(findings, isEmpty);
    });

    test('the results table header row is not masked', () {
      final findings = detector.detect(pageOf(['Test Name Result Unit Reference Range']));
      expect(findings, isEmpty);
    });

    test('a test name the catalogue does not know is still protected by its unit', () {
      final findings = detector.detect(pageOf(['Vitamin D (25-OH) 18.4 ng/ml']));
      expect(findings, isEmpty);
    });
  });

  group('age and sex', () {
    test('are detected but left visible by default', () {
      // The two lines are adjacent and share a category, so they merge into a
      // single box — one chip to toggle rather than two stacked rectangles.
      final findings = detector.detect(pageOf(['Age : 45 Years', 'Sex : Male']));

      expect(findings, hasLength(1));
      expect(findings.single.category, PiiCategory.ageSex);
      expect(findings.single.masked, isFalse);
      expect(hasMatch(findings, 'Age'), isTrue);
      expect(hasMatch(findings, 'Sex'), isTrue);
    });

    test('a line carrying both a name and an age is masked', () {
      final findings = detector.detect(pageOf(['Name : Ayesha Siddiqua Age : 32']));

      expect(findings, hasLength(1));
      expect(findings.single.category, PiiCategory.identity);
      expect(findings.single.masked, isTrue);
    });
  });

  group('standalone patterns', () {
    test('an unlabelled email is caught', () {
      final findings = detector.detect(pageOf(['ayesha.siddiqua@example.com']));
      expect(findings.single.category, PiiCategory.contact);
    });

    test('an unlabelled NID number is caught', () {
      final findings = detector.detect(pageOf(['1994856231457']));
      expect(findings.single.category, PiiCategory.identifier);
    });

    test('an honorific-prefixed name with no label is caught', () {
      final findings = detector.detect(pageOf(['Md. Rafiqul Islam']));
      expect(findings.single.category, PiiCategory.identity);
    });
  });

  group('letterhead', () {
    test('a facility keyword anywhere is masked', () {
      final findings = detector.detect(pageOf(['Popular Diagnostic Centre Ltd.']));
      expect(findings.single.category, PiiCategory.facility);
    });

    test('an oversized banner line at the top is treated as letterhead', () {
      final findings = detector.detect(pageOf(['GREENVIEW MEDICARE', 'Blood Report'], bigFirst: true));
      expect(hasMatch(findings, 'GREENVIEW'), isTrue);
    });

    test('an oversized report title at the top is not mistaken for letterhead', () {
      // The size heuristic would otherwise swallow this, and a facility box
      // can no longer be revealed — masking it would silently cost the
      // analysis the line that says what kind of report this is.
      final findings = detector.detect(pageOf(['COMPLETE BLOOD COUNT (CBC)', 'Haemoglobin 11.8 g/dL'], bigFirst: true));
      expect(findings, isEmpty);
    });

    test('a department title is kept but a clinic name on the same page is not', () {
      final findings = detector.detect(pageOf(['HAEMATOLOGY REPORT', 'Popular Diagnostic Centre Ltd.'], bigFirst: true));

      expect(findings, hasLength(1));
      expect(hasMatch(findings, 'Popular'), isTrue);
    });

    test('the report date at the top is left alone', () {
      final findings = detector.detect(pageOf(['12/03/2026', 'Collected on 12-03-2026'], bigFirst: true));
      expect(findings, isEmpty);
    });
  });

  test('adjacent lines of the same category merge into one box', () {
    final page = OcrPage(
      lines: const [
        OcrLine(text: 'Address : House 12, Road 4', box: Rect.fromLTWH(20, 100, 500, 30)),
        OcrLine(text: 'Address : Dhanmondi, Dhaka 1209', box: Rect.fromLTWH(20, 128, 500, 30)),
      ],
      imageSize: Size(1000, 800),
    );

    final findings = detector.detect(page);

    expect(findings, hasLength(1));
    expect(findings.single.rect.top, lessThanOrEqualTo(100));
    expect(findings.single.rect.bottom, greaterThanOrEqualTo(158));
  });

  test('boxes are padded but stay inside the image', () {
    final page = OcrPage(
      lines: const [OcrLine(text: 'Name : Rafiq', box: Rect.fromLTWH(0, 0, 200, 30))],
      imageSize: Size(400, 400),
    );

    final rect = detector.detect(page).single.rect;

    expect(rect.left, 0);
    expect(rect.top, 0);
    expect(rect.right, greaterThan(200));
    expect(rect.bottom, greaterThan(30));
  });

  group('what the user is allowed to reveal', () {
    test('only age/sex and the boxes they drew themselves', () {
      expect(PiiCategory.ageSex.canReveal, isTrue);
      expect(PiiCategory.manual.canReveal, isTrue);

      for (final category in [
        PiiCategory.identity,
        PiiCategory.address,
        PiiCategory.contact,
        PiiCategory.identifier,
        PiiCategory.clinician,
        PiiCategory.facility,
      ]) {
        expect(category.canReveal, isFalse, reason: '${category.label} must stay hidden');
      }
    });

    test('everything that cannot be revealed also starts out masked', () {
      for (final category in PiiCategory.values) {
        if (!category.canReveal) {
          expect(category.maskedByDefault, isTrue, reason: '${category.label} would never be hidden otherwise');
        }
      }
    });
  });

  test('an empty page yields nothing', () {
    expect(detector.detect(const OcrPage.empty()), isEmpty);
    expect(matchedTexts(detector.detect(pageOf(const []))), isEmpty);
  });
}
