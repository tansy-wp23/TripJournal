import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/home/home_screen.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';

void main() {
  testWidgets(
    'creating a trip with the default (today) dates is rejected — trip-001 is '
    'already active on today, so overlap prevention must catch it',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Pump Home directly rather than the full app (bypassing AuthGate),
      // then reach the trip form the same way a real user would: overlap
      // validation reads from TripController's already-loaded trips
      // (see trip_controller.dart's _validate doc comment), which only
      // happens once Home has loaded them.
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: HomeScreen())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Trip'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('trip-title-field')), 'Conflicting Trip');
      // Dates are left at their default (today) — already inside trip-001's
      // (Kyoto) active range, so this must be rejected without needing to
      // drive the native date picker.
      await tester.tap(find.byKey(const Key('save-trip-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('You already have a trip during these dates'), findsOneWidget);
      expect(find.textContaining('Kyoto Trip'), findsOneWidget);
      expect(find.text('New trip'), findsOneWidget); // still on the form — nothing was saved
    },
  );

  testWidgets(
    'editing a trip without changing its dates saves successfully — must not '
    'collide with its own unchanged dates',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Pump the trip view directly (Osaka = trip-002) rather than the full
      // app: this test is about overlap validation on save, not auth
      // routing or Home's trip list.
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: TripViewScreen(tripId: 'trip-002'))));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('trip-view-edit-button')));
      await tester.pumpAndSettle();

      expect(find.text('Edit trip'), findsOneWidget);
      await tester.tap(find.byKey(const Key('save-trip-button')));
      await tester.pumpAndSettle();

      // Saved and popped back to Trip View — no overlap error anywhere.
      // "Osaka Trip" appears twice on this screen (AppBar title + header).
      expect(find.text('Edit trip'), findsNothing);
      expect(find.textContaining('You already have a trip during these dates'), findsNothing);
      expect(find.text('Osaka Trip'), findsNWidgets(2));
    },
  );
}
