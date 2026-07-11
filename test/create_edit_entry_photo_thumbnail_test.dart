import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/repository_locator.dart';
import 'package:tripjournal/features/journal/screens/create_edit_entry_screen.dart';
import 'package:tripjournal/features/journal/widgets/photo_thumbnail.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

void main() {
  testWidgets(
    'existing photos render as square thumbnails, and removing one persists the reduced list on save',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final entry = JournalEntry(
        id: 'entry-thumbnail-test',
        tripId: 'trip-001',
        title: 'Thumbnail test entry',
        body: 'Body',
        mood: Mood.neutral,
        photoPaths: const ['assets/mock/p1.jpg', 'assets/mock/p2.jpg'],
        createdAt: DateTime(2026, 4, 10),
        updatedAt: DateTime(2026, 4, 10),
      );
      await journalRepository.addEntry(entry);

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(home: CreateEditEntryScreen(existingEntry: entry)),
      ));
      await tester.pumpAndSettle();

      // Square thumbnails, not filename chips.
      expect(find.byType(PhotoThumbnail), findsNWidgets(2));
      expect(find.text('p1.jpg'), findsNothing);

      await tester.tap(find.byKey(const Key('remove-photo-0')));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoThumbnail), findsOneWidget);

      await tester.tap(find.byKey(const Key('save-entry-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-confirm-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);

      final saved = await journalRepository.getEntry('entry-thumbnail-test');
      expect(saved!.photoPaths, ['assets/mock/p2.jpg']);
    },
  );
}
