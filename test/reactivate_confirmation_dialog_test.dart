import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/widgets/reactivate_confirmation_dialog.dart';

void main() {
  Future<void> openDialog(WidgetTester tester, List<bool> resultBox) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await showReactivateConfirmationDialog(
                  context,
                  targetDisplayName: 'Chong Mei Ling',
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

  group('showReactivateConfirmationDialog', () {
    testWidgets('cancel resolves to false', (tester) async {
      final results = <bool>[];
      await openDialog(tester, results);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(results, [false]);
    });

    testWidgets('confirm resolves to true', (tester) async {
      final results = <bool>[];
      await openDialog(tester, results);

      await tester.tap(find.byKey(const Key('reactivate-confirm-button')));
      await tester.pumpAndSettle();

      expect(results, [true]);
    });
  });
}
