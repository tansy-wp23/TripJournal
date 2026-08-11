import 'package:cross_file/cross_file.dart';

/// Uploads/deletes the user's profile picture. Mirrors [TripCoverStorage]'s
/// shape so a future Supabase-backed implementation is a one-line locator
/// swap, same as the rest of this codebase's repositories.
abstract interface class ProfileAvatarStorage {
  Future<String> uploadAvatar({required String userId, required XFile photo});

  Future<void> deleteAvatarUrl(String? url);
}
