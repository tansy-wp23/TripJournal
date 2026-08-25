import '../../data/photo_storage.dart';
import '../../models/journal_entry.dart';

Set<String> journalPhotoPaths(JournalEntry? entry) {
  if (entry == null) return <String>{};
  return {
    ...entry.photoPaths.where((path) => path.isNotEmpty),
    for (final meal in entry.healthLog?.meals ?? const [])
      if (meal.photoPath case final path? when path.isNotEmpty) path,
  };
}

Future<Set<String>> cleanupPhotosAfterFailedJournalSave({
  required JournalEntry? before,
  required JournalEntry attempted,
  required PhotoStorage storage,
}) async {
  final newlyAdded = journalPhotoPaths(attempted)
    ..removeAll(journalPhotoPaths(before));
  await _deleteBestEffort(newlyAdded, storage);
  return newlyAdded;
}

Future<void> cleanupPhotosAfterSuccessfulJournalSave({
  required JournalEntry? before,
  required JournalEntry saved,
  required PhotoStorage storage,
}) async {
  final removed = journalPhotoPaths(before)
    ..removeAll(journalPhotoPaths(saved));
  await _deleteBestEffort(removed, storage);
}

Future<void> _deleteBestEffort(
  Iterable<String> paths,
  PhotoStorage storage,
) async {
  await Future.wait(
    paths.map((path) async {
      try {
        await storage.deletePhoto(path);
      } catch (_) {
        // Storage is outside the database transaction. A failed cleanup must
        // never hide the original save result or invalidate persisted data.
      }
    }),
  );
}
