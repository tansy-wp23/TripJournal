import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/repository_locator.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';
import 'package:tripjournal/models/portion_size.dart';

void main() {
  testWidgets(
    'a meal\'s portion survives create -> save -> repository -> detail view, end to end',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Pump the trip view directly (Kyoto = trip-001) rather than the full
      // app: this test is about portion persistence, not auth routing or
      // Home's trip list.
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: TripViewScreen(tripId: 'trip-001'))));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-entry-day-5')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('entry-title-field')), 'Portion round trip test');
      await tester.enterText(find.byKey(const Key('entry-body-field')), 'Checking portion persistence.');

      await tester.tap(find.byKey(const Key('add-meal-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('meal-name-field')), 'Nasi lemak');
      await tester.tap(find.descendant(
        of: find.byKey(const Key('meal-portion-selector')),
        matching: find.text('Large'),
      ));
      await tester.pumpAndSettle();
      // Typed after picking the portion, so it's the final override — not
      // subject to the auto-fill suggestion (IMPLEMENTATION_PLAN_UX_POLISH.md §1).
      await tester.enterText(find.byKey(const Key('meal-calories-field')), '900');
      await tester.tap(find.byKey(const Key('confirm-meal-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save-entry-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-confirm-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);

      // Persisted for real, not just shown in the form's local state.
      final entries = await journalRepository.getEntries('trip-001');
      final saved = entries.firstWhere((e) => e.title == 'Portion round trip test');
      expect(saved.healthLog?.meals.single.portion, PortionSize.large);

      // Shown again on the detail view after leaving and reopening the entry.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Portion round trip test'));
      await tester.pumpAndSettle();

      expect(find.text('Breakfast · Large · ~900 kcal'), findsOneWidget);
    },
  );
}
