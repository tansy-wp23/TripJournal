import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/home/home_screen.dart';
import 'package:tripjournal/features/trip/widgets/trip_list_controls.dart';

import 'support/auth_test_harness.dart';

void main() {
  testWidgets(
    'TripListNoMatchesState shows a friendly message and invokes onClearFilter when tapped',
    (tester) async {
      var cleared = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripListNoMatchesState(onClearFilter: () => cleared = true),
          ),
        ),
      );

      expect(find.text('No trips match this filter.'), findsOneWidget);
      expect(cleared, isFalse);

      await tester.tap(
        find.byKey(const Key('clear-trip-status-filter-button')),
      );
      await tester.pump();

      expect(cleared, isTrue);
    },
  );

  testWidgets(
    'the home screen never shows the no-matches state with the seeded (always non-empty) trip data',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // AuthTestHarness overrides authControllerProvider so HomeScreen's
      // app-bar avatar doesn't touch Supabase (not initialized in tests).
      final harness = AuthTestHarness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.wrap(const HomeScreen()));
      await tester.pumpAndSettle();

      for (final key in ['all', 'active', 'upcoming', 'past']) {
        await tester.tap(find.byKey(Key('trip-status-filter-$key')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('trip-list-no-matches')), findsNothing);
      }
    },
  );
}
