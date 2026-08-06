import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/repository_locator.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';

Future<void> _openCreateEntryForKyotoDay(WidgetTester tester, int day) async {
  // Pump the trip view directly (Kyoto = trip-001) rather than the full app:
  // this suite is about the create-entry discard guard, not auth routing or
  // Home's trip list.
  await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: TripViewScreen(tripId: 'trip-001'))));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(Key('add-entry-day-$day')));
  await tester.pumpAndSettle();
}

void main() {
  group('discard-changes guard (IMPLEMENTATION_PLAN_UX_POLISH.md §6)', () {
    testWidgets('a pristine, untouched entry leaves on back with no prompt', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _openCreateEntryForKyotoDay(tester, 5);
      expect(find.text('New entry'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('New entry'), findsNothing); // actually left the screen
    });

    testWidgets('a dirty (edited but unsaved) entry prompts "Discard changes?" on back', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _openCreateEntryForKyotoDay(tester, 5);
      await tester.enterText(find.byKey(const Key('entry-title-field')), 'Unsaved draft');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('New entry'), findsOneWidget); // still on the editor, blocked
    });

    testWidgets('"Keep editing" dismisses the prompt and leaves the input intact', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _openCreateEntryForKyotoDay(tester, 5);
      await tester.enterText(find.byKey(const Key('entry-title-field')), 'Keep me');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('discard-keep-editing')));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('New entry'), findsOneWidget); // still here
      expect(find.widgetWithText(TextField, 'Keep me'), findsOneWidget); // input untouched
    });

    testWidgets('"Discard" leaves the screen without saving anything', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _openCreateEntryForKyotoDay(tester, 5);
      await tester.enterText(find.byKey(const Key('entry-title-field')), 'Should be discarded');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('discard-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('New entry'), findsNothing); // left the screen

      final entries = await journalRepository.getEntries('trip-001');
      expect(entries.any((e) => e.title == 'Should be discarded'), isFalse);
    });

    testWidgets('after a successful save the form is clean again — back leaves silently', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _openCreateEntryForKyotoDay(tester, 5);
      await tester.enterText(find.byKey(const Key('entry-title-field')), 'Saved then back');
      await tester.tap(find.byKey(const Key('save-entry-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-confirm-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Edit entry'), findsNothing); // actually left the screen
    });
  });
}
