import 'package:intl/intl.dart';

/// Formatting helpers mirrored from the web app's `lib/format.ts`, kept
/// behaviourally identical so the two clients never disagree on how a value
/// reads.

String formatDate(DateTime value) => DateFormat('dd MMM yyyy').format(value);

String formatDateLong(DateTime value) => DateFormat('EEE, dd MMMM yyyy').format(value);

String relativeDate(DateTime value) {
  final days = (DateTime.now().difference(value).inHours / 24).round();
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 30) return '$days days ago';
  final months = (days / 30).round();
  if (months < 12) return '$months month${months == 1 ? '' : 's'} ago';
  final years = (months / 12).round();
  return '$years year${years == 1 ? '' : 's'} ago';
}

/// Large counts (cells/uL runs to the billions) are unreadable in full, so
/// abbreviate above a million while keeping small values exact.
String formatValue(num value) {
  final abs = value.abs();
  if (abs >= 1000000000) return '${(value / 1000000000).toStringAsFixed(2)}B';
  if (abs >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
  if (abs >= 10000) return NumberFormat.decimalPattern().format(value.round());
  final rounded = double.parse(value.toStringAsFixed(2));
  return rounded == rounded.roundToDouble() && rounded.abs() < 1e15
      ? rounded.toInt().toString()
      : rounded.toString();
}

enum RangeStatus { low, normal, high, unknown }

const Map<RangeStatus, String> statusLabel = {
  RangeStatus.low: 'Below range',
  RangeStatus.normal: 'In range',
  RangeStatus.high: 'Above range',
  RangeStatus.unknown: 'No reference',
};

RangeStatus rangeStatus(num value, num? low, num? high) {
  if (low == null && high == null) return RangeStatus.unknown;
  if (low != null && value < low) return RangeStatus.low;
  if (high != null && value > high) return RangeStatus.high;
  return RangeStatus.normal;
}

String initials(String name) {
  final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ').trim();
  if (cleaned.isEmpty) return '?';
  final parts = cleaned.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    return parts[0].substring(0, parts[0].length < 2 ? parts[0].length : 2).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String fullName({String? firstName, String? lastName, required String username}) {
  final name = [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ').trim();
  return name.isNotEmpty ? name : username;
}

class DateRangeOption {
  const DateRangeOption(this.value, this.label);
  final String value;
  final String label;
}

const dateRanges = [
  DateRangeOption('all', 'All time'),
  DateRangeOption('week', 'Last week'),
  DateRangeOption('15days', 'Last 15 days'),
  DateRangeOption('month', 'Last month'),
  DateRangeOption('year', 'Last year'),
  DateRangeOption('custom', 'Custom range'),
];
