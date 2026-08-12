import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT issued by `POST /auth/login` / `/auth/signup` across
/// launches. The API also accepts an httpOnly cookie, but that's for the web
/// client — this app always sends the token as a Bearer header.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'healthmate_token';

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
