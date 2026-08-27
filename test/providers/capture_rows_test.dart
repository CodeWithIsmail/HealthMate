import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/models/extraction.dart';
import 'package:healthmate/providers/capture_provider.dart';

/// A real report crashed the review screen with "Duplicate keys found": two
/// printed lines ("HCT" and "PCV") resolved to one canonical test, so two rows
/// shared a testId. Rows are keyed by testId, and [CaptureProvider.updateValue]
/// and `removeRow` address rows by testId too — duplicates would edit and
/// delete each other.
void main() {
  ExtractedValue value(String testId, String name, double v) => ExtractedValue(
    rawName: name,
    value: v,
    unit: '%',
    testId: testId,
    canonicalName: name,
    refLow: 36,
    refHigh: 50,
    matchedBy: MatchedBy.alias,
  );

  test('keeps distinct tests untouched', () {
    final (rows, dropped) = CaptureProvider.rowsFromExtraction([
      value('a', 'Haemoglobin', 12.1),
      value('b', 'Haematocrit', 37.1),
    ]);

    expect(rows.map((r) => r.testId), ['a', 'b']);
    expect(dropped, isEmpty);
  });

  test('drops a repeated testId and names what was dropped', () {
    final (rows, dropped) = CaptureProvider.rowsFromExtraction([
      value('a', 'Haematocrit', 37.1),
      value('a', 'Haematocrit', 37.0),
      value('b', 'MCV', 83.4),
    ]);

    expect(rows.map((r) => r.testId), ['a', 'b']);
    expect(rows.first.valueText, '37.1', reason: 'the first reading wins');
    expect(dropped, ['Haematocrit']);
  });

  test('every row it returns carries a unique key', () {
    final (rows, _) = CaptureProvider.rowsFromExtraction([
      value('a', 'One', 1),
      value('a', 'One again', 2),
      value('a', 'One more', 3),
      value('b', 'Two', 4),
    ]);

    expect(rows.map((r) => r.testId).toSet().length, rows.length);
  });

  test('trims trailing zeros off whole numbers', () {
    final (rows, _) = CaptureProvider.rowsFromExtraction([value('a', 'Neutrophils', 51.0)]);
    expect(rows.single.valueText, '51');
  });
}
