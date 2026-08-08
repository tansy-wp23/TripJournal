import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/profile_repository.dart';
import '../../../data/user_management_repository_locator.dart';
import '../../../models/profile.dart';
import '../../../validation/profile_validation.dart';
import '../../auth/controller/auth_controller.dart';

/// Controls the profile view/edit flow (PB-09 through PB-12).
///
/// Reads the current user id from [AuthController] (which derives it from
/// the Supabase session) and loads/updates the [Profile] via
/// [ProfileRepository]. Maps to the "Profile Management" component from
/// Component.md.
class ProfileController extends ChangeNotifier {
  ProfileController(this._profileRepository, this._authController);

  final ProfileRepository _profileRepository;
  final AuthController _authController;

  Profile? _profile;
  bool _loading = false;
  String? _error;

  Profile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;

  /// Loads the profile for the currently signed-in user.
  Future<void> loadProfile() async {
    final userId = _authController.currentUserId;
    if (userId == null) {
      _error = 'Not signed in.';
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _profileRepository.getProfile(userId);
      if (_profile == null) {
        _error = 'No profile found.';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Validates [displayName] and, if valid, updates the profile. Returns an
  /// error message on failure, or null on success.
  Future<String?> updateDisplayName(String displayName) async {
    final validationError = validateProfileDisplayName(displayName);
    if (validationError != null) return validationError;

    final current = _profile;
    if (current == null) return 'No profile to update.';

    _error = null;
    try {
      _profile = await _profileRepository.updateProfile(
        current.copyWith(
          displayName: displayName.trim(),
          updatedAt: DateTime.now(),
        ),
      );
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error;
    }
  }
}

/// The single place the app resolves its [ProfileController] from — mirrors
/// `authControllerProvider` / `tripControllerProvider`.
final profileControllerProvider = ChangeNotifierProvider<ProfileController>(
  (ref) => ProfileController(
    profileRepository,
    ref.watch(authControllerProvider),
  ),
);