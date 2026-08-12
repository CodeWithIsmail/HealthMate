import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';
import '../models/user_profile.dart';
import '../repositories/connections_repository.dart';
import '../repositories/user_repository.dart';

class PeopleSearchProvider extends ChangeNotifier {
  PeopleSearchProvider({required UserRepository userRepository, required ConnectionsRepository connectionsRepository})
    : _userRepo = userRepository,
      _connectionsRepo = connectionsRepository;

  final UserRepository _userRepo;
  final ConnectionsRepository _connectionsRepo;

  String term = '';
  List<PersonCard>? results;
  bool searching = false;
  String? error;
  String? notice;

  Timer? _debounce;

  void setTerm(String value) {
    term = value;
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      results = null;
      searching = false;
      notifyListeners();
      return;
    }
    searching = true;
    notifyListeners();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    try {
      final found = await _userRepo.search(q);
      // A stale debounce could still land after the term changed again.
      if (q != term.trim()) return;
      results = found;
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'Search failed.';
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  Future<void> grant(String username) async {
    error = null;
    try {
      await _connectionsRepo.grant(username);
      notice = '$username can now view your health data.';
      _patch(username, theyCanViewMe: true);
    } catch (e) {
      error = e is ApiException ? e.message : 'Could not grant access.';
      notifyListeners();
    }
  }

  Future<void> revoke(String username) async {
    try {
      await _connectionsRepo.revoke(username);
      notice = '$username no longer has access.';
      _patch(username, theyCanViewMe: false);
    } catch (_) {}
  }

  void _patch(String username, {required bool theyCanViewMe}) {
    results = results
        ?.map(
          (p) => p.username != username
              ? p
              : PersonCard(
                  id: p.id,
                  username: p.username,
                  firstName: p.firstName,
                  lastName: p.lastName,
                  imageUrl: p.imageUrl,
                  grantedAt: p.grantedAt,
                  iCanViewThem: p.iCanViewThem,
                  theyCanViewMe: theyCanViewMe,
                ),
        )
        .toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
