import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/repository_locator.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';
import 'package:tripjournal/models/journal_entry.dart';

Future<void> _openCreateEntryForKyotoDay(WidgetTester tester, int day) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: TripViewScreen(tripId: 'trip-001')),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(Key('add-entry-day-$day')));
  await tester.pumpAndSettle();
}

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<List<JournalEntry>> _allEntries() =>
    journalRepository.getEntries('trip-001', includeDrafts: true);

void main() {
  group('save as draft on back', () {
    testWidgets('"Save draft" parks the entry and leaves the screen', (
      tester,
    ) async {
      _useTallSurface(tester);

      await _openCreateEntryForKyotoDay(tester, 5);
      await tester.enterText(
        find.byKey(const Key('entry-title-field')),
        'Half-written',
      );
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('discard-save-draft')));
      await tester.pumpAndSettle();

      expect(find.text('New entry'), findsNothing); // left the editor

      final parked = (await _allEntries()).where(
        (e) => e.title == 'Half-written',
      );
      expect(parked, hasLength(1));
      expect(parked.single.isDraft, isTrue);
    });

    testWidgets(
      'a draft with no text at all still saves — the whole point of parking, '
      'since the published-entry rule requires a title or body',
      (tester) async {
        _useTallSurface(tester);

        await _openCreateEntryForKyotoDay(tester, 5);
        // Only a step count: no title, no body — a published entry could not
        // be saved in this state at all.
        await tester.enterText(
          find.byKey(const Key('health-log-steps-field')),
          '8200',
        );
        await tester.pump();

        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('discard-save-draft')));
        await tester.pumpAndSettle();

        expect(find.text('New entry'), findsNothing);

        // Scoped to this entry's step count: journalRepository is an app-wide
        // singleton, so drafts parked by other tests in this file are still
        // in there.
        final parked = (await _allEntries()).where(
          (e) => e.isDraft && e.healthLog?.steps == 8200,
        );
        expect(parked, hasLength(1));
        expect(parked.single.title, isEmpty);
        expect(parked.single.body, isEmpty);
      },
    );

    testWidgets('a draft is hidden from the published-entry read', (
      tester,
    ) async {
      _useTallSurface(tester);

      await _openCreateEntryForKyotoDay(tester, 5);
      await tester.enterText(
        find.byKey(const Key('entry-title-field')),
        'Only a draft',
      );
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('discard-save-draft')));
      await tester.pumpAndSettle();

      // The default read is what the map, stats, AI summary, PDF export and
      // every public view use.
      final published = await journalRepository.getEntries('trip-001');
      expect(published.any((e) => e.title == 'Only a draft'), isFalse);
      expect(published.every((e) => !e.isDraft), isTrue);
    });

    testWidgets('reopening a draft and saving normally publishes it', (
      tester,
    ) async {
      _useTallSurface(tester);

      await _openCreateEntryForKyotoDay(tester, 5);
      await tester.enterText(
        find.byKey(const Key('entry-title-field')),
        'Finish me later',
      );
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('discard-save-draft')));
      await tester.pumpAndSettle();

      final draft = (await _allEntries()).firstWhere(
        (e) => e.title == 'Finish me later',
      );
      expect(draft.isDraft, isTrue);

      // Back on the timeline, the draft is badged and reopens in the editor.
      expect(
        find.byKey(Key('entry-draft-badge-${draft.id}')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(Key('entry-tile-${draft.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Edit entry'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Finish me later'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('save-entry-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-confirm-confirm')));
      await tester.pumpAndSettle();

      final published = await journalRepository.getEntries('trip-001');
      final promoted = published.firstWhere(
        (e) => e.title == 'Finish me later',
      );
      expect(promoted.isDraft, isFalse);
      expect(promoted.id, draft.id); // same row, not a second copy
    });

    testWidgets('parking twice updates the same draft, never a second copy', (
      tester,
    ) async {
      _useTallSurface(tester);

      await _openCreateEntryForKyotoDay(tester, 5);
      await tester.enterText(
        find.byKey(const Key('entry-title-field')),
        'First park',
      );
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('discard-save-draft')));
      await tester.pumpAndSettle();

      final draft = (await _allEntries()).firstWhere(
        (e) => e.title == 'First park',
      );

      await tester.tap(find.byKey(Key('entry-tile-${draft.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('entry-title-field')),
        'Second park',
      );
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('discard-save-draft')));
      await tester.pumpAndSettle();

      final all = await _allEntries();
      // Same row, re-parked: one copy, updated title, and no leftover under
      // the original title.
      expect(all.where((e) => e.id == draft.id), hasLength(1));
      expect(all.firstWhere((e) => e.id == draft.id).title, 'Second park');
      expect(all.where((e) => e.title == 'First park'), isEmpty);
    });
  });
}
