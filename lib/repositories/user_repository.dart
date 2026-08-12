import '../core/api/api_client.dart';
import '../models/user_profile.dart';

class UserRepository {
  UserRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Omit [username] for the caller's own profile.
  Future<UserProfile> profile({String? username}) async {
    final json = await _api.get<Map<String, dynamic>>(
      username == null ? '/users/me' : '/users/$username',
    );
    return UserProfile.fromJson(json);
  }

  Future<List<PersonCard>> search(String query) async {
    final json = await _api.get<List<dynamic>>('/users/search', query: {'q': query});
    return json.map((e) => PersonCard.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UserProfile> updateProfile(Map<String, dynamic> fields) async {
    final json = await _api.patch<Map<String, dynamic>>('/users/me', data: fields);
    return UserProfile.fromJson(json);
  }

  Future<UserProfile> uploadAvatar(String filePath) async {
    final json = await _api.postMultipart<Map<String, dynamic>>(
      '/users/me/avatar',
      filePath: filePath,
      fieldName: 'file',
    );
    return UserProfile.fromJson(json);
  }
}
