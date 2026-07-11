import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/screens/create_edit_entry_screen.dart';
import 'package:tripjournal/features/journal/widgets/photo_thumbnail.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

JournalEntry _entryWithPhotos(List<String> photoPaths) {
  return JournalEntry(
    id: 'entry-multiselect-test',
    tripId: 'trip-001',
    title: 'Multi-select test entry',
    body: 'Body',
    mood: Mood.neutral,
    photoPaths: photoPaths,
    createdAt: DateTime(2026, 4, 10),
    updatedAt: DateTime(2026, 4, 10),
  );
}

void main() {
  group('multi-select entry photo upload (IMPLEMENTATION_PLAN_INLINE_PHOTO.md §3)', () {
    testWidgets(
      'a gallery pick result of "nothing selected" is a no-op — no crash, no stuck state, still saveable',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(ProviderScope(
          child: MaterialApp(home: CreateEditEntryScreen(existingEntry: _entryWithPhotos(const []))),
        ));
        await tester.pumpAndSettle();

        expect(find.text('No photos added.'), findsOneWidget);

        await tester.tap(find.byKey(const Key('add-photo-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('pick-photo-gallery')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('No photos added.'), findsOneWidget);
        expect(find.byType(PhotoThumbnail), findsNothing);
      },
    );

    testWidgets('the camera option still works as a single-photo add path, unaffected by multi-select', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(home: CreateEditEntryScreen(existingEntry: _entryWithPhotos(const []))),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-photo-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pick-photo-camera')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('No photos added.'), findsOneWidget);
    });

    testWidgets('with 1 slot remaining (4 of 5 photos), the picker sheet still opens normally', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final entry = _entryWithPhotos(const [
        'assets/mock/p1.jpg',
        'assets/mock/p2.jpg',
        'assets/mock/p3.jpg',
        'assets/mock/p4.jpg',
      ]);

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(home: CreateEditEntryScreen(existingEntry: entry)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-photo-button')));
      await tester.pump();

      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      // Not blocked yet — there's still 1 slot left (4 existing < 5 cap).
      expect(find.text('You can add up to 5 photos per entry.'), findsNothing);
    });

    testWidgets('at exactly 5 photos, "Add photo" blocks immediately without opening the picker sheet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final entry = _entryWithPhotos(const [
        'assets/mock/p1.jpg',
        'assets/mock/p2.jpg',
        'assets/mock/p3.jpg',
        'assets/mock/p4.jpg',
        'assets/mock/p5.jpg',
      ]);

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(home: CreateEditEntryScreen(existingEntry: entry)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-photo-button')));
      await tester.pump();

      expect(find.text('You can add up to 5 photos per entry.'), findsOneWidget);
      expect(find.text('Take photo'), findsNothing);
      expect(find.text('Choose from gallery'), findsNothing);
    });
  });
}
