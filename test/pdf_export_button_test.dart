import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/main.dart';

/// `Printing.sharePdf` needs a real platform channel. Under `flutter_test`
/// that call never resolves at all (no plugin registered to reply), so
/// `pumpAndSettle` after tapping export would hang forever -- these tests
/// only pump a bounded number of frames and check the button reaches the
/// loading state without throwing. The PDF bytes themselves (the part that
/// can actually break) are covered by journal_pdf_export_test.dart.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TripJournalApp());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'tapping export on an entry starts PDF generation and shows a loading indicator',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Kyoto Trip').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('entry-tile-entry-1')));
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
      await tester.tap(find.text('Kyoto Trip').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('trip-view-export-pdf-button')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}
