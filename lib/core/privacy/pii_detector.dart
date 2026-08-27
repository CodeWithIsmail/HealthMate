import 'dart:ui';

import 'ocr_line.dart';
import 'pii_patterns.dart';

/// One region of the image that looks like personal information.
///
/// [rect] is in image pixel coordinates. [matchedText] is kept so the review
/// screen can tell the user *what* it hid — it never leaves the device.
class PiiFinding {
  PiiFinding({
    required this.rect,
    required this.category,
    required this.matchedText,
    bool? masked,
    this.userDrawn = false,
  }) : masked = masked ?? category.maskedByDefault;

  final Rect rect;
  final PiiCategory category;
  final String matchedText;
  final bool userDrawn;

  /// Whether this region will actually be painted over. Toggled by the user on
  /// the review screen.
  bool masked;
}

/// Turns recognised text into a list of regions to black out.
///
/// Pure Dart on purpose — it takes [OcrPage] rather than ML Kit types, so the
/// rules can be tested against synthetic report layouts (see
/// `test/core/privacy/pii_detector_test.dart`).
///
/// The ordering of the rules matters. The "never mask a result" guard runs
/// first, because blacking out `Haemoglobin 11.8 g/dL` breaks the feature,
/// whereas over-masking a header line costs nothing. Only the high-confidence
/// standalone patterns (email, phone, NID) are allowed past that guard.
class PiiDetector {
  PiiDetector({List<String> catalogueNames = const []})
    : _catalogueNames = catalogueNames.map(_normalize).where((n) => n.length >= 3).toList();

  final List<String> _catalogueNames;

  /// Categories are tested in this order; the first *masked-by-default* hit
  /// wins. `identity` is last because its keywords are the broadest ("name",
  /// "patient"), so more specific labels like "Patient ID" classify correctly.
  static const List<PiiCategory> _labelOrder = [
    PiiCategory.contact,
    PiiCategory.identifier,
    PiiCategory.address,
    PiiCategory.clinician,
    PiiCategory.ageSex,
    PiiCategory.identity,
  ];

  static final Map<PiiCategory, List<RegExp>> _labelPatterns = {
    for (final entry in labelKeywords.entries) entry.key: _buildLabelPatterns(entry.value),
  };

  /// A label counts when it opens the line (`Name: X`, `Name ....... X`) or
  /// when it appears mid-line immediately before a colon (`Age: 45 Sex: M`).
  static List<RegExp> _buildLabelPatterns(List<String> fragments) {
    final joined = fragments.join('|');
    return [
      RegExp('^[^a-z0-9]{0,4}(?:$joined)\\b'),
      RegExp('\\b(?:$joined)\\s*[:\\-–—]'),
    ];
  }

  List<PiiFinding> detect(OcrPage page) {
    if (page.isEmpty) return [];

    final headerCutoff = page.imageSize.height * 0.15;
    final medianHeight = _medianLineHeight(page.lines);
    final findings = <PiiFinding>[];

    for (final line in page.lines) {
      final text = _normalize(line.text);
      if (text.isEmpty) continue;

      final categories = <PiiCategory>{};

      // High-confidence patterns first: these are specific enough that they
      // are trusted even on a line that otherwise looks like a result row.
      if (emailPattern.hasMatch(text)) categories.add(PiiCategory.contact);
      if (bdMobilePattern.hasMatch(text) || genericPhonePattern.hasMatch(text)) {
        categories.add(PiiCategory.contact);
      }
      if (nidPattern.hasMatch(text)) categories.add(PiiCategory.identifier);
      if (honorificPattern.hasMatch(text)) categories.add(PiiCategory.identity);
      if (doctorPattern.hasMatch(text)) categories.add(PiiCategory.clinician);

      final guarded = _looksLikeResultLine(text);
      var labelEnd = -1;

      if (!guarded) {
        // Every matching label is collected, not just the first: a line can
        // carry two labels ("Name : Ayesha   Age : 32") and the choice of
        // which one wins decides whether it is masked by default.
        for (final category in _labelOrder) {
          for (final pattern in _labelPatterns[category]!) {
            final match = pattern.firstMatch(text);
            if (match == null) continue;
            categories.add(category);
            if (match.end > labelEnd) labelEnd = match.end;
          }
        }

        if (categories.isEmpty && _looksLikeLetterhead(line, text, headerCutoff, medianHeight)) {
          categories.add(PiiCategory.facility);
        }
      }

      if (categories.isEmpty) continue;

      final category = _pickCategory(categories);

      // A label match covers the label; the value it introduces is often a
      // separate OCR line further along the same row (column layouts, dot
      // leaders). Extending across the row is what actually hides the name.
      final rect = labelEnd >= 0 && _carriesAValue(category)
          ? _expandAcrossRow(line, page, hasTrailingValue: _hasTrailingValue(text, labelEnd))
          : line.box;

      findings.add(
        PiiFinding(
          rect: _pad(rect, page.imageSize),
          category: category,
          matchedText: line.text.trim(),
        ),
      );
    }

    return _mergeOverlapping(findings);
  }

  /// Age/sex only wins when it is the *only* thing on the line — otherwise a
  /// line like "Name : Ayesha   Age : 32" would inherit age's
  /// visible-by-default behaviour and leak the name.
  static PiiCategory _pickCategory(Set<PiiCategory> categories) {
    if (categories.length == 1) return categories.first;
    final ranked = categories.where((c) => c != PiiCategory.ageSex).toList()
      ..sort((a, b) => _rank(a).compareTo(_rank(b)));
    return ranked.isEmpty ? PiiCategory.ageSex : ranked.first;
  }

  static int _rank(PiiCategory category) {
    final index = _labelOrder.indexOf(category);
    return index == -1 ? _labelOrder.length : index;
  }

  /// Categories where the label introduces a value somewhere to its right.
  /// A letterhead is its own text, so it has nothing to extend towards.
  static bool _carriesAValue(PiiCategory category) =>
      category != PiiCategory.facility && category != PiiCategory.manual;

  /// Whether anything survives after the label on the same line — `Name : Md.
  /// Rafiq` has a value, a bare `Name .............` does not.
  static bool _hasTrailingValue(String text, int labelEnd) {
    if (labelEnd >= text.length) return false;
    return text.substring(labelEnd).replaceAll(RegExp(r'[\s:.\-–—_·…]+'), '').isNotEmpty;
  }

  /// Grows a label's box rightwards to cover the value it labels.
  ///
  /// This is the fix for the most dangerous miss in the whole detector: on a
  /// two-column or dot-leader layout, OCR reports `Name` and `Rafiqul Islam`
  /// as separate lines, and the value on its own matches nothing — no label,
  /// no honorific, nothing numeric. Masking only the matched line blacks out
  /// the word "Name" and leaves the patient's name legible.
  ///
  /// Expansion stops at the first line that starts a new field (`Age :`) or
  /// that reads as a test result, so a wide sweep can neither swallow the next
  /// column's label nor black out a measurement.
  Rect _expandAcrossRow(OcrLine label, OcrPage page, {required bool hasTrailingValue}) {
    final candidates =
        page.lines
            .where(
              (other) =>
                  !identical(other, label) &&
                  other.box.left >= label.box.right - 2 &&
                  _verticalOverlapRatio(label.box, other.box) >= 0.4,
            )
            .toList()
          ..sort((a, b) => a.box.left.compareTo(b.box.left));

    var rect = label.box;
    var extended = false;
    var blocked = false;

    for (final candidate in candidates) {
      final text = _normalize(candidate.text);
      if (_startsNewField(text) || _looksLikeResultLine(text)) {
        blocked = true;
        break;
      }
      rect = rect.expandToInclude(candidate.box);
      extended = true;
    }

    // A bare label with nothing recognised beside it. Two things can be true:
    // the value is printed to the right and OCR failed to read it (faint
    // print, a stamp, handwriting), or the layout stacks it underneath. Cover
    // both rather than trusting that the row is empty.
    if (!extended && !blocked && !hasTrailingValue) {
      if (page.imageSize.width > 0) {
        rect = Rect.fromLTRB(rect.left, rect.top, page.imageSize.width, rect.bottom);
      }
      final below = _lineBelow(label, page);
      if (below != null) rect = rect.expandToInclude(below.box);
    }

    return rect;
  }

  /// The line directly under a bare label, when it is close enough and aligned
  /// closely enough to be that label's value. Deliberately narrow: only ever
  /// consulted when nothing at all was found on the label's own row.
  OcrLine? _lineBelow(OcrLine label, OcrPage page) {
    final tolerance = label.box.height * 1.5;
    OcrLine? best;

    for (final other in page.lines) {
      if (identical(other, label)) continue;
      final gap = other.box.top - label.box.bottom;
      if (gap < -2 || gap > tolerance) continue;
      if ((other.box.left - label.box.left).abs() > tolerance) continue;

      final text = _normalize(other.text);
      if (text.isEmpty || _startsNewField(text) || _looksLikeResultLine(text)) continue;
      if (best == null || other.box.top < best.box.top) best = other;
    }

    return best;
  }

  /// True when a line opens with a label of its own — the next field along.
  bool _startsNewField(String text) =>
      _labelPatterns.values.any((patterns) => patterns.first.hasMatch(text));

  /// Shared vertical extent as a fraction of the shorter box, which is how
  /// "these two boxes are on the same row" is decided.
  static double _verticalOverlapRatio(Rect a, Rect b) {
    final top = a.top > b.top ? a.top : b.top;
    final bottom = a.bottom < b.bottom ? a.bottom : b.bottom;
    final overlap = bottom - top;
    if (overlap <= 0) return 0;
    final shorter = a.height < b.height ? a.height : b.height;
    return shorter <= 0 ? 0 : overlap / shorter;
  }

  /// True for anything that reads as a measurement or the results-table header.
  bool _looksLikeResultLine(String text) {
    for (final name in _catalogueNames) {
      if (text.contains(name)) return true;
    }

    if (RegExp(r'\d').hasMatch(text)) {
      for (final unit in unitTokens) {
        if (text.contains(unit)) return true;
      }
    }

    var headerHits = 0;
    for (final token in tableHeaderTokens) {
      if (RegExp('\\b${RegExp.escape(token)}\\b').hasMatch(text)) headerHits++;
      if (headerHits >= 2) return true;
    }

    return false;
  }

  /// Letterhead: either an explicit facility word anywhere on the page, or a
  /// line sitting in the top band that is set noticeably larger than the body
  /// text — which is what a logo/clinic banner looks like.
  ///
  /// Two exemptions keep the size heuristic from eating lines that belong to
  /// the report rather than the clinic: dates (the collection date is printed
  /// at the top of most reports) and report/department titles.
  bool _looksLikeLetterhead(OcrLine line, String text, double headerCutoff, double medianHeight) {
    if (text.length < 3) return false;
    if (datePattern.hasMatch(text)) return false;
    if (facilityPattern.hasMatch(text)) return true;
    if (reportTitlePattern.hasMatch(text)) return false;
    return line.box.bottom <= headerCutoff && medianHeight > 0 && line.box.height >= medianHeight * 1.3;
  }

  /// Lower median — with only a couple of lines on the page, taking the upper
  /// one would let a banner set its own baseline and never look oversized.
  static double _medianLineHeight(List<OcrLine> lines) {
    if (lines.isEmpty) return 0;
    final heights = lines.map((l) => l.box.height).toList()..sort();
    return heights[(heights.length - 1) ~/ 2];
  }

  static Rect _pad(Rect box, Size imageSize) {
    final padded = box.inflate(4);
    if (imageSize.isEmpty) return padded;
    return Rect.fromLTRB(
      padded.left.clamp(0.0, imageSize.width),
      padded.top.clamp(0.0, imageSize.height),
      padded.right.clamp(0.0, imageSize.width),
      padded.bottom.clamp(0.0, imageSize.height),
    );
  }

  /// Adjacent lines of the same category (a two-line address, a wrapped
  /// letterhead) collapse into one box so the review screen shows one chip to
  /// toggle rather than several stacked rectangles.
  static List<PiiFinding> _mergeOverlapping(List<PiiFinding> findings) {
    final merged = <PiiFinding>[];

    for (final finding in findings) {
      var absorbed = false;
      for (var i = 0; i < merged.length; i++) {
        final existing = merged[i];
        if (existing.category != finding.category) continue;
        if (!existing.rect.inflate(3).overlaps(finding.rect.inflate(3))) continue;

        merged[i] = PiiFinding(
          rect: existing.rect.expandToInclude(finding.rect),
          category: existing.category,
          matchedText: '${existing.matchedText} ${finding.matchedText}'.trim(),
          masked: existing.masked,
        );
        absorbed = true;
        break;
      }
      if (!absorbed) merged.add(finding);
    }

    merged.sort((a, b) => a.rect.top.compareTo(b.rect.top));
    return merged;
  }

  static String _normalize(String value) => value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}
