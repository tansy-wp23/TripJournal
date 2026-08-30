import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/home/home_screen.dart';

import 'support/auth_test_harness.dart';

void main() {
  Future<void> pumpHome(WidgetTester tester) async {
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
  }

  testWidgets('defaults to showing every trip with no filter selected', (tester) async {
    await pumpHome(tester);

    // Kyoto (active) appears twice: hero card + list. Osaka/Taipei once each.
    expect(find.text('Kyoto Trip'), findsNWidgets(2));
    expect(find.text('Osaka Trip'), findsOneWidget);
    expect(find.text('Taipei Trip'), findsOneWidget);
  });

  testWidgets('the Past status chip narrows the list to only past trips', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('trip-status-filter-past')));
    await tester.pumpAndSettle();

    // Hero card still shows the active trip regardless of the list filter.
    expect(find.text('Kyoto Trip'), findsOneWidget);
    expect(find.text('Osaka Trip'), findsOneWidget);
    expect(find.text('Taipei Trip'), findsNothing);
  });

  testWidgets('the Upcoming status chip narrows the list to only upcoming trips', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('trip-status-filter-upcoming')));
    await tester.pumpAndSettle();

    expect(find.text('Taipei Trip'), findsOneWidget);
    expect(find.text('Osaka Trip'), findsNothing);
  });

  testWidgets('the Active status chip narrows the list to just the active trip', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('trip-status-filter-active')));
    await tester.pumpAndSettle();

    // Hero card + the one matching list entry.
    expect(find.text('Kyoto Trip'), findsNWidgets(2));
    expect(find.text('Osaka Trip'), findsNothing);
    expect(find.text('Taipei Trip'), findsNothing);
    expect(find.byKey(const Key('trip-list-no-matches')), findsNothing);
  });

  testWidgets('the sort menu re-orders the trip list by title A-Z', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('trip-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trip-sort-option-titleAZ')));
    await tester.pumpAndSettle();

    // Alphabetical: Kyoto, Osaka, Taipei -- confirm all three still present
    // (order is checked at the pure-function level in trip_list_sort_test).
    expect(find.text('Kyoto Trip'), findsWidgets);
    expect(find.text('Osaka Trip'), findsOneWidget);
    expect(find.text('Taipei Trip'), findsOneWidget);
  });

  testWidgets('search expands beside filters and narrows trips by destination', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('trip-search-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('trip-search-field')), 'Japan');
    await tester.pumpAndSettle();

    expect(find.text('Kyoto Trip'), findsNWidgets(2));
    expect(find.text('Osaka Trip'), findsOneWidget);
    expect(find.text('Taipei Trip'), findsNothing);
  });
}
