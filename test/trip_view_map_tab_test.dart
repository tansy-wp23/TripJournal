import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/controller/journal_controller.dart';
import 'package:tripjournal/features/journal/screens/entry_detail_screen.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';
import 'package:tripjournal/models/mood.dart';

void main() {
  Future<void> pumpTrip(
    WidgetTester tester, {
    String tripId = 'trip-001',
    ProviderContainer? container,
    Size size = const Size(1200, 2600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final screen = MaterialApp(home: TripViewScreen(tripId: tripId));
    await tester.pumpWidget(
      container == null
          ? ProviderScope(child: screen)
          : UncontrolledProviderScope(container: container, child: screen),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Map ignores Entry filters while query, mood, and date survive switching',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpTrip(tester, container: container);

      await tester.tap(find.byKey(const Key('trip-view-search-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('journal-search-field')),
        'Fushimi',
      );
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byKey(const Key('trip-view-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mood-filter-tired')));
      await tester.tap(find.byKey(const Key('apply-journal-filters')));
      await tester.pumpAndSettle();

      final current = container.read(journalControllerProvider).filter;
      container
          .read(journalControllerProvider.notifier)
          .setFilter(
            current.copyWith(
              startDate: DateTime(2026, 4, 11),
              endDate: DateTime(2026, 4, 11),
            ),
          );
      await tester.pump();

      expect(find.text('Fushimi Inari hike'), findsOneWidget);
      expect(find.text('Arrival in Kyoto'), findsNothing);
      expect(find.byKey(const Key('journal-filter-count-2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('trip-view-map-tab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trip-view-search-toggle')), findsNothing);
      expect(find.byKey(const Key('trip-view-filter-button')), findsNothing);
      expect(find.text('3 mapped · 0 without location'), findsOneWidget);

      await tester.tap(find.byKey(const Key('trip-view-entries-tab')));
      await tester.pumpAndSettle();

      final searchField = tester.widget<TextField>(
        find.byKey(const Key('journal-search-field')),
      );
      expect(searchField.controller?.text, 'Fushimi');
      expect(find.byKey(const Key('journal-filter-count-2')), findsOneWidget);
      expect(find.text('Fushimi Inari hike'), findsOneWidget);
      expect(find.text('Arrival in Kyoto'), findsNothing);

      final retained = container.read(journalControllerProvider).filter;
      expect(retained.query, 'Fushimi');
      expect(retained.mood, Mood.tired);
      expect(retained.startDate, DateTime(2026, 4, 11));
      expect(retained.endDate, DateTime(2026, 4, 11));
    },
  );

  testWidgets('Entries timeline keeps its scroll offset across tab switches', (
    tester,
  ) async {
    await pumpTrip(tester, size: const Size(1200, 800));

    final entriesList = find.byKey(
      const PageStorageKey<String>('trip-view-entries-list'),
    );
    await tester.drag(entriesList, const Offset(0, -500));
    await tester.pumpAndSettle();

    final scrollable = find
        .descendant(of: entriesList, matching: find.byType(Scrollable))
        .first;
    final beforeSwitch = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    expect(beforeSwitch, greaterThan(0));

    await tester.tap(find.byKey(const Key('trip-view-map-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trip-view-entries-tab')));
    await tester.pumpAndSettle();

    final afterSwitch = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(
                  const PageStorageKey<String>('trip-view-entries-list'),
                ),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;
    expect(afterSwitch, closeTo(beforeSwitch, 0.1));
  });

  testWidgets('a Map preview opens the existing Entry Detail screen', (
    tester,
  ) async {
    await pumpTrip(tester);

    await tester.tap(find.byKey(const Key('trip-view-map-tab')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('trip-map-fallback-coord:35.011600,135.768100')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trip-map-preview-entry-1')));
    await tester.pumpAndSettle();

    expect(find.byType(EntryDetailScreen), findsOneWidget);
    expect(find.text('Arrival in Kyoto'), findsWidgets);
  });

  testWidgets('empty Map action returns the traveler to Entries', (
    tester,
  ) async {
    await pumpTrip(tester, tripId: 'trip-003');

    await tester.tap(find.byKey(const Key('trip-view-map-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trip-map-add-location')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip-view-search-toggle')), findsOneWidget);
    expect(find.byKey(const Key('no-entries-yet-hint')), findsOneWidget);
  });
}
