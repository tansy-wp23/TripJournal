import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/repository_locator.dart';
import 'package:tripjournal/data/trip_repository_locator.dart';
import 'package:tripjournal/features/journal/screens/create_edit_entry_screen.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';

void main() {
  testWidgets('backfilling a past day (trip-002, fully in the past) stamps the entry at noon, not midnight', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Pump the trip view directly (Osaka = trip-002) rather than the full
    // app: this test is about day-derivation on the create-entry screen, not
    // auth routing or Home's trip list.
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: TripViewScreen(tripId: 'trip-002'))));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-entry-day-1')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('entry-title-field')), 'Backfilled entry');
    await tester.enterText(find.byKey(const Key('entry-body-field')), 'Written after the fact.');
    await tester.tap(find.byKey(const Key('save-entry-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-confirm-confirm')));
    await tester.pumpAndSettle();

    final entries = await journalRepository.getEntries('trip-002');
    final saved = entries.firstWhere((e) => e.title == 'Backfilled entry');
    expect(saved.createdAt, DateTime(2026, 3, 20, 12)); // day 1 of trip-002 == March 20
  });

  testWidgets('a date outside the trip range is rejected with an inline error and nothing is saved', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final trip = await tripRepository.getTrip('trip-002'); // Mar 20 - Mar 21, 2026
    final beforeCount = (await journalRepository.getEntries('trip-002')).length;

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: CreateEditEntryScreen(
          tripId: 'trip-002',
          initialDate: DateTime(2026, 5, 1), // outside trip-002's range
          trip: trip,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('entry-title-field')), 'Should not save');
    await tester.enterText(find.byKey(const Key('entry-body-field')), 'Out of range.');
    await tester.tap(find.byKey(const Key('save-entry-button')));
    await tester.pump();

    expect(find.text('This date is outside your trip dates.'), findsOneWidget);
    expect(find.text('New entry'), findsOneWidget); // still on the create screen — save was blocked

    final afterCount = (await journalRepository.getEntries('trip-002')).length;
    expect(afterCount, beforeCount);
  });
}
