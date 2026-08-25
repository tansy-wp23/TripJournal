import 'package:cross_file/cross_file.dart';

import 'photo_copy.dart';
import 'photo_storage.dart';

/// Local-filesystem implementation of [PhotoStorage] — the one wired up today.
///
/// "Mock" in the same sense as `MockTripCoverStorage`: it satisfies the
/// interface without a backend, so UI work never blocks on Supabase. Unlike
/// the cover mock it does real work, because the durability problem it solves
/// is real on device.
final class MockPhotoStorage implements PhotoStorage {
  @override
  Future<String> savePhoto(XFile photo, {required String tripId}) async {
    // tripId is unused here on purpose: the local copy lives in the app's own
    // directory, which no policy scopes by trip. Only the Supabase
    // implementation needs it.
    final copied = await copyPhotoIntoAppStorage(photo);
    if (copied != null) return copied;

    // No filesystem to copy into: web (blob:/data: URLs) and `flutter test`,
    // where the path_provider method channel has no implementation. Synthesize
    // a stable URI for the former and echo the picker's path for the latter —
    // both degrade to exactly today's behaviour rather than losing the photo.
    final scheme = Uri.tryParse(photo.path)?.scheme.toLowerCase();
    if (photo.path.isEmpty || scheme == 'blob' || scheme == 'data') {
      return Uri(
        scheme: 'mock-photo',
        host: 'local',
        pathSegments: [photo.name],
      ).toString();
    }
    return photo.path;
  }

  @override
  Future<void> deletePhoto(String? path) async {
    if (path == null || path.isEmpty) return;
    await deleteCopiedPhoto(path);
  }
}
