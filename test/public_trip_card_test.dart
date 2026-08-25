import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/community/widgets/public_trip_card.dart';
import 'package:tripjournal/features/trip/mock_user.dart';
import 'package:tripjournal/models/trip.dart';

Trip _publicTrip() {
  final now = DateTime.utc(2026, 8, 5, 12);
  return Trip(
    id: 'public-1',
    userId: kMockUserId,
    title: 'Kyoto Trip',
    destination: 'Kyoto, Japan',
    startDate: now,
    endDate: now,
    createdAt: now,
    updatedAt: now,
    isPublic: true,
    publishedAt: now,
    publisherDisplayName: 'Alice',
  );
}

void main() {
  testWidgets('shows title, destination, dates, and publisher name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublicTripCard(trip: _publicTrip(), onTap: () {}),
        ),
      ),
    );

    expect(find.text('Kyoto Trip'), findsOneWidget);
    expect(find.text('Kyoto, Japan'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('falls back to Anonymous when no publisher name is set', (
    tester,
  ) async {
    final trip = _publicTrip().copyWith(clearPublisherDisplayName: true);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PublicTripCard(trip: trip, onTap: () {}))),
    );

    expect(find.text('Anonymous'), findsOneWidget);
  });

  testWidgets('invokes onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublicTripCard(
            trip: _publicTrip(),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PublicTripCard));
    expect(tapped, isTrue);
  });
}
