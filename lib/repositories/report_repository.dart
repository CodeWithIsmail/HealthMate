import '../core/api/api_client.dart';
import '../models/extraction.dart';
import '../models/report.dart';

class ReportRepository {
  ReportRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<ReportsListResponse> list({String? username, String range = 'all', String? from, String? to}) async {
    final query = <String, dynamic>{'range': range};
    if (username != null) query['username'] = username;
    if (range == 'custom') {
      query['from'] = from;
      query['to'] = to;
    }
    final json = await _api.get<Map<String, dynamic>>('/reports', query: query);
    return ReportsListResponse.fromJson(json);
  }

  Future<ReportDetail> detail(String id) async {
    final json = await _api.get<Map<String, dynamic>>('/reports/$id');
    return ReportDetail.fromJson(json);
  }

  Future<String> create({
    required DateTime reportDate,
    String? title,
    String? imageUrl,
    String? summary,
    String? summaryBn,
    required ReportSource source,
    required List<({String testId, double value})> values,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/reports',
      data: {
        'reportDate': reportDate.toIso8601String().split('T').first,
        if (title != null && title.isNotEmpty) 'title': title,
        'imageUrl': ?imageUrl,
        'summary': ?summary,
        'summaryBn': ?summaryBn,
        'source': source.apiValue,
        'values': values.map((v) => {'testId': v.testId, 'value': v.value}).toList(),
      },
    );
    return json['id'] as String;
  }

  Future<void> remove(String id) => _api.delete<void>('/reports/$id');

  Future<void> share(String id, String username) =>
      _api.post<void>('/reports/$id/share', data: {'username': username});

  Future<void> unshare(String id, String username) => _api.delete<void>('/reports/$id/share/$username');

  Future<ExtractionResponse> extract(String filePath) async {
    final json = await _api.postMultipart<Map<String, dynamic>>(
      '/reports/extract',
      filePath: filePath,
      fieldName: 'file',
    );
    return ExtractionResponse.fromJson(json);
  }

  Future<AnalyzeResponse> analyze(String filePath) async {
    final json = await _api.postMultipart<Map<String, dynamic>>(
      '/reports/analyze',
      filePath: filePath,
      fieldName: 'file',
    );
    return AnalyzeResponse.fromJson(json);
  }

  Future<ChatResponse> chat({required String message, List<ChatTurn> history = const []}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/reports/chat',
      data: {'message': message, 'history': history.map((t) => t.toJson()).toList()},
    );
    return ChatResponse.fromJson(json);
  }
}
