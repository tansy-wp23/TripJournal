import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/widgets/suspend_confirmation_dialog.dart';

void main() {
  // Opens the dialog via a real button tap (rather than calling
  // showSuspendConfirmationDialog directly against a captured context) so
  // every test exercises the same realistic trigger path, and stashes the
  // eventual result in [resultBox] for assertions after the dialog closes.
  Future<void> openDialog(WidgetTester tester, List<String?> resultBox) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await showSuspendConfirmationDialog(
                  context,
                  targetDisplayName: 'Alice Tan',
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

  group('showSuspendConfirmationDialog', () {
    testWidgets('confirm button is disabled until a reason is entered',
        (tester) async {
      await openDialog(tester, []);

      final disabled = tester.widget<FilledButton>(
        find.byKey(const Key('suspend-confirm-button')),
      );
      expect(disabled.onPressed, isNull);

      await tester.enterText(find.byKey(const Key('suspend-reason-field')), 'Spam');
      await tester.pumpAndSettle();

      final enabled = tester.widget<FilledButton>(
        find.byKey(const Key('suspend-confirm-button')),
      );
      expect(enabled.onPressed, isNotNull);
    });

    testWidgets('whitespace-only reason does not enable the confirm button',
        (tester) async {
      await openDialog(tester, []);

      await tester.enterText(find.byKey(const Key('suspend-reason-field')), '   ');
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('suspend-confirm-button')),
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

    testWidgets('confirm resolves to the trimmed reason', (tester) async {
      final results = <String?>[];
      await openDialog(tester, results);

      await tester.enterText(
        find.byKey(const Key('suspend-reason-field')),
        '  Reported for spam  ',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('suspend-confirm-button')));
      await tester.pumpAndSettle();

      expect(results, ['Reported for spam']);
    });
  });
}
