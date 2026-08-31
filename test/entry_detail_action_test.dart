import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/features/journal/ai/daily_advice_locator.dart';
import 'package:tripjournal/features/journal/controller/journal_controller.dart';
import 'package:tripjournal/features/journal/screens/entry_detail_screen.dart';

void main() {
  testWidgets('Entry detail separates its primary and secondary actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
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
        child: const MaterialApp(home: EntryDetailScreen(entryId: 'entry-1')),
      ),
    );
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.actions, hasLength(1));
    expect(find.byKey(const Key('edit-entry-button')), findsOneWidget);
    expect(find.text('Edit entry'), findsOneWidget);
    expect(find.byKey(const Key('export-entry-pdf-button')), findsNothing);
    expect(find.byKey(const Key('delete-entry-button')), findsNothing);

    await tester.tap(find.byKey(const Key('entry-detail-more-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Export entry as PDF'), findsOneWidget);
    expect(find.text('Move to Trash'), findsOneWidget);
    expect(find.byKey(const Key('export-entry-pdf-button')), findsOneWidget);
    expect(find.byKey(const Key('delete-entry-button')), findsOneWidget);
  });
}
