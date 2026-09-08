import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/repository_locator.dart';
import 'package:tripjournal/features/community/public_trip_view_screen.dart';
import 'package:tripjournal/features/journal/screens/photo_viewer_screen.dart';
import 'package:tripjournal/features/journal/widgets/photo_thumbnail.dart';
import 'package:tripjournal/features/trip/mock_user.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';
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
    expect(find.byKey(const Key('public-trip-more-menu')), findsOneWidget);

    await tester.tap(find.byKey(const Key('public-trip-more-menu')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('public-trip-share-link-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('public-trip-copy-id-button')), findsOneWidget);
  });

  testWidgets('Share link sends only the TripJournal deep link', (
    tester,
  ) async {
    final methodCalls = <MethodCall>[];
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
          methodCalls.add(call);
          return '';
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, null),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: PublicTripViewScreen(trip: _publicTrip())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('public-trip-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('public-trip-share-link-button')));
    await tester.pumpAndSettle();

    expect(methodCalls, hasLength(1));
    expect(methodCalls.single.method, 'share');
    final arguments = methodCalls.single.arguments as Map<Object?, Object?>;
    expect(arguments['text'], 'tripjournal://trip/trip-001');
    expect(arguments['subject'], isNull);
  });

  testWidgets('Copy trip ID copies only the raw ID and confirms success', (
    tester,
  ) async {
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final arguments = call.arguments as Map<Object?, Object?>;
            copiedText = arguments['text'] as String?;
          }
          if (call.method == 'Clipboard.getData') {
            return <String, Object?>{'text': copiedText};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: PublicTripViewScreen(trip: _publicTrip())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('public-trip-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('public-trip-copy-id-button')));
    await tester.pumpAndSettle();

    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboard?.text, 'trip-001');
    expect(find.text('Trip ID copied'), findsOneWidget);
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

      final photoFinder = find.byKey(const Key('public-entry-photo-entry-1-0'));
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
            child: MaterialApp(home: PublicTripViewScreen(trip: _publicTrip())),
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
      expect(find.byKey(const Key('public-meal-photo-meal-1a')), findsNothing);
      expect(find.byType(PhotoThumbnail), findsWidgets);
    });
  });

  testWidgets(
    'a draft in a published trip is never shown to a viewer — this screen '
    'reads the repository directly, so the default filter is the only guard',
    (tester) async {
      final draft = JournalEntry(
        id: 'draft-in-public-trip',
        tripId: 'trip-001',
        title: 'Half-written and private',
        body: 'Not ready for anyone else to read.',
        mood: Mood.neutral,
        photoPaths: const [],
        createdAt: DateTime.utc(2026, 4, 10, 9),
        updatedAt: DateTime.utc(2026, 4, 10, 9),
        isDraft: true,
      );
      await journalRepository.addEntry(draft);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: PublicTripViewScreen(trip: _publicTrip())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Half-written and private'), findsNothing);
      expect(find.text('Not ready for anyone else to read.'), findsNothing);
    },
  );
}
