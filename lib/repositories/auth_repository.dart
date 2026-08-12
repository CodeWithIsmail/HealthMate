import '../core/api/api_client.dart';
import '../core/storage/token_storage.dart';
import '../models/session_user.dart';

class AuthRepository {
  AuthRepository({required ApiClient apiClient, required TokenStorage tokenStorage})
    : _api = apiClient,
      // ignore: prefer_initializing_formals
      _tokenStorage = tokenStorage;

  final ApiClient _api;
  final TokenStorage _tokenStorage;

  Future<SessionUser> signup({required String email, required String username, required String password}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/auth/signup',
      data: {'email': email, 'username': username, 'password': password},
    );
    return _persist(json);
  }

  /// [identifier] accepts either a username or an email — that's the API's field name.
  Future<SessionUser> login({required String identifier, required String password}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'identifier': identifier, 'password': password},
    );
    return _persist(json);
  }

  Future<void> logout() async {
    await _tokenStorage.clearToken();
    try {
      await _api.post<void>('/auth/logout');
    } catch (_) {
      // Local token is already cleared; a failed server-side clear (e.g. offline) isn't fatal.
    }
  }

  Future<SessionUser> me() async {
    final json = await _api.get<Map<String, dynamic>>('/auth/me');
    return SessionUser.fromJson(json);
  }

  Future<bool> hasToken() async => (await _tokenStorage.readToken()) != null;

  Future<SessionUser> _persist(Map<String, dynamic> json) async {
    final token = json['token'] as String;
    await _tokenStorage.saveToken(token);
    return SessionUser.fromJson(json['user'] as Map<String, dynamic>);
  }
}
