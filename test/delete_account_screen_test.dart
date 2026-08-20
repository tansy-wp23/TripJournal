import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/auth/screens/delete_account_screen.dart';

void main() {
  Widget wrapped() => const MaterialApp(home: DeleteAccountScreen());

  group('DeleteAccountScreen', () {
    testWidgets('shows the warning and a disabled send-code button', (
      tester,
    ) async {
      await tester.pumpWidget(wrapped());

      expect(find.text('Delete Account'), findsOneWidget);
      expect(find.text('Send code'), findsOneWidget);
      expect(find.byKey(const Key('delete-confirm-field')), findsOneWidget);

      final sendButton = tester.widget<FilledButton>(
        find.byKey(const Key('delete-send-code-button')),
      );
      expect(sendButton.onPressed, isNull);
    });

    testWidgets('typing DELETE enables the send-code button', (tester) async {
      await tester.pumpWidget(wrapped());

      await tester.enterText(
        find.byKey(const Key('delete-confirm-field')),
        'DELETE',
      );
      await tester.pump();

      final sendButton = tester.widget<FilledButton>(
        find.byKey(const Key('delete-send-code-button')),
      );
      expect(sendButton.onPressed, isNotNull);
    });

    testWidgets('typing something other than DELETE keeps it disabled', (
      tester,
    ) async {
      await tester.pumpWidget(wrapped());

      await tester.enterText(
        find.byKey(const Key('delete-confirm-field')),
        'delete',
      );
      await tester.pump();

      final sendButton = tester.widget<FilledButton>(
        find.byKey(const Key('delete-send-code-button')),
      );
      expect(sendButton.onPressed, isNull);
    });

    testWidgets('cancel pops back', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('open-delete-screen'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DeleteAccountScreen(),
                    ),
                  ),
                  child: const Text('Open delete'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open-delete-screen')));
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('delete-cancel-button')));
      await tester.pumpAndSettle();

      expect(find.byType(DeleteAccountScreen), findsNothing);
    });
  });
}