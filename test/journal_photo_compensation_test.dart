import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/photo_storage.dart';
import 'package:tripjournal/features/journal/journal_photo_compensation.dart';
import 'package:tripjournal/models/health_log.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';
import 'package:tripjournal/models/mood.dart';

void main() {
  test('failed save cleans only photos newly added by that attempt', () async {
    final storage = _RecordingStorage();
    final before = _entry(
      entryPhotos: const ['old-entry.jpg'],
      mealPhoto: 'old-meal.jpg',
    );
    final attempted = _entry(
      entryPhotos: const ['old-entry.jpg', 'new-entry.jpg'],
      mealPhoto: 'new-meal.jpg',
    );

    final removed = await cleanupPhotosAfterFailedJournalSave(
      before: before,
      attempted: attempted,
      storage: storage,
    );

    expect(removed, {'new-entry.jpg', 'new-meal.jpg'});
    expect(storage.deleted.toSet(), removed);
  });

  test(
    'successful save cleans only photos removed from persisted data',
    () async {
      final storage = _RecordingStorage();
      final before = _entry(
        entryPhotos: const ['keep.jpg', 'removed-entry.jpg'],
        mealPhoto: 'removed-meal.jpg',
      );
      final saved = _entry(entryPhotos: const ['keep.jpg', 'new.jpg']);

      await cleanupPhotosAfterSuccessfulJournalSave(
        before: before,
        saved: saved,
        storage: storage,
      );

      expect(storage.deleted.toSet(), {
        'removed-entry.jpg',
        'removed-meal.jpg',
      });
    },
  );

  test('cleanup is best effort when one storage deletion fails', () async {
    final storage = _RecordingStorage(failPaths: {'broken.jpg'});
    final attempted = _entry(
      entryPhotos: const ['broken.jpg', 'still-cleaned.jpg'],
    );

    final removed = await cleanupPhotosAfterFailedJournalSave(
      before: null,
      attempted: attempted,
      storage: storage,
    );

    expect(removed, {'broken.jpg', 'still-cleaned.jpg'});
    expect(storage.deleted, contains('still-cleaned.jpg'));

    await cleanupPhotosAfterSuccessfulJournalSave(
      before: attempted,
      saved: _entry(entryPhotos: const []),
      storage: storage,
    );
  });
}

JournalEntry _entry({required List<String> entryPhotos, String? mealPhoto}) =>
    JournalEntry(
      id: 'entry',
      tripId: 'trip',
      title: 'Photos',
      body: '',
      mood: Mood.neutral,
      photoPaths: entryPhotos,
      createdAt: DateTime(2026, 8, 25),
      updatedAt: DateTime(2026, 8, 25),
      healthLog: HealthLog(
        id: 'health',
        entryId: 'entry',
        steps: 0,
        caloriesEaten: 0,
        meals: mealPhoto == null
            ? const []
            : [
                Meal(
                  id: 'meal',
                  name: 'Meal',
                  calories: 0,
                  mealType: MealType.snack,
                  photoPath: mealPhoto,
                ),
              ],
      ),
    );

class _RecordingStorage implements PhotoStorage {
  _RecordingStorage({this.failPaths = const {}});

  final Set<String> failPaths;
  final deleted = <String>[];

  @override
  Future<String> savePhoto(XFile photo, {required String tripId}) async =>
      photo.path;

  @override
  Future<void> deletePhoto(String? path) async {
    if (path == null) return;
    if (failPaths.contains(path)) throw StateError('simulated failure');
    deleted.add(path);
  }
}
