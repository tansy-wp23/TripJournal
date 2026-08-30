import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/repository_locator.dart';
import 'package:tripjournal/features/home/home_screen.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

import 'support/auth_test_harness.dart';

Widget _wrapped(AuthTestHarness harness) => harness.wrap(const HomeScreen());

void main() {
  testWidgets('profile menu shows Recently Deleted above Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = AuthTestHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(_wrapped(harness));
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

    final harness = AuthTestHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(_wrapped(harness));
    await tester.pumpAndSettle();

    // Seeded entries are all dated April 2026, so today's entry is missing.
    expect(find.text("You haven't written today's entry yet."), findsOneWidget);
    expect(find.byKey(const Key('write-today-entry-button')), findsOneWidget);
  });

  testWidgets('refreshes trip entry counts after returning from Trip View', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final before = await journalRepository.getEntries('trip-001');
    final createdAt = DateTime.now();
    final added = JournalEntry(
      id: 'home-return-count-refresh',
      tripId: 'trip-001',
      title: 'Added while viewing trip',
      body: '',
      mood: Mood.neutral,
      photoPaths: const [],
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    addTearDown(() => journalRepository.deleteEntry(added.id));

    final harness = AuthTestHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(_wrapped(harness));
    await tester.pumpAndSettle();
    expect(find.text('${before.length} entries'), findsOneWidget);

    await tester.tap(find.text('Kyoto Trip').last);
    await tester.pumpAndSettle();
    await journalRepository.addEntry(added);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('${before.length + 1} entries'), findsOneWidget);
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

    final harness = AuthTestHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(_wrapped(harness));
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
