import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/widgets/delete_confirmation_dialog.dart';
import 'package:tripjournal/features/trip/widgets/delete_trip_confirmation_dialog.dart';

void main() {
  group('showDeleteConfirmationDialog (journal entry)', () {
    testWidgets('shows the entry title and returns true on confirm', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDeleteConfirmationDialog(
                    context,
                    entryTitle: 'Arrival in Kyoto',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete entry?'), findsOneWidget);
      expect(
        find.text(
          'This will permanently delete "Arrival in Kyoto". This cannot be undone.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('returns false on cancel', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDeleteConfirmationDialog(
                    context,
                    entryTitle: 'Some entry',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });

  group('showDeleteTripConfirmationDialog', () {
    testWidgets('explains 30-day recovery and returns true on confirm', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDeleteTripConfirmationDialog(
                    context,
                    tripTitle: 'Kyoto Trip',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.text('Move "Kyoto Trip" to Recently Deleted?'),
        findsOneWidget,
      );
      expect(find.text('You can restore it for 30 days.'), findsOneWidget);
      expect(find.textContaining('journal entr'), findsNothing);
      expect(find.textContaining('permanent'), findsNothing);

      await tester.tap(find.text('Move to Trash'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });
}
