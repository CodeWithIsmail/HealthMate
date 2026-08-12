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

  /// Both `PATCH /users/me` and `POST /users/me/avatar` return only the bare
  /// profile fields — no `stats`/`isSelf`/`age`/`bmi` — so callers refetch
  /// via [profile] afterwards rather than trying to parse a full
  /// [UserProfile] out of these responses.
  Future<void> updateProfile(Map<String, dynamic> fields) =>
      _api.patch<void>('/users/me', data: fields);

  Future<void> uploadAvatar(String filePath) => _api.postMultipart<void>(
    '/users/me/avatar',
    filePath: filePath,
    fieldName: 'file',
  );
}
