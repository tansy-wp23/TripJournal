import '../models/profile.dart';

/// Maps to PB-03 (Search and View User). A **multi-row** read over
/// `Profile`, distinct from the single-caller `ProfileRepository` the User
/// Management module owns — that interface only ever resolves "the current
/// user's own profile."
abstract class AdminUserDirectoryRepository {
  /// Returns profiles whose display name or email contains [query]
  /// (case-insensitive substring match). Returns all profiles when [query]
  /// is null or empty.
  Future<List<Profile>> searchUsers({String? query});

  /// Fetches a single user's profile by id, or null if no such user exists.
  Future<Profile?> getUserById(String userId);
}