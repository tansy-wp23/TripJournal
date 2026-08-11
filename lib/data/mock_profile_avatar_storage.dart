import 'package:cross_file/cross_file.dart';

import 'profile_avatar_storage.dart';

/// In-memory fake of [ProfileAvatarStorage] so UI work never blocks on a
/// backend — no `profiles` table/Storage bucket exists yet (profile
/// management is mock-only end-to-end, see `user_management_repository_locator.dart`).
final class MockProfileAvatarStorage implements ProfileAvatarStorage {
  @override
  Future<String> uploadAvatar({
    required String userId,
    required XFile photo,
  }) async {
    final scheme = Uri.tryParse(photo.path)?.scheme.toLowerCase();
    if (photo.path.isEmpty || scheme == 'blob' || scheme == 'data') {
      return Uri(
        scheme: 'mock-avatar',
        host: userId,
        pathSegments: [photo.name],
      ).toString();
    }
    return photo.path;
  }

  @override
  Future<void> deleteAvatarUrl(String? url) async {}
}
