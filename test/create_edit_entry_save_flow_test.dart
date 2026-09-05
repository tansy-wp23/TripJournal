import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/repository_locator.dart';
import 'package:tripjournal/features/journal/screens/create_edit_entry_screen.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';

void main() {
  testWidgets(
    'saving a new entry stays on the same screen, shows "Saved", and never '
    'auto-generates AI advice',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Pump the trip view directly (Kyoto = trip-001) rather than the full
      // app: these tests are about the save flow, not auth routing or Home's
      // trip list.
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: TripViewScreen(tripId: 'trip-001'))));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-entry-day-1')));
      await tester.pumpAndSettle();

      expect(find.text('New entry'), findsOneWidget);
      // The edit screen doesn't show AI advice at all anymore - that moved to
      // EntryDetailScreen and is only ever generated on demand there.
      expect(find.byKey(const Key('ai-advice-text')), findsNothing);

      await tester.enterText(find.byKey(const Key('entry-title-field')), 'Save flow test');
      await tester.enterText(find.byKey(const Key('entry-body-field')), 'Checking the new save flow.');
      await tester.tap(find.byKey(const Key('save-entry-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-confirm-confirm')));
      await tester.pumpAndSettle();

      // Did not navigate away.
      expect(find.text('Edit entry'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byKey(const Key('ai-advice-text')), findsNothing);

      // Persisted for real, and advice was never touched by the save.
      final entries = await journalRepository.getEntries('trip-001');
      final saved = entries.firstWhere((e) => e.title == 'Save flow test');
      expect(saved.healthLog?.aiAdvice, isNull);
    },
  );

  testWidgets('editing a field after a successful save reverts the button back to "Save"', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Pump the trip view directly (Kyoto = trip-001) rather than the full
    // app: these tests are about the save flow, not auth routing or Home's
    // trip list.
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: TripViewScreen(tripId: 'trip-001'))));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-entry-day-1')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('entry-title-field')), 'Dirty tracking test');
    await tester.enterText(find.byKey(const Key('entry-body-field')), 'Body.');
    await tester.tap(find.byKey(const Key('save-entry-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-confirm-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('entry-title-field')), 'Dirty tracking test (changed)');
    await tester.pump();

    expect(find.text('Saved'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
  });

  testWidgets('opening an existing entry with prior advice never shows or touches it on this screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final existing = await journalRepository.getEntry('entry-1');
    expect(existing!.healthLog!.aiAdvice, isNotNull); // seeded with advice

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: CreateEditEntryScreen(existingEntry: existing)),
    ));
    await tester.pumpAndSettle();

    // AI advice is EntryDetailScreen's feature now - the edit form never
    // displays or generates it.
    expect(find.byKey(const Key('ai-advice-text')), findsNothing);
    expect(find.byKey(const Key('generate-advice-button')), findsNothing);
  });

  testWidgets(
    're-saving after changing mood does NOT touch existing AI advice - only '
    'the explicit Regenerate button on EntryDetailScreen may change it',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final existing = await journalRepository.getEntry('entry-3'); // mood: neutral in the seed
      final originalAdvice = existing!.healthLog!.aiAdvice;
      expect(originalAdvice, isNotNull);

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(home: CreateEditEntryScreen(existingEntry: existing)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stressed'));
      await tester.tap(find.byKey(const Key('save-entry-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-confirm-confirm')));
      await tester.pumpAndSettle();

      final saved = await journalRepository.getEntry('entry-3');
      expect(saved!.mood.name, 'stressed');
      expect(saved.healthLog?.aiAdvice, originalAdvice);
    },
  );

  group('save confirmation dialog (IMPLEMENTATION_PLAN_UX_POLISH.md §5)', () {
    testWidgets('Save shows a confirmation dialog before persisting anything', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Pump the trip view directly (Kyoto = trip-001) rather than the full
      // app: these tests are about the save flow, not auth routing or Home's
      // trip list.
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: TripViewScreen(tripId: 'trip-001'))));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-entry-day-1')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('entry-title-field')), 'Confirm dialog test');
      await tester.tap(find.byKey(const Key('save-entry-button')));
      await tester.pumpAndSettle();

      expect(find.text('Save changes to this entry?'), findsOneWidget);
      // Not persisted yet — the dialog hasn't been confirmed.
      final entries = await journalRepository.getEntries('trip-001');
      expect(entries.any((e) => e.title == 'Confirm dialog test'), isFalse);
    });

    testWidgets('Cancel dismisses the dialog and leaves the form intact, without saving', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Pump the trip view directly (Kyoto = trip-001) rather than the full
      // app: these tests are about the save flow, not auth routing or Home's
      // trip list.
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: TripViewScreen(tripId: 'trip-001'))));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-entry-day-1')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('entry-title-field')), 'Cancelled save test');
      await tester.tap(find.byKey(const Key('save-entry-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-confirm-cancel')));
      await tester.pumpAndSettle();

      // Dialog gone, still on the (unsaved) create screen with input intact.
      expect(find.text('Save changes to this entry?'), findsNothing);
      expect(find.text('New entry'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Cancelled save test'), findsOneWidget);

      final entries = await journalRepository.getEntries('trip-001');
      expect(entries.any((e) => e.title == 'Cancelled save test'), isFalse);
    });

    testWidgets('a save that fails validation never reaches the confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Pump the trip view directly (Kyoto = trip-001) rather than the full
      // app: these tests are about the save flow, not auth routing or Home's
      // trip list.
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: TripViewScreen(tripId: 'trip-001'))));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-entry-day-1')));
      await tester.pumpAndSettle();

      // Both fields empty — invalid.
      await tester.tap(find.byKey(const Key('save-entry-button')));
      await tester.pump();

      expect(find.text('Save changes to this entry?'), findsNothing);
      expect(find.text('Please add a title or write something in your entry.'), findsOneWidget);
    });
  });
}
