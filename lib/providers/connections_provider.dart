import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';
import '../models/connections.dart';
import '../repositories/connections_repository.dart';

class ConnectionsProvider extends ChangeNotifier {
  ConnectionsProvider({required ConnectionsRepository connectionsRepository}) : _repo = connectionsRepository;

  final ConnectionsRepository _repo;

  ConnectionsResponse? data;
  bool loading = true;
  String? error;

  bool granting = false;
  String? grantError;

  final Set<String> busyUsernames = {};

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      data = await _repo.list();
    } catch (e) {
      error = e is ApiException ? e.message : "Couldn't load connections.";
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> grant(String username) async {
    granting = true;
    grantError = null;
    notifyListeners();
    try {
      await _repo.grant(username);
      await load();
      return true;
    } catch (e) {
      grantError = e is ApiException ? e.message : 'Could not grant access.';
      granting = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> revoke(String username) async {
    busyUsernames.add(username);
    notifyListeners();
    try {
      await _repo.revoke(username);
      await load();
    } catch (_) {
    } finally {
      busyUsernames.remove(username);
      notifyListeners();
    }
  }

  Future<void> leave(String username) async {
    busyUsernames.add(username);
    notifyListeners();
    try {
      await _repo.leave(username);
      await load();
    } catch (_) {
    } finally {
      busyUsernames.remove(username);
      notifyListeners();
    }
  }
}
