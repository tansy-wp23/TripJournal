import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/trip_form_screen.dart';

void main() {
  testWidgets('new trip presents a clear section hierarchy', (tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TripFormScreen())),
    );

    expect(find.text('Trip details'), findsOneWidget);
    expect(find.text('Travel dates'), findsOneWidget);
    expect(find.text('Cover photo'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.byKey(const Key('trip-start-date-field')), findsOneWidget);
    expect(find.byKey(const Key('trip-end-date-field')), findsOneWidget);
    expect(find.byKey(const Key('save-trip-button')), findsOneWidget);
  });

  testWidgets('new trip requires a trimmed destination', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TripFormScreen())),
    );
    await tester.enterText(
      find.byKey(const Key('trip-title-field')),
      'Weekend away',
    );
    await tester.enterText(
      find.byKey(const Key('trip-destination-field')),
      '   ',
    );
    await tester.tap(find.byKey(const Key('save-trip-button')));
    await tester.pump();

    expect(find.text('Please enter a destination.'), findsOneWidget);
  });
}
