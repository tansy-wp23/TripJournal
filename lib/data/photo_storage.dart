import 'package:cross_file/cross_file.dart';

/// Where a picked photo is kept so it survives.
///
/// `image_picker` hands back a path inside the OS cache directory — on Android
/// that is `/data/.../cache/...`, which the system is free to evict at any
/// time. Journal entry photos have always stored that raw path, which is why a
/// photo can silently turn into a broken-image placeholder days later. Copying
/// the file somewhere the app owns fixes that.
///
/// Returns a path/URL string rather than a `File` deliberately: the README's
/// rule is that photos live in Storage and only the resulting string is
/// persisted, so the phase-7 swap to Supabase Storage keeps this same shape.
abstract interface class PhotoStorage {
  /// Copies [photo] into durable storage and returns the path to use from now
  /// on.
  ///
  /// **Never throws.** Callers add photos inside `try` blocks whose `catch`
  /// aborts a whole multi-select batch, so a failure here has to degrade to
  /// "keep the original path" rather than losing the user's other photos.
  Future<String> savePhoto(XFile photo);

  /// Best-effort cleanup for a photo the user removed. A no-op for paths this
  /// storage never owned.
  Future<void> deletePhoto(String? path);
}
