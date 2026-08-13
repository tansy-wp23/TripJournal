import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/widgets/leaving_resolved_remark_dialog.dart';

void main() {
  // Mirrors suspend_confirmation_dialog_test.dart's pattern: opens the
  // dialog via a real button tap rather than calling
  // showLeavingResolvedRemarkDialog directly against a captured context.
  Future<void> openDialog(
    WidgetTester tester,
    List<String?> resultBox, {
    String initialRemarks = '',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await showLeavingResolvedRemarkDialog(
                  context,
                  targetStatusLabel: 'Open',
                  initialRemarks: initialRemarks,
                );
                resultBox.add(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('showLeavingResolvedRemarkDialog', () {
    testWidgets('confirm button is disabled until a remark is entered',
        (tester) async {
      await openDialog(tester, []);

      final disabled = tester.widget<FilledButton>(
        find.byKey(const Key('leaving-resolved-remark-confirm-button')),
      );
      expect(disabled.onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('leaving-resolved-remark-field')),
        'Recurred in production.',
      );
      await tester.pumpAndSettle();

      final enabled = tester.widget<FilledButton>(
        find.byKey(const Key('leaving-resolved-remark-confirm-button')),
      );
      expect(enabled.onPressed, isNotNull);
    });

    testWidgets('whitespace-only remark does not enable the confirm button',
        (tester) async {
      await openDialog(tester, []);

      await tester.enterText(
        find.byKey(const Key('leaving-resolved-remark-field')),
        '   ',
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('leaving-resolved-remark-confirm-button')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('cancel resolves to null', (tester) async {
      final results = <String?>[];
      await openDialog(tester, results);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(results, [null]);
    });

    testWidgets('confirm resolves to the trimmed remark', (tester) async {
      final results = <String?>[];
      await openDialog(tester, results);

      await tester.enterText(
        find.byKey(const Key('leaving-resolved-remark-field')),
        '  Still broken on retest  ',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('leaving-resolved-remark-confirm-button')));
      await tester.pumpAndSettle();

      expect(results, ['Still broken on retest']);
    });

    testWidgets('pre-fills from initialRemarks and still requires non-blank '
        'to enable confirm', (tester) async {
      await openDialog(tester, [], initialRemarks: 'Already noted here.');

      expect(
        find.widgetWithText(TextField, 'Already noted here.'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('leaving-resolved-remark-confirm-button')),
      );
      expect(button.onPressed, isNotNull);
    });
  });
}
