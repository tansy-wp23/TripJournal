import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/home/home_screen.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';

Widget _wrapped() => const ProviderScope(child: MaterialApp(home: HomeScreen()));

void main() {
  testWidgets('tapping the stats area of the active-trip card opens the trip (no dead zone)', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapped());
    await tester.pumpAndSettle();

    // Tap inside the wellness stats row, not the card generally — this is
    // the area that used to be a separate, non-participating card.
    await tester.tap(find.textContaining('days logged'));
    await tester.pumpAndSettle();

    expect(find.byType(TripViewScreen), findsOneWidget);
  });

  testWidgets('tapping "Write today\'s entry" opens the entry form, not the trip view', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapped());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('write-today-entry-button')));
    await tester.pumpAndSettle();

    expect(find.byType(TripViewScreen), findsNothing);
    expect(find.text('New entry'), findsOneWidget);
  });
}
