import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/home/home_screen.dart';

Widget _wrapped() =>
    const ProviderScope(child: MaterialApp(home: HomeScreen()));

void main() {
  testWidgets('profile menu shows Recently Deleted above Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapped());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    final recentlyDeletedY = tester
        .getTopLeft(find.text('Recently Deleted'))
        .dy;
    final settingsY = tester.getTopLeft(find.text('Settings')).dy;
    expect(recentlyDeletedY, lessThan(settingsY));
  });

  testWidgets('shows "write today\'s entry" when no entry exists for today', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapped());
    await tester.pumpAndSettle();

    // Seeded entries are all dated April 2026, so today's entry is missing.
    expect(find.text("You haven't written today's entry yet."), findsOneWidget);
    expect(find.byKey(const Key('write-today-entry-button')), findsOneWidget);
  });

  // Runs last: mutates the shared mock repository singleton (adds a real
  // entry for today), which the test above's assumptions depend on not
  // having happened yet.
  testWidgets('switches to the confirmation state once today\'s entry exists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapped());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('write-today-entry-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('entry-title-field')),
      'Nudge test entry',
    );
    await tester.enterText(
      find.byKey(const Key('entry-body-field')),
      'Body written for today.',
    );
    await tester.tap(find.byKey(const Key('save-entry-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-confirm-confirm')));
    await tester.pumpAndSettle();

    // The entry screen stays open after save (IMPLEMENTATION_PLAN_UX_AI.md
    // §3) — leave manually to see the homepage's confirmation state.
    expect(find.text('Saved'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text("Today's entry: Nudge test entry"), findsOneWidget);
    expect(find.byKey(const Key('write-today-entry-button')), findsNothing);
  });
}
