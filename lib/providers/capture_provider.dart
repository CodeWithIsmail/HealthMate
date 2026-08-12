import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';
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

  String? imagePath;
  DateTime reportDate = DateTime.now();
  String title = '';
  List<CaptureRow> rows = [];

  String? uploadedImageUrl;
  String? extractionProvider; // 'gemini' | 'stub'
  String? degradedReason;

  String? analysis;
  String? analysisProvider;
  List<ChatTurn> chat = [];

  List<CatalogueTest> catalogue = [];
  bool catalogueLoading = false;

  /// 'extract' | 'analyze' | 'chat' | 'save' | null
  String? busy;
  String? error;

  bool get isStub => extractionProvider == 'stub';

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
    imagePath = path;
    notifyListeners();
  }

  void clearImage() {
    imagePath = null;
    notifyListeners();
  }

  Future<void> extract() async {
    if (imagePath == null) return;
    busy = 'extract';
    error = null;
    notifyListeners();
    try {
      final res = await _reportRepo.extract(imagePath!);
      uploadedImageUrl = res.imageUrl;
      extractionProvider = res.provider;
      degradedReason = res.degradedReason;
      rows = res.values
          .map(
            (v) => CaptureRow(
              testId: v.testId,
              name: v.canonicalName,
              unit: v.unit,
              valueText: _trimTrailingZeros(v.value),
              refLow: v.refLow,
              refHigh: v.refHigh,
              matchedBy: v.matchedBy,
            ),
          )
          .toList();
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
    if (imagePath == null) return;
    busy = 'analyze';
    notifyListeners();
    try {
      final res = await _reportRepo.analyze(imagePath!);
      analysis = res.text;
      analysisProvider = res.provider;
    } catch (_) {
      analysis = null;
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
        if (analysis != null)
          ChatTurn(role: 'model', text: analysis!.length > 4000 ? analysis!.substring(0, 4000) : analysis!),
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

  void updateValue(String testId, String value) {
    for (final row in rows) {
      if (row.testId == testId) row.valueText = value;
    }
    notifyListeners();
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
        summary: analysis,
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

  static String _trimTrailingZeros(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}
