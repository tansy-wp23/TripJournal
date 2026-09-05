import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/features/journal/ai/daily_advice_locator.dart';
import 'package:tripjournal/features/journal/controller/journal_controller.dart';
import 'package:tripjournal/features/journal/screens/entry_detail_screen.dart';
import 'package:tripjournal/models/health_log.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

void main() {
  Future<JournalController> pumpDetail(
    WidgetTester tester,
    String entryId,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = JournalController(
      MockJournalRepository(),
      dailyAdviceService,
    );
    await controller.loadEntries('trip-001');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalControllerProvider.overrideWith(
            (ref) => controller,
            disposeNotifier: false,
          ),
        ],
        child: MaterialApp(home: EntryDetailScreen(entryId: entryId)),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets(
    'existing advice shows immediately on open - no generation call is made',
    (tester) async {
      final controller = await pumpDetail(tester, 'entry-1');
      final seeded = controller.entries
          .firstWhere((e) => e.id == 'entry-1')
          .healthLog!
          .aiAdvice!;

      expect(find.byKey(const Key('entry-ai-advice-text')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('entry-ai-advice-text')))
            .data,
        seeded,
      );
      // Regenerate (not "Generate") since advice already exists.
      expect(find.text('Regenerate advice'), findsOneWidget);
      expect(find.text('Generate advice'), findsNothing);
    },
  );

  testWidgets(
    'tapping Generate advice on an entry with none calls the AI service and persists it',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = JournalController(
        MockJournalRepository(),
        dailyAdviceService,
      );
      await controller.loadEntries('trip-001');
      addTearDown(controller.dispose);

      // Every seeded mock entry already has advice - create a fresh one with
      // a health log but no aiAdvice yet, to cover the cold-start Generate
      // path (as opposed to Regenerate, exercised by the other tests here).
      final now = DateTime(2026, 4, 13, 9);
      await controller.create(
        JournalEntry(
          id: 'entry-no-advice-yet',
          tripId: 'trip-001',
          title: 'Fresh entry',
          body: 'No advice generated yet.',
          mood: Mood.happy,
          photoPaths: const [],
          createdAt: now,
          updatedAt: now,
          healthLog: const HealthLog(
            id: 'health-no-advice-yet',
            entryId: 'entry-no-advice-yet',
            steps: 4000,
            caloriesEaten: 1200,
            meals: [],
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalControllerProvider.overrideWith(
              (ref) => controller,
              disposeNotifier: false,
            ),
          ],
          child: const MaterialApp(
            home: EntryDetailScreen(entryId: 'entry-no-advice-yet'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No AI advice yet.'), findsOneWidget);
      expect(find.text('Generate advice'), findsOneWidget);

      await tester.tap(find.byKey(const Key('generate-advice-button')));
      await tester.pumpAndSettle();

      final after = controller.entries
          .firstWhere((e) => e.id == 'entry-no-advice-yet')
          .healthLog!
          .aiAdvice;
      expect(after, isNotNull);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('entry-ai-advice-text')))
            .data,
        after,
      );
      expect(find.text('Regenerate advice'), findsOneWidget);
    },
  );

  testWidgets(
    'editing advice manually persists the exact typed text, not a regeneration',
    (tester) async {
      final controller = await pumpDetail(tester, 'entry-1');

      await tester.tap(find.byKey(const Key('edit-advice-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('advice-editor-field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('advice-editor-field')),
        'Manually written advice.',
      );
      await tester.tap(find.byKey(const Key('save-advice-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('advice-editor-field')), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('entry-ai-advice-text')))
            .data,
        'Manually written advice.',
      );
      final persisted = controller.entries
          .firstWhere((e) => e.id == 'entry-1')
          .healthLog!
          .aiAdvice;
      expect(persisted, 'Manually written advice.');
    },
  );

  testWidgets('Cancel discards an in-progress advice edit without persisting', (
    tester,
  ) async {
    final controller = await pumpDetail(tester, 'entry-1');
    final original = controller.entries
        .firstWhere((e) => e.id == 'entry-1')
        .healthLog!
        .aiAdvice;

    await tester.tap(find.byKey(const Key('edit-advice-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('advice-editor-field')),
      'Discarded draft.',
    );
    await tester.tap(find.byKey(const Key('cancel-edit-advice-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('advice-editor-field')), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('entry-ai-advice-text')))
          .data,
      original,
    );
    final persisted = controller.entries
        .firstWhere((e) => e.id == 'entry-1')
        .healthLog!
        .aiAdvice;
    expect(persisted, original);
  });

  testWidgets(
    'advice persists across navigation: reopening the same entry shows the same text with no regeneration',
    (tester) async {
      final controller = await pumpDetail(tester, 'entry-1');
      await tester.tap(find.byKey(const Key('generate-advice-button')));
      await tester.pumpAndSettle();
      final generated = controller.entries
          .firstWhere((e) => e.id == 'entry-1')
          .healthLog!
          .aiAdvice;

      // Simulate leaving and reopening the entry - a fresh EntryDetailScreen
      // pumped against the same (already-mutated) controller state.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalControllerProvider.overrideWith(
              (ref) => controller,
              disposeNotifier: false,
            ),
          ],
          child: const MaterialApp(home: SizedBox()),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalControllerProvider.overrideWith(
              (ref) => controller,
              disposeNotifier: false,
            ),
          ],
          child: const MaterialApp(
            home: EntryDetailScreen(entryId: 'entry-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('entry-ai-advice-text')))
            .data,
        generated,
      );
    },
  );
}
