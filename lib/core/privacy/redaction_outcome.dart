import 'pii_patterns.dart';

/// What the redaction screen hands back: the file that is safe to upload, and
/// a count of what was hidden so the capture screen can show
/// "4 items hidden before upload".
///
/// [imagePath] is the **only** path that may be sent to the API. The picked
/// original stays on the device.
class RedactionOutcome {
  const RedactionOutcome({required this.imagePath, required this.hiddenByCategory});

  final String imagePath;
  final Map<PiiCategory, int> hiddenByCategory;

  int get hiddenCount => hiddenByCategory.values.fold(0, (sum, count) => sum + count);
}
