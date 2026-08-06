import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/trip_view_screen.dart';

Future<void> _openCreateEntryForKyotoDay1(WidgetTester tester) async {
  // Pump the trip view directly (Kyoto = trip-001) rather than the full app:
  // this test is about entry-form validation, not auth routing or Home's
  // trip list. Day 1's "Add entry" reaches the same create-entry screen.
  await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: TripViewScreen(tripId: 'trip-001'))));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('add-entry-day-1')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('create-entry form validation blocks a totally empty entry, but title-only is enough', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openCreateEntryForKyotoDay1(tester);
    expect(find.text('New entry'), findsOneWidget);

    // Tap Save with both fields empty.
    await tester.tap(find.byKey(const Key('save-entry-button')));
    await tester.pump();
    expect(find.text('Please add a title or write something in your entry.'), findsOneWidget);
    // Still on the create screen — nothing was saved.
    expect(find.text('New entry'), findsOneWidget);

    // A title alone is enough to save — body is not required (title OR body).
    // The screen stays open after a successful save (IMPLEMENTATION_PLAN_UX_AI.md
    // §3): the AppBar retitles to "Edit entry" and the button reads "Saved".
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('entry-title-field')), 'Only a title');
    await tester.tap(find.byKey(const Key('save-entry-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-confirm-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('New entry'), findsNothing);
    expect(find.text('Edit entry'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('a body alone (no title) is also enough to save', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openCreateEntryForKyotoDay1(tester);

    await tester.enterText(find.byKey(const Key('entry-body-field')), 'Body with no title.');
    await tester.tap(find.byKey(const Key('save-entry-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-confirm-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('New entry'), findsNothing);
    expect(find.text('Edit entry'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('whitespace-only title/body is treated as empty', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openCreateEntryForKyotoDay1(tester);

    await tester.enterText(find.byKey(const Key('entry-title-field')), '   ');
    await tester.enterText(find.byKey(const Key('entry-body-field')), '   ');
    await tester.tap(find.byKey(const Key('save-entry-button')));
    await tester.pump();

    expect(find.text('Please add a title or write something in your entry.'), findsOneWidget);
    expect(find.text('New entry'), findsOneWidget);
  });
}
