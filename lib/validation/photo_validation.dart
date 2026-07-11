const kMaxPhotosPerEntry = 5;
const kMaxPhotoSizeBytes = 32 * 1024 * 1024;

/// [currentCount] is the number of photos already on the entry, before
/// adding another one.
String? validatePhotoCount(int currentCount) {
  if (currentCount >= kMaxPhotosPerEntry) {
    return 'You can add up to $kMaxPhotosPerEntry photos per entry.';
  }
  return null;
}

/// How many more photos can be added before hitting [kMaxPhotosPerEntry] —
/// used to cap a multi-select pick up front (as a guide, via the picker's
/// own `limit`) and, since not every platform/picker honours that, enforced
/// again on return as the backstop. See
/// IMPLEMENTATION_PLAN_INLINE_PHOTO.md §3.
int remainingPhotoAllowance(int currentCount) {
  final remaining = kMaxPhotosPerEntry - currentCount;
  return remaining < 0 ? 0 : remaining;
}

String? validatePhotoSize(int bytes) {
  if (bytes > kMaxPhotoSizeBytes) {
    return 'This image is too large (max 32 MB).';
  }
  return null;
}
