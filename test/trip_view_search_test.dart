import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/trip_view_screen.dart';

Widget _wrapped(String tripId) {
  return ProviderScope(child: MaterialApp(home: TripViewScreen(tripId: tripId)));
}

void main() {
  Future<void> setUpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // trip-001 (Kyoto) has 3 seeded entries: entry-1 "Arrival in Kyoto"
    // (excited), entry-2 "Fushimi Inari hike" (tired), entry-3 "Rainy day
    // at the museum" (neutral).
    await tester.pumpWidget(_wrapped('trip-001'));
    await tester.pumpAndSettle();
  }

  testWidgets('the search bar is hidden until the search icon is tapped', (tester) async {
    await setUpScreen(tester);

    expect(find.byKey(const Key('journal-search-field')), findsNothing);

    await tester.tap(find.byKey(const Key('trip-view-search-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('journal-search-field')), findsOneWidget);
  });

  testWidgets('typing a query narrows the timeline to matching entries after the debounce', (
    tester,
  ) async {
    await setUpScreen(tester);

    await tester.tap(find.byKey(const Key('trip-view-search-toggle')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('journal-search-field')), 'Fushimi');
    // Debounce is 300ms -- pump past it.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Fushimi Inari hike'), findsOneWidget);
    expect(find.text('Arrival in Kyoto'), findsNothing);
    expect(find.text('Rainy day at the museum'), findsNothing);
  });

  testWidgets('filter button opens a sheet and applies mood independently', (tester) async {
    await setUpScreen(tester);

    await tester.tap(find.byKey(const Key('trip-view-filter-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mood-filter-tired')));
    await tester.tap(find.byKey(const Key('apply-journal-filters')));
    await tester.pumpAndSettle();

    expect(find.text('Fushimi Inari hike'), findsOneWidget);
    expect(find.text('Arrival in Kyoto'), findsNothing);
    expect(find.byKey(const Key('journal-filter-count-1')), findsOneWidget);
  });

  testWidgets('a query with no matches shows the "No matching entries" empty state', (
    tester,
  ) async {
    await setUpScreen(tester);

    await tester.tap(find.byKey(const Key('trip-view-search-toggle')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('journal-search-field')), 'volcano eruption');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('No matching entries'), findsOneWidget);
  });

  testWidgets('closing search clears only query and preserves mood filter', (
    tester,
  ) async {
    await setUpScreen(tester);

    await tester.tap(find.byKey(const Key('trip-view-search-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('journal-search-field')), 'Fushimi');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const Key('trip-view-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mood-filter-tired')));
    await tester.tap(find.byKey(const Key('apply-journal-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Arrival in Kyoto'), findsNothing);

    await tester.tap(find.byKey(const Key('trip-view-search-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('journal-search-field')), findsNothing);
    expect(find.text('Arrival in Kyoto'), findsNothing);
    expect(find.text('Fushimi Inari hike'), findsOneWidget);
  });
}
