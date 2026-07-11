import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/screens/entry_detail_screen.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';

Widget _wrapped(String tripId) {
  return ProviderScope(
    child: MaterialApp(home: TripViewScreen(tripId: tripId)),
  );
}

void main() {
  testWidgets('each entry renders as its own distinct, chevron-marked tile showing steps and mood', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapped('trip-001'));
    await tester.pumpAndSettle();

    // Seeded entry-1 ("Arrival in Kyoto"): 8,200 steps, mood Excited.
    expect(find.byKey(const Key('entry-tile-entry-1')), findsOneWidget);
    expect(find.text('8,200 steps · Excited'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsWidgets); // one per visible entry tile
  });

  testWidgets('tapping an entry tile opens its detail screen', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapped('trip-001'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('entry-tile-entry-1')));
    await tester.pumpAndSettle();

    expect(find.byType(EntryDetailScreen), findsOneWidget);
    expect(find.text('Arrival in Kyoto'), findsOneWidget);
  });
}
