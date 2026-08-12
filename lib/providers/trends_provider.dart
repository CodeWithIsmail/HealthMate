import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';
import '../models/report.dart';
import '../models/trend.dart';
import '../repositories/trends_repository.dart';

/// Test names to land on when several are tied on point count — a headline
/// metric people actually come here to see, rather than an arbitrary tie
/// break (in practice, alphabetically-first tests like "Basophils").
const _preferredTests = ['Haemoglobin', 'Fasting Blood Sugar', 'Total Cholesterol', 'Platelet Count'];

class TrendsProvider extends ChangeNotifier {
  TrendsProvider({required TrendsRepository trendsRepository}) : _repo = trendsRepository;

  final TrendsRepository _repo;

  String? username;
  List<TrendTest> tests = [];
  bool testsLoading = true;
  String? testsError;

  String? selectedTestId;
  String range = 'all';
  DateTime? customFrom;
  DateTime? customTo;

  TrendSeries? series;
  bool seriesLoading = false;
  String? seriesError;

  OwnerRef? get owner => series?.owner;

  Future<void> loadTests({String? username}) async {
    this.username = username;
    testsLoading = true;
    testsError = null;
    notifyListeners();
    try {
      final res = await _repo.availableTests(username: username);
      tests = res.tests;
      final preferred = _preferredTests
          .map((name) {
            for (final t in tests) {
              if (t.name == name) return t;
            }
            return null;
          })
          .whereType<TrendTest>()
          .firstOrNull;
      final sorted = [...tests]..sort((a, b) => b.pointCount.compareTo(a.pointCount));
      final best = preferred ?? (sorted.isNotEmpty ? sorted.first : null);
      selectedTestId = best?.id;
    } catch (e) {
      testsError = e is ApiException ? e.message : "Couldn't load trends.";
      tests = [];
    } finally {
      testsLoading = false;
      notifyListeners();
    }
    if (selectedTestId != null) await loadSeries();
  }

  Future<void> selectTest(String testId) async {
    selectedTestId = testId;
    await loadSeries();
  }

  Future<void> setRange(String newRange, {DateTime? from, DateTime? to}) async {
    range = newRange;
    customFrom = from;
    customTo = to;
    await loadSeries();
  }

  Future<void> loadSeries() async {
    final testId = selectedTestId;
    if (testId == null) return;
    seriesLoading = true;
    seriesError = null;
    notifyListeners();
    try {
      series = await _repo.series(
        testId: testId,
        username: username,
        range: range,
        from: customFrom?.toIso8601String().split('T').first,
        to: customTo?.toIso8601String().split('T').first,
      );
    } catch (e) {
      seriesError = e is ApiException ? e.message : "Couldn't load this test's history.";
      series = null;
    } finally {
      seriesLoading = false;
      notifyListeners();
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
