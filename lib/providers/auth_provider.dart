import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';
import '../models/session_user.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Session state for the whole app. Drives the router's auth-gated
/// redirects (see `core/router/app_router.dart`) and is the source of truth
/// for "am I logged in" everywhere else.
class AuthProvider extends ChangeNotifier {
  // ignore: prefer_initializing_formals
  AuthProvider({required AuthRepository authRepository}) : _authRepository = authRepository;

  final AuthRepository _authRepository;

  AuthStatus status = AuthStatus.unknown;
  SessionUser? user;
  String? error;
  bool busy = false;

  Future<void> restoreSession() async {
    if (!await _authRepository.hasToken()) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      user = await _authRepository.me();
      status = AuthStatus.authenticated;
    } catch (_) {
      // Stored token is no longer valid server-side.
      await _authRepository.logout();
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login({required String identifier, required String password}) =>
      _attempt(() => _authRepository.login(identifier: identifier, password: password));

  Future<bool> signup({required String email, required String username, required String password}) =>
      _attempt(() => _authRepository.signup(email: email, username: username, password: password));

  Future<bool> _attempt(Future<SessionUser> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      user = await action();
      status = AuthStatus.authenticated;
      return true;
    } catch (e) {
      error = e is ApiException ? e.message : "Couldn't reach the server. Try again.";
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Wired to `ApiClient.onUnauthorized` — the token was rejected
  /// server-side (expired/invalid), not a local logout.
  void forceLogout() {
    if (status != AuthStatus.authenticated) return;
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
