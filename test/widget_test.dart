import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/community/community_screen.dart';
import 'package:tripjournal/features/home/home_screen.dart';

import 'support/auth_test_harness.dart';

void main() {
  testWidgets('Home screen shows the active trip and seeded trips', (WidgetTester tester) async {
    // Tall virtual screen so the whole "Your Trips" list is built without
    // needing to scroll — Home's ListView is still lazy at the render
    // level even with a fixed children list.
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Pump HomeScreen directly rather than the full app: this test is about
    // Home's content, not auth routing (TripJournalApp() now boots into
    // AuthGate -> LoginScreen for a signed-out session).
    // AuthTestHarness overrides authControllerProvider so HomeScreen's
    // app-bar avatar doesn't touch Supabase (not initialized in tests).
    final harness = AuthTestHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('TripJournal'), findsOneWidget);
    // Kyoto is the active trip — shown in both the hero card and the
    // "Your Trips" list.
    expect(find.text('Kyoto Trip'), findsNWidgets(2));
    expect(find.text('Osaka Trip'), findsOneWidget);
    expect(find.byKey(const Key('community-button')), findsOneWidget);
  });

  testWidgets('tapping the community button opens the Community screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = AuthTestHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('community-button')));
    await tester.pumpAndSettle();

    expect(find.byType(CommunityScreen), findsOneWidget);
  });
}
