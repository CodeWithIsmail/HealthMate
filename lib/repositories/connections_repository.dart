import '../core/api/api_client.dart';
import '../models/connections.dart';
import '../models/user_profile.dart';

class ConnectionsRepository {
  ConnectionsRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<ConnectionsResponse> list() async {
    final json = await _api.get<Map<String, dynamic>>('/connections');
    return ConnectionsResponse.fromJson(json);
  }

  Future<PersonCard> grant(String username) async {
    final json = await _api.post<Map<String, dynamic>>('/connections/viewers', data: {'username': username});
    return PersonCard.fromJson(json);
  }

  Future<void> revoke(String username) => _api.delete<void>('/connections/viewers/$username');

  Future<void> leave(String username) => _api.delete<void>('/connections/access/$username');
}
