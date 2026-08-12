import '../core/api/api_client.dart';
import '../models/catalogue_test.dart';

/// The full test catalogue behind the manual-entry picker —
/// `GET /tests`, distinct from `GET /trends/tests` (see `TrendTest`).
class TestsRepository {
  TestsRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<CatalogueTest>> list({String? query}) async {
    final json = await _api.get<List<dynamic>>(
      '/tests',
      query: query != null && query.isNotEmpty ? {'q': query} : null,
    );
    return json.map((e) => CatalogueTest.fromJson(e as Map<String, dynamic>)).toList();
  }
}
