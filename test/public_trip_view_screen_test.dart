import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/community/public_trip_view_screen.dart';
import 'package:tripjournal/features/journal/screens/photo_viewer_screen.dart';
import 'package:tripjournal/features/journal/widgets/photo_thumbnail.dart';
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

  group('photos and meal detail', () {
    testWidgets('shows every journal entry photo, not just the body text', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: PublicTripViewScreen(trip: _publicTrip())),
        ),
      );
      await tester.pumpAndSettle();

      // entry-1 (seeded) has two photos.
      expect(
        find.byKey(const Key('public-entry-photo-entry-1-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('public-entry-photo-entry-1-1')),
        findsOneWidget,
      );
    });

    testWidgets('tapping an entry photo opens the full-screen viewer', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: PublicTripViewScreen(trip: _publicTrip())),
        ),
      );
      await tester.pumpAndSettle();

      final photoFinder = find.byKey(
        const Key('public-entry-photo-entry-1-0'),
      );
      await tester.ensureVisible(photoFinder);
      await tester.pumpAndSettle();
      await tester.tap(photoFinder);
      await tester.pumpAndSettle();

      expect(find.byType(PhotoViewerScreen), findsOneWidget);
    });

    testWidgets(
      'shows the food photo, restaurant, review, and rating for a meal, '
      'not just its name',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: PublicTripViewScreen(trip: _publicTrip()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // meal-1b (seeded "Ramen") carries a food photo, restaurant, review
        // and rating — all of it should reach the public view.
        expect(
          find.byKey(const Key('public-meal-photo-meal-1b')),
          findsOneWidget,
        );
        expect(find.text('Ichiran Gion'), findsOneWidget);
        expect(
          find.text('Rich tonkotsu broth, could\'ve used less salt.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('public-meal-rating-meal-1b')),
          findsOneWidget,
        );
      },
    );

    testWidgets('a meal with no photo still shows its other details', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: PublicTripViewScreen(trip: _publicTrip())),
        ),
      );
      await tester.pumpAndSettle();

      // meal-1a ("Onigiri set") has no photo, restaurant, review, or rating.
      expect(find.text('Onigiri set'), findsOneWidget);
      expect(
        find.byKey(const Key('public-meal-photo-meal-1a')),
        findsNothing,
      );
      expect(find.byType(PhotoThumbnail), findsWidgets);
    });
  });
}
