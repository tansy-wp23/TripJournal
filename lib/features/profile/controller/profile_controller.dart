import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/profile_avatar_storage.dart';
import '../../../data/profile_repository.dart';
import '../../../data/user_management_repository_locator.dart';
import '../../../models/profile.dart';
import '../../../validation/photo_validation.dart';
import '../../../validation/profile_validation.dart';
import '../../auth/controller/auth_controller.dart';

/// Controls the profile view/edit flow (PB-09 through PB-12).
///
/// Reads the current user id from [AuthController] (which derives it from
/// the Supabase session) and loads/updates the [Profile] via
/// [ProfileRepository]. Maps to the "Profile Management" component from
/// Component.md.
class ProfileController extends ChangeNotifier {
  ProfileController(
    this._profileRepository,
    this._authController,
    this._profileAvatarStorage,
  );

  final ProfileRepository _profileRepository;
  final AuthController _authController;
  final ProfileAvatarStorage _profileAvatarStorage;

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
    } catch (_) {
      _error = 'Failed to load profile. Please try again.';
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
      // AuthController holds its own cached Profile, and doesn't see this
      // update on its own since the write went through ProfileRepository
      // directly — see the note on AuthController.refreshProfile(). Without
      // this, screens reading authControllerProvider's profile (e.g. the
      // publish flow's "shared by" name) keep showing the pre-edit value
      // until the next sign-in.
      await _authController.refreshProfile();
      return null;
    } catch (_) {
      _error = 'Failed to save profile. Please try again.';
      notifyListeners();
      return _error;
    }
  }

  /// Validates and saves date of birth / country / travel interests from
  /// the profile edit screen — the same three fields onboarding collects,
  /// for a user filling them in (or changing them) after the fact.
  /// Deliberately separate from [completeOnboarding]: this never touches
  /// [Profile.profileCompleted], since an already-onboarded user editing
  /// their profile isn't "completing" anything.
  Future<String?> updateTravelDetails({
    DateTime? dateOfBirth,
    String? country,
    required Set<String> travelInterests,
  }) async {
    final dobError = validateDateOfBirth(dateOfBirth);
    if (dobError != null) return dobError;

    final current = _profile;
    if (current == null) return 'No profile to update.';

    _error = null;
    try {
      _profile = await _profileRepository.updateProfile(
        current.copyWith(
          dateOfBirth: dateOfBirth,
          clearDateOfBirth: dateOfBirth == null,
          country: country,
          clearCountry: country == null,
          travelInterests: travelInterests.toList(),
          updatedAt: DateTime.now(),
        ),
      );
      notifyListeners();
      // See the matching note in updateDisplayName().
      await _authController.refreshProfile();
      return null;
    } catch (_) {
      _error = 'Failed to save profile. Please try again.';
      notifyListeners();
      return _error;
    }
  }

  /// Validates and saves the fields collected by the onboarding screen,
  /// then marks the profile complete so [AuthController.status] stops
  /// routing to [AuthStatus.needsOnboarding]. A single combined update
  /// (name + DOB + country + interests + the completed flag together)
  /// rather than the edit screen's separate name/avatar calls — onboarding
  /// is one save, not a series of independent edits, so one round trip
  /// keeps a half-entered form from partially failing.
  ///
  /// Avatar is intentionally not a parameter here — call [updateAvatar]
  /// first if the user picked one, same as the edit screen does, since it
  /// needs its own upload step before a URL exists to save.
  ///
  /// Returns an error message on failure, or null on success (including a
  /// name/DOB validation failure — the caller's form should already have
  /// run the same validators, but this is the backstop per
  /// IMPLEMENTATION_PLAN_VALIDATION.md's "Where Validation Lives").
  Future<String?> completeOnboarding({
    required String displayName,
    DateTime? dateOfBirth,
    String? country,
    required Set<String> travelInterests,
  }) async {
    final nameError = validateProfileDisplayName(displayName);
    if (nameError != null) return nameError;
    final dobError = validateDateOfBirth(dateOfBirth);
    if (dobError != null) return dobError;

    final current = _profile;
    if (current == null) return 'No profile to update.';

    _error = null;
    try {
      _profile = await _profileRepository.updateProfile(
        current.copyWith(
          displayName: displayName.trim(),
          dateOfBirth: dateOfBirth,
          clearDateOfBirth: dateOfBirth == null,
          country: country,
          clearCountry: country == null,
          travelInterests: travelInterests.toList(),
          profileCompleted: true,
          updatedAt: DateTime.now(),
        ),
      );
      notifyListeners();
      // AuthController holds its own cached Profile (that's what
      // AuthGate/AuthStatus.needsOnboarding reads) — it doesn't see this
      // update on its own since the write went through ProfileRepository
      // directly, not through AuthController. Without this, the onboarding
      // screen would stay on screen forever after a successful save.
      await _authController.refreshProfile();
      return null;
    } catch (_) {
      _error = 'Failed to save profile. Please try again.';
      notifyListeners();
      return _error;
    }
  }

  /// Marks onboarding complete without touching any other field — the
  /// "Skip for now" path. The user keeps whatever display name they already
  /// had (derived from their Google account at sign-up) and can fill the
  /// rest in later from the profile edit screen; they must never be trapped
  /// on the onboarding screen or nagged again next login.
  Future<String?> skipOnboarding() async {
    final current = _profile;
    if (current == null) return 'No profile to update.';

    _error = null;
    try {
      _profile = await _profileRepository.updateProfile(
        current.copyWith(profileCompleted: true, updatedAt: DateTime.now()),
      );
      notifyListeners();
      await _authController.refreshProfile();
      return null;
    } catch (_) {
      _error = 'Failed to save profile. Please try again.';
      notifyListeners();
      return _error;
    }
  }

  /// Validates [photo]'s size, uploads it, and points the profile at the
  /// result. The previous avatar (if any) is deleted only after the profile
  /// update succeeds, so a failed upload never orphans the old one. Returns
  /// an error message on failure, or null on success.
  Future<String?> updateAvatar(XFile photo) async {
    final current = _profile;
    if (current == null) return 'No profile to update.';

    final Uint8List bytes;
    try {
      bytes = await photo.readAsBytes();
    } catch (_) {
      return "Couldn't read that photo.";
    }
    final sizeError = validatePhotoSize(bytes.length);
    if (sizeError != null) return sizeError;

    _error = null;
    try {
      final uploadedUrl = await _profileAvatarStorage.uploadAvatar(
        userId: current.userID,
        photo: photo,
      );
      final previousUrl = current.avatarUrl;
      _profile = await _profileRepository.updateProfile(
        current.copyWith(avatarUrl: uploadedUrl, updatedAt: DateTime.now()),
      );
      if (previousUrl != null && previousUrl != uploadedUrl) {
        await _profileAvatarStorage.deleteAvatarUrl(previousUrl);
      }
      notifyListeners();
      // See the matching note in updateDisplayName().
      await _authController.refreshProfile();
      return null;
    } catch (_) {
      _error = "Couldn't update your profile photo. Please try again.";
      notifyListeners();
      return _error;
    }
  }

  /// Clears the profile's avatar. Returns an error message on failure, or
  /// null on success (including when there was no avatar to remove).
  Future<String?> removeAvatar() async {
    final current = _profile;
    if (current == null) return 'No profile to update.';
    final previousUrl = current.avatarUrl;
    if (previousUrl == null) return null;

    _error = null;
    try {
      _profile = await _profileRepository.updateProfile(
        current.copyWith(clearAvatarUrl: true, updatedAt: DateTime.now()),
      );
      await _profileAvatarStorage.deleteAvatarUrl(previousUrl);
      notifyListeners();
      // See the matching note in updateDisplayName().
      await _authController.refreshProfile();
      return null;
    } catch (_) {
      _error = "Couldn't update your profile photo. Please try again.";
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
    profileAvatarStorage,
  ),
);