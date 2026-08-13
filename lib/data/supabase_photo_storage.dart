import 'package:cross_file/cross_file.dart';

import 'photo_storage.dart';

/// TODO(phase7): upload to a Supabase Storage bucket (mirroring
/// `SupabaseTripCoverStorage`'s `trip-covers` bucket) and return the public
/// URL. Swapping this in is a one-line change in `repository_locator.dart`.
final class SupabasePhotoStorage implements PhotoStorage {
  @override
  Future<String> savePhoto(XFile photo) async => throw UnimplementedError();

  @override
  Future<void> deletePhoto(String? path) async => throw UnimplementedError();
}
