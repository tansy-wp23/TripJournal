import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/community/public_trip_view_screen.dart';
import 'package:tripjournal/features/trip/mock_user.dart';
import 'package:tripjournal/models/trip.dart';

Trip _publicTrip() {
  final now = DateTime.utc(2026, 4, 10);
  return Trip(
    id: 'trip-001',
    userId: kMockUserId,
    title: 'Kyoto Trip',
    destination: 'Kyoto, Japan',
    startDate: now,
    endDate: now.add(const Duration(days: 2)),
    summary: 'A memorable trip.',
    createdAt: now,
    updatedAt: now,
    isPublic: true,
    publishedAt: now,
    publisherDisplayName: 'Alice',
  );
}

void main() {
  // Reads entries for 'trip-001' via journalRepository, which under the mock
  // backend resolves to the seeded MockJournalRepository entries for that id.
  testWidgets('shows the publisher banner, title, and trip summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: PublicTripViewScreen(trip: _publicTrip())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shared by Alice'), findsOneWidget);
    expect(find.text('Kyoto Trip'), findsWidgets);
    expect(find.text('A memorable trip.'), findsOneWidget);
    expect(find.byKey(const Key('public-trip-share-button')), findsOneWidget);
  });

  testWidgets('has no edit, add, or delete actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: PublicTripViewScreen(trip: _publicTrip())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
