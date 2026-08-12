import '../core/api/api_client.dart';
import '../models/trend.dart';

class TrendsRepository {
  TrendsRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<TrendsAvailableResponse> availableTests({String? username}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/trends/tests',
      query: username != null ? {'username': username} : null,
    );
    return TrendsAvailableResponse.fromJson(json);
  }

  Future<TrendSeries> series({
    required String testId,
    String? username,
    String range = 'all',
    String? from,
    String? to,
  }) async {
    final query = <String, dynamic>{'testId': testId, 'range': range};
    if (username != null) query['username'] = username;
    if (range == 'custom') {
      query['from'] = from;
      query['to'] = to;
    }
    final json = await _api.get<Map<String, dynamic>>('/trends/series', query: query);
    return TrendSeries.fromJson(json);
  }
}
