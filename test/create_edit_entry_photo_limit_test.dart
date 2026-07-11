import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/screens/create_edit_entry_screen.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

void main() {
  testWidgets('tapping "Add photo" when already at 5 photos blocks immediately, without opening the picker sheet', (
    tester,
  ) async {
    final entryWithFivePhotos = JournalEntry(
      id: 'entry-five-photos',
      tripId: 'trip-001',
      title: 'Already has 5 photos',
      body: 'Body',
      mood: Mood.neutral,
      photoPaths: const [
        'assets/mock/p1.jpg',
        'assets/mock/p2.jpg',
        'assets/mock/p3.jpg',
        'assets/mock/p4.jpg',
        'assets/mock/p5.jpg',
      ],
      createdAt: DateTime(2026, 4, 10),
      updatedAt: DateTime(2026, 4, 10),
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: CreateEditEntryScreen(existingEntry: entryWithFivePhotos),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-photo-button')));
    await tester.pump();

    expect(find.text('You can add up to 5 photos per entry.'), findsOneWidget);
    // The picker sheet never opened.
    expect(find.text('Take photo'), findsNothing);
    expect(find.text('Choose from gallery'), findsNothing);
  });
}
