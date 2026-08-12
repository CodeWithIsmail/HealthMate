import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';
import '../models/user_profile.dart';
import '../repositories/user_repository.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider({required UserRepository userRepository}) : _repo = userRepository;

  final UserRepository _repo;

  UserProfile? profile;
  bool loading = true;
  String? error;
  String? username;

  bool saving = false;
  String? saveError;

  bool avatarUploading = false;
  String? avatarError;

  Future<void> load({String? username}) async {
    this.username = username;
    loading = true;
    error = null;
    notifyListeners();
    try {
      profile = await _repo.profile(username: username);
    } catch (e) {
      error = e is ApiException ? e.message : "Couldn't load this profile.";
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> save(Map<String, dynamic> fields) async {
    saving = true;
    saveError = null;
    notifyListeners();
    try {
      await _repo.updateProfile(fields);
      profile = await _repo.profile();
      return true;
    } catch (e) {
      saveError = e is ApiException ? e.message : 'Could not save your profile.';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> uploadAvatar(String filePath) async {
    avatarUploading = true;
    avatarError = null;
    notifyListeners();
    try {
      await _repo.uploadAvatar(filePath);
      profile = await _repo.profile();
      return true;
    } catch (e) {
      avatarError = e is ApiException ? e.message : 'Avatar upload failed.';
      return false;
    } finally {
      avatarUploading = false;
      notifyListeners();
    }
  }
}
