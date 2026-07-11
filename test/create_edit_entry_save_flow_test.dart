import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/repository_locator.dart';
import 'package:tripjournal/features/journal/screens/create_edit_entry_screen.dart';
import 'package:tripjournal/main.dart';

void main() {
  testWidgets(
    'saving a new entry stays on the same screen, shows "Saved" and the AI suggestion in place',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TripJournalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kyoto Trip').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-entry-day-1')));
      await tester.pumpAndSettle();

      expect(find.text('New entry'), findsOneWidget);
      expect(find.byKey(const Key('ai-advice-text')), findsNothing); // nothing yet — never saved

      await tester.enterText(find.byKey(const Key('entry-title-field')), 'Save flow test');
      await tester.enterText(find.byKey(const Key('entry-body-field')), 'Checking the new save flow.');
      await tester.tap(find.byKey(const Key('save-entry-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-confirm-confirm')));
      await tester.pumpAndSettle();

      // Did not navigate away.
      expect(find.text('Edit entry'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byKey(const Key('ai-advice-text')), findsOneWidget);
      final adviceWidget = tester.widget<Text>(find.byKey(const Key('ai-advice-text')));
      expect(adviceWidget.data, isNotNull);
      expect(adviceWidget.data, isNotEmpty);

      // Persisted for real, not just shown locally.
      final entries = await journalRepository.getEntries('trip-001');
      final saved = entries.firstWhere((e) => e.title == 'Save flow test');
      expect(saved.healthLog?.aiAdvice, adviceWidget.data);
    },
  );

  testWidgets('editing a field after a successful save reverts the button back to "Save"', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TripJournalApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kyoto Trip').last);
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

  testWidgets('opening an existing entry with prior advice shows it immediately, before any new save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final existing = await journalRepository.getEntry('entry-1');

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: CreateEditEntryScreen(existingEntry: existing)),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-advice-text')), findsOneWidget);
    final adviceWidget = tester.widget<Text>(find.byKey(const Key('ai-advice-text')));
    expect(adviceWidget.data, existing!.healthLog!.aiAdvice);
  });

  testWidgets('re-saving after changing mood regenerates the advice for the new mood', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final existing = await journalRepository.getEntry('entry-3'); // mood: neutral in the seed

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: CreateEditEntryScreen(existingEntry: existing)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stressed'));
    await tester.tap(find.byKey(const Key('save-entry-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-confirm-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-advice-text')), findsOneWidget);
    final adviceWidget = tester.widget<Text>(find.byKey(const Key('ai-advice-text')));
    expect(adviceWidget.data, contains('stressed'));
  });

  group('save confirmation dialog (IMPLEMENTATION_PLAN_UX_POLISH.md §5)', () {
    testWidgets('Save shows a confirmation dialog before persisting anything', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TripJournalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kyoto Trip').last);
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

      await tester.pumpWidget(const TripJournalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kyoto Trip').last);
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

      await tester.pumpWidget(const TripJournalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kyoto Trip').last);
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
