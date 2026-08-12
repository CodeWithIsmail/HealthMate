import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';
import '../models/report.dart';
import '../repositories/report_repository.dart';

/// Backs the reports list screen: current date-range filter, the loaded
/// list, and delete. `username` is set when viewing reports someone else
/// shared with the caller (read-only in that case — see `ReportsListResponse.owner.isSelf`).
class ReportProvider extends ChangeNotifier {
  ReportProvider({required ReportRepository reportRepository}) : _repo = reportRepository;

  final ReportRepository _repo;

  bool loading = false;
  String? error;
  OwnerRef? owner;
  List<ReportSummary> reports = [];
  String range = 'all';
  DateTime? customFrom;
  DateTime? customTo;
  String? username;

  Future<void> load({String? username}) async {
    this.username = username ?? this.username;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _repo.list(
        username: this.username,
        range: range,
        from: customFrom?.toIso8601String().split('T').first,
        to: customTo?.toIso8601String().split('T').first,
      );
      owner = res.owner;
      reports = res.reports;
    } catch (e) {
      error = e is ApiException ? e.message : "Couldn't load reports.";
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setRange(String newRange, {DateTime? from, DateTime? to}) {
    range = newRange;
    customFrom = from;
    customTo = to;
    return load();
  }

  Future<bool> delete(String id) async {
    try {
      await _repo.remove(id);
      reports = reports.where((r) => r.id != id).toList();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
