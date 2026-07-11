import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/widgets/delete_confirmation_dialog.dart';
import 'package:tripjournal/features/trip/widgets/delete_trip_confirmation_dialog.dart';

void main() {
  group('showDeleteConfirmationDialog (journal entry)', () {
    testWidgets('shows the entry title and returns true on confirm', (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDeleteConfirmationDialog(context, entryTitle: 'Arrival in Kyoto');
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete entry?'), findsOneWidget);
      expect(
        find.text('This will permanently delete "Arrival in Kyoto". This cannot be undone.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('returns false on cancel', (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDeleteConfirmationDialog(context, entryTitle: 'Some entry');
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });

  group('showDeleteTripConfirmationDialog', () {
    testWidgets('shows the real entry count, pluralized correctly, and returns true on confirm', (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDeleteTripConfirmationDialog(
                  context,
                  tripTitle: 'Kyoto Trip',
                  entryCount: 3,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete trip?'), findsOneWidget);
      expect(
        find.text('Delete "Kyoto Trip" and its 3 journal entries? This cannot be undone.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('uses singular "entry" wording for a count of exactly 1', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDeleteTripConfirmationDialog(context, tripTitle: 'Osaka Trip', entryCount: 1),
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.text('Delete "Osaka Trip" and its 1 journal entry? This cannot be undone.'),
        findsOneWidget,
      );
    });

    testWidgets('uses a plain message with no entry count when the trip has zero entries', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDeleteTripConfirmationDialog(context, tripTitle: 'Taipei Trip', entryCount: 0),
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.text('This will permanently delete "Taipei Trip". This cannot be undone.'),
        findsOneWidget,
      );
    });
  });
}
