import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/photo_storage.dart';
import 'package:tripjournal/data/repository_locator.dart';
import 'package:tripjournal/features/journal/screens/create_edit_entry_screen.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

class _RecordingPhotoStorage implements PhotoStorage {
  final List<String?> deleted = [];

  @override
  Future<String> savePhoto(XFile photo) async => photo.path;

  @override
  Future<void> deletePhoto(String? path) async => deleted.add(path);
}

void main() {
  testWidgets(
    'removing an already-saved photo does not delete the file, since the edit can still be discarded',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final entry = JournalEntry(
        id: 'entry-photo-cleanup-test',
        tripId: 'trip-001',
        title: 'Cleanup test entry',
        body: 'Body',
        mood: Mood.neutral,
        photoPaths: const ['/app/photos/saved-1.jpg', '/app/photos/saved-2.jpg'],
        createdAt: DateTime(2026, 4, 10),
        updatedAt: DateTime(2026, 4, 10),
      );
      await journalRepository.addEntry(entry);

      final storage = _RecordingPhotoStorage();
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: CreateEditEntryScreen(existingEntry: entry, photoStorage: storage),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('remove-photo-0')));
      await tester.pumpAndSettle();

      // The photo is gone from the form, but the file it points at is still
      // referenced by the saved entry until the user actually saves.
      expect(storage.deleted, isEmpty);
    },
  );
}
