import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/trip_form_screen.dart';

void main() {
  testWidgets('new trip requires a trimmed destination', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: TripFormScreen())));
    await tester.enterText(find.byKey(const Key('trip-title-field')), 'Weekend away');
    await tester.enterText(find.byKey(const Key('trip-destination-field')), '   ');
    await tester.tap(find.byKey(const Key('save-trip-button')));
    await tester.pump();

    expect(find.text('Please enter a destination.'), findsOneWidget);
  });
}
