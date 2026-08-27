import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';
import '../core/privacy/pii_patterns.dart';
import '../core/privacy/redaction_outcome.dart';
import '../models/catalogue_test.dart';
import '../models/extraction.dart';
import '../models/report.dart';
import '../repositories/report_repository.dart';
import '../repositories/tests_repository.dart';

enum CaptureMode { scan, manual }

enum CaptureStep { input, review }

class CaptureRow {
  CaptureRow({
    required this.testId,
    required this.name,
    this.unit,
    this.valueText = '',
    this.refLow,
    this.refHigh,
    this.matchedBy,
  });

  final String testId;
  final String name;
  final String? unit;
  String valueText;
  final double? refLow;
  final double? refHigh;
  final MatchedBy? matchedBy;
}

/// Drives the combined "scan a report" / "enter manually" flow — mirrors the
/// web app's `/reports/new` page: pick or type values, review, save.
/// Nothing is persisted server-side until [save] is called.
class CaptureProvider extends ChangeNotifier {
  CaptureProvider({required ReportRepository reportRepository, required TestsRepository testsRepository})
    : _reportRepo = reportRepository,
      _testsRepo = testsRepository;

  final ReportRepository _reportRepo;
  final TestsRepository _testsRepo;

  CaptureMode mode = CaptureMode.scan;
  CaptureStep step = CaptureStep.input;

  /// The photo as picked and cropped. Stays on the device — it is shown
  /// nowhere and uploaded nowhere; only [sanitizedImagePath] leaves the phone.
  String? originalImagePath;

  /// The redacted copy produced by `RedactionScreen`. **The only image path
  /// that may be sent to the API.** Null until the user has confirmed the
  /// redaction, which is what keeps an unscanned original from being uploaded.
  String? sanitizedImagePath;

  /// How many regions were hidden, per category — drives the "N items hidden"
  /// badge on the capture screen.
  Map<PiiCategory, int> redactionSummary = const {};

  DateTime reportDate = DateTime.now();
  String title = '';
  List<CaptureRow> rows = [];

  String? uploadedImageUrl;
  String? extractionProvider; // 'gemini' | 'stub'
  String? degradedReason;

  /// Set when the extraction returned two readings for the same catalogue
  /// test and the later one had to be dropped — see [rowsFromExtraction].
  /// Shown on the review step so the loss is never silent.
  String? duplicateNote;

  String? analysisEn;
  String? analysisBn;
  String? analysisProvider;
  List<ChatTurn> chat = [];

  List<CatalogueTest> catalogue = [];
  bool catalogueLoading = false;

  /// 'extract' | 'analyze' | 'chat' | 'save' | null
  String? busy;
  String? error;

  bool get isStub => extractionProvider == 'stub';

  bool get hasImage => originalImagePath != null;

  /// True once the picked image has been through the redaction step.
  bool get isSanitized => sanitizedImagePath != null;

  int get hiddenCount => redactionSummary.values.fold(0, (sum, count) => sum + count);

  /// Canonical test names handed to the PII detector so it never blacks out a
  /// result row (see `PiiDetector`).
  List<String> get catalogueNames => catalogue.map((test) => test.name).toList();

  Future<void> loadCatalogue() async {
    catalogueLoading = true;
    notifyListeners();
    try {
      catalogue = await _testsRepo.list();
    } catch (_) {
      catalogue = [];
    } finally {
      catalogueLoading = false;
      notifyListeners();
    }
  }

  void setMode(CaptureMode m) {
    mode = m;
    notifyListeners();
  }

  void pickImage(String path) {
    originalImagePath = path;
    sanitizedImagePath = null;
    redactionSummary = const {};
    notifyListeners();
  }

  /// Called by `RedactionScreen` once the user has confirmed what to hide.
  void applyRedaction(RedactionOutcome outcome) {
    sanitizedImagePath = outcome.imagePath;
    redactionSummary = outcome.hiddenByCategory;
    error = null;
    notifyListeners();
  }

  void clearImage() {
    originalImagePath = null;
    sanitizedImagePath = null;
    redactionSummary = const {};
    notifyListeners();
  }

  Future<void> extract() async {
    final path = sanitizedImagePath;
    if (path == null) {
      // Belt and braces: the button is disabled until redaction is confirmed,
      // and this makes it impossible for a later refactor to upload the
      // untouched original by accident.
      error = 'Hide any personal details on the image before extracting.';
      notifyListeners();
      return;
    }
    busy = 'extract';
    error = null;
    notifyListeners();
    try {
      final res = await _reportRepo.extract(path);
      uploadedImageUrl = res.imageUrl;
      extractionProvider = res.provider;
      degradedReason = res.degradedReason;
      final (extracted, dropped) = rowsFromExtraction(res.values);
      rows = extracted;
      duplicateNote = dropped.isEmpty
          ? null
          : 'Two lines in your report were read as the same test '
                '(${dropped.toSet().join(', ')}). Only the first reading of each was kept — '
                'check it against the image below.';
      step = CaptureStep.review;
      busy = null;
      notifyListeners();
      unawaited(_analyze());
    } catch (e) {
      error = e is ApiException ? e.message : 'Extraction failed. Try another image.';
      busy = null;
      notifyListeners();
    }
  }

  Future<void> _analyze() async {
    final path = sanitizedImagePath;
    if (path == null) return;
    busy = 'analyze';
    notifyListeners();
    try {
      final res = await _reportRepo.analyze(path);
      analysisEn = res.textEn;
      analysisBn = res.textBn;
      analysisProvider = res.provider;
    } catch (_) {
      analysisEn = null;
      analysisBn = null;
    } finally {
      busy = null;
      notifyListeners();
    }
  }

  Future<void> ask(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return;
    chat = [...chat, ChatTurn(role: 'user', text: trimmed)];
    busy = 'chat';
    notifyListeners();
    try {
      final history = [
        if (analysisEn != null)
          ChatTurn(role: 'model', text: analysisEn!.length > 4000 ? analysisEn!.substring(0, 4000) : analysisEn!),
        ...chat,
      ];
      final windowed = history.length > 20 ? history.sublist(history.length - 20) : history;
      final res = await _reportRepo.chat(message: trimmed, history: windowed);
      chat = [...chat, ChatTurn(role: 'model', text: res.text)];
    } catch (e) {
      chat = [...chat, ChatTurn(role: 'model', text: e is ApiException ? e.message : 'Request failed.')];
    } finally {
      busy = null;
      notifyListeners();
    }
  }

  void addRow(String testId) {
    if (rows.any((r) => r.testId == testId)) return;
    final t = catalogue.firstWhere((c) => c.id == testId);
    rows = [...rows, CaptureRow(testId: t.id, name: t.name, unit: t.unit, refLow: t.refLow, refHigh: t.refHigh)];
    notifyListeners();
  }

  void removeRow(String testId) {
    rows = rows.where((r) => r.testId != testId).toList();
    notifyListeners();
  }

  /// Deliberately does **not** notify. Only the edited row reacts to a
  /// keystroke (its own status pill), and it rebuilds itself; notifying here
  /// rebuilt all ~25 rows of a scanned report on every character typed.
  /// [save] reads `valueText` directly, and add/remove still notify.
  void updateValue(String testId, String value) {
    for (final row in rows) {
      if (row.testId == testId) row.valueText = value;
    }
  }

  void setTitle(String value) {
    title = value;
  }

  void setReportDate(DateTime date) {
    reportDate = date;
    notifyListeners();
  }

  void goToReview() {
    step = CaptureStep.review;
    notifyListeners();
  }

  void backToInput() {
    step = CaptureStep.input;
    notifyListeners();
  }

  Future<String?> save() async {
    final values = <({String testId, double value})>[];
    for (final row in rows) {
      final parsed = double.tryParse(row.valueText.trim());
      if (parsed != null) values.add((testId: row.testId, value: parsed));
    }
    if (values.isEmpty) {
      error = 'Enter at least one value before saving.';
      notifyListeners();
      return null;
    }

    busy = 'save';
    error = null;
    notifyListeners();
    try {
      final id = await _reportRepo.create(
        reportDate: reportDate,
        title: title.trim().isEmpty ? null : title.trim(),
        imageUrl: uploadedImageUrl,
        summary: analysisEn,
        summaryBn: analysisBn,
        source: mode == CaptureMode.scan ? ReportSource.ocr : ReportSource.manual,
        values: values,
      );
      return id;
    } catch (e) {
      error = e is ApiException ? e.message : 'Could not save the report.';
      return null;
    } finally {
      busy = null;
      notifyListeners();
    }
  }

  /// Extraction rows, with any repeated `testId` dropped.
  ///
  /// A lab report can print the same measurement under two names ("HCT" and
  /// "PCV", "SGPT" and "ALT"), and the API's catalogue matching resolves both
  /// to one canonical test. Two rows sharing a `testId` cannot work here:
  /// [updateValue] and [removeRow] address rows *by* `testId`, so editing one
  /// would edit both and deleting one would delete both, and the save payload
  /// carries a single value per test regardless. The duplicate is therefore
  /// dropped at the point it arrives — and reported, via [duplicateNote],
  /// rather than disappearing quietly.
  ///
  /// Returns the rows to show and the canonical names that were dropped.
  static (List<CaptureRow>, List<String>) rowsFromExtraction(List<ExtractedValue> values) {
    final seen = <String>{};
    final kept = <CaptureRow>[];
    final dropped = <String>[];

    for (final v in values) {
      if (!seen.add(v.testId)) {
        dropped.add(v.canonicalName);
        continue;
      }
      kept.add(
        CaptureRow(
          testId: v.testId,
          name: v.canonicalName,
          unit: v.unit,
          valueText: _trimTrailingZeros(v.value),
          refLow: v.refLow,
          refHigh: v.refHigh,
          matchedBy: v.matchedBy,
        ),
      );
    }

    return (kept, dropped);
  }

  static String _trimTrailingZeros(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}
