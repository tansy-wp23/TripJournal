import '../models/profile.dart';

/// Maps to the "Account Creation" and "Profile Management" components from
/// Component.md. Plain get/update go through RLS-protected direct table
/// access (Phase 7); no Edge Function needed for these.
abstract class ProfileRepository {
  /// Fetches the profile for [userId]. Returns null if no profile exists yet.
  Future<Profile?> getProfile(String userId);

  /// Creates a profile if one doesn't already exist for [userId].
  ///
  /// In Phase 6 a Postgres trigger (`handle_new_user`) becomes the primary
  /// server-side source of truth for account creation; this call becomes a
  /// defensive fallback. Returns the profile (existing or newly created).
  Future<Profile> createProfileIfMissing({
    required String userId,
    required String email,
    required String displayName,
  });

  /// Updates the given profile. Only the caller's own row is writable
  /// (enforced by RLS in Phase 7).
  Future<Profile> updateProfile(Profile profile);
}