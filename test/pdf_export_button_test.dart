import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/journal_repository.dart';
import 'package:tripjournal/features/journal/ai/daily_advice_locator.dart';
import 'package:tripjournal/features/journal/controller/journal_controller.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

/// `Printing.sharePdf` needs a real platform channel. Under `flutter_test`
/// that call never resolves at all (no plugin registered to reply), so
/// `pumpAndSettle` after tapping export would hang forever -- these tests
/// only pump a bounded number of frames and check the button reaches the
/// loading state without throwing. The PDF bytes themselves (the part that
/// can actually break) are covered by journal_pdf_export_test.dart.
///
/// The entries below deliberately reference a photo by **file** path rather
/// than a bundled `assets/` one. Asset reads resolve within a microtask, so
/// with the seeded data the whole document now builds and the loading dialog
/// is popped before the first frame is ever pumped — the spinner would be
/// untestable, not absent. A file path forces real async I/O, which is also
/// what a genuine user photo is.
class _FilePhotoJournalRepository implements JournalRepository {
  static final _entries = [
    JournalEntry(
      id: 'entry-1',
      tripId: 'trip-001',
      title: 'Arrival in Kyoto',
      body: 'Landed and took the train straight in.',
      mood: Mood.excited,
      photoPaths: const ['/no/such/directory/photo.jpg'],
      createdAt: DateTime(2026, 4, 10, 19, 30),
      updatedAt: DateTime(2026, 4, 10, 19, 30),
    ),
  ];

  @override
  Future<List<JournalEntry>> getEntries(String tripId) async => _entries;

  @override
  Future<JournalEntry?> getEntry(String id) async =>
      _entries.where((e) => e.id == id).firstOrNull;

  @override
  Future<void> addEntry(JournalEntry entry) async {}

  @override
  Future<void> updateEntry(JournalEntry entry) async {}

  @override
  Future<void> deleteEntry(String id) async {}
}

void main() {
  // Pump the trip view directly (Kyoto = trip-001) rather than the full app:
  // these tests are about PDF export, not auth routing or Home's trip list.
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalControllerProvider.overrideWith(
            (ref) => JournalController(
              _FilePhotoJournalRepository(),
              dailyAdviceService,
            ),
          ),
        ],
        child: const MaterialApp(home: TripViewScreen(tripId: 'trip-001')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'tapping export on an entry starts PDF generation and shows a loading indicator',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('entry-tile-entry-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('entry-detail-more-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('export-entry-pdf-button')));
      await tester.pump(); // shows the loading dialog
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Give PDF generation (pure Dart, no plugin) time to finish and reach
      // the platform-channel share call, without waiting for that call to
      // resolve (it never will here).
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tapping export on a trip starts PDF generation and shows a loading indicator',
    (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('trip-view-more-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('trip-view-export-pdf-button')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the loading dialog is dismissed afterwards, leaving the trip view intact',
    (tester) async {
      // Navigator.pop closes whatever is on top — this guards against it ever
      // taking the screen with it instead of just the dialog.
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('trip-view-more-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('trip-view-export-pdf-button')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // pump() only advances a fake clock; the photo lookup is real file I/O,
      // so generation needs runAsync to actually make progress.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(TripViewScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
