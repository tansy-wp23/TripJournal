import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/trip_view_screen.dart';

Widget _wrapped(String tripId) {
  return ProviderScope(
    child: MaterialApp(home: TripViewScreen(tripId: tripId)),
  );
}

void main() {
  Future<void> setUpScreen(WidgetTester tester, String tripId) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapped(tripId));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a trip with entries shows the dismissible "tap to edit" tip, not the empty hint',
    (tester) async {
      // trip-001 (Kyoto) has seeded entries.
      await setUpScreen(tester, 'trip-001');

      expect(find.byKey(const Key('tap-to-edit-hint')), findsOneWidget);
      expect(find.byKey(const Key('no-entries-yet-hint')), findsNothing);
    },
  );

  testWidgets('dismissing the tip hides it', (tester) async {
    await setUpScreen(tester, 'trip-001');

    expect(find.byKey(const Key('tap-to-edit-hint')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dismiss-tap-to-edit-hint')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tap-to-edit-hint')), findsNothing);
  });

  testWidgets(
    'a trip with zero entries shows the "no entries yet" hint, not the tap-to-edit tip',
    (tester) async {
      // trip-003 (Taipei) is seeded with no journal entries yet.
      await setUpScreen(tester, 'trip-003');

      expect(find.byKey(const Key('no-entries-yet-hint')), findsOneWidget);
      expect(find.byKey(const Key('tap-to-edit-hint')), findsNothing);
    },
  );

  testWidgets(
    'the "Clear filters" action on a no-matches result restores the full timeline',
    (tester) async {
      await setUpScreen(tester, 'trip-001');

      await tester.tap(find.byKey(const Key('trip-view-search-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('journal-search-field')),
        'volcano eruption',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('No matching entries'), findsOneWidget);

      await tester.tap(find.byKey(const Key('clear-journal-filters-button')));
      await tester.pumpAndSettle();

      // Filter cleared -- the search field (still open) now shows empty text
      // and the full timeline is back.
      expect(find.text('No matching entries'), findsNothing);
      expect(find.text('Arrival in Kyoto'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const Key('journal-search-field')),
      );
      expect(field.controller!.text, isEmpty);
    },
  );
}
