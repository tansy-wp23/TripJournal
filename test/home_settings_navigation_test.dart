import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/home/home_screen.dart';

import 'support/auth_test_harness.dart';

void main() {
  testWidgets('Settings menu opens the wired settings screen', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // AuthTestHarness overrides authControllerProvider so HomeScreen's
    // app-bar avatar doesn't touch Supabase (not initialized in tests).
    final harness = AuthTestHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
  });
}
