import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/core/utils/formatters.dart';

void main() {
  group('rangeStatus', () {
    test('unknown when no reference range exists', () {
      expect(rangeStatus(5, null, null), RangeStatus.unknown);
    });

    test('low when below the reference range', () {
      expect(rangeStatus(3, 5, 10), RangeStatus.low);
    });

    test('high when above the reference range', () {
      expect(rangeStatus(12, 5, 10), RangeStatus.high);
    });

    test('normal when inside the reference range', () {
      expect(rangeStatus(7, 5, 10), RangeStatus.normal);
    });

    test('normal exactly on the boundary values', () {
      expect(rangeStatus(5, 5, 10), RangeStatus.normal);
      expect(rangeStatus(10, 5, 10), RangeStatus.normal);
    });

    test('low still evaluates against a present low bound with a null high bound', () {
      expect(rangeStatus(2, 5, null), RangeStatus.low);
      expect(rangeStatus(100, 5, null), RangeStatus.normal);
    });

    test('high still evaluates against a present high bound with a null low bound', () {
      expect(rangeStatus(20, null, 10), RangeStatus.high);
      expect(rangeStatus(1, null, 10), RangeStatus.normal);
    });
  });

  group('formatValue', () {
    test('keeps small values exact, trimming a trailing .0', () {
      expect(formatValue(14.5), '14.5');
      expect(formatValue(14), '14');
      expect(formatValue(0), '0');
    });

    test('rounds to 2 decimal places', () {
      expect(formatValue(14.4444), '14.44');
    });

    test('adds thousands separators above 10,000', () {
      expect(formatValue(12345), '12,345');
    });

    test('abbreviates millions and billions', () {
      expect(formatValue(2500000), '2.50M');
      expect(formatValue(3200000000), '3.20B');
    });
  });

  group('initials', () {
    test('two words takes first letter of each', () {
      expect(initials('Ismail Hossain'), 'IH');
    });

    test('single word takes the first two letters', () {
      expect(initials('ismail'), 'IS');
    });

    test('empty input falls back to a placeholder', () {
      expect(initials(''), '?');
    });
  });

  group('fullName', () {
    test('joins first and last name when present', () {
      expect(fullName(firstName: 'Ismail', lastName: 'Hossain', username: 'ismail'), 'Ismail Hossain');
    });

    test('falls back to username when no name is set', () {
      expect(fullName(username: 'ismail'), 'ismail');
    });
  });
}
