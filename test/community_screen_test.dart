import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_trip_repository.dart';
import 'package:tripjournal/features/community/community_screen.dart';
import 'package:tripjournal/features/community/controller/community_controller.dart';
import 'package:tripjournal/features/community/public_trip_view_screen.dart';
import 'package:tripjournal/features/trip/mock_user.dart';
import 'package:tripjournal/models/trip.dart';

Trip _publicTrip(String id, {String? destination}) {
  final now = DateTime.utc(2026, 8, 5, 12);
  return Trip(
    id: id,
    userId: kMockUserId,
    title: 'Public Trip $id',
    destination: destination,
    startDate: now,
    endDate: now,
    createdAt: now,
    updatedAt: now,
    isPublic: true,
    publishedAt: now,
    publisherDisplayName: 'Alice',
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  CommunityController controller, {
  VoidCallback? onSignIn,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [communityControllerProvider.overrideWith((ref) => controller)],
      child: MaterialApp(home: CommunityScreen(onSignIn: onSignIn)),
    ),
  );
  await tester.pump(); // triggers the post-frame load callback
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the empty state when no trips are published', (
    tester,
  ) async {
    final controller = CommunityController(MockTripRepository());

    await _pumpScreen(tester, controller);

    expect(find.text('No trips published yet'), findsOneWidget);
  });

  testWidgets('lists every loaded public trip as a card', (tester) async {
    final repository = MockTripRepository();
    await repository.addTrip(_publicTrip('public-1'));
    await repository.addTrip(_publicTrip('public-2'));
    final controller = CommunityController(repository);

    await _pumpScreen(tester, controller);

    expect(find.text('Public Trip public-1'), findsOneWidget);
    expect(find.text('Public Trip public-2'), findsOneWidget);
  });

  testWidgets('tapping a card opens the read-only public trip view', (
    tester,
  ) async {
    final repository = MockTripRepository();
    await repository.addTrip(_publicTrip('public-1'));
    final controller = CommunityController(repository);

    await _pumpScreen(tester, controller);
    await tester.tap(find.text('Public Trip public-1'));
    await tester.pumpAndSettle();

    expect(find.byType(PublicTripViewScreen), findsOneWidget);
  });

  group('search by ID', () {
    testWidgets('opens a public trip that matches the entered ID', (
      tester,
    ) async {
      final repository = MockTripRepository();
      await repository.addTrip(_publicTrip('public-1'));
      final controller = CommunityController(repository);

      await _pumpScreen(tester, controller);
      await tester.tap(find.byKey(const Key('community-search-by-id')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'public-1');
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(PublicTripViewScreen), findsOneWidget);
    });

    testWidgets('shows a not-found message for an unknown or private ID', (
      tester,
    ) async {
      final controller = CommunityController(MockTripRepository());

      await _pumpScreen(tester, controller);
      await tester.tap(find.byKey(const Key('community-search-by-id')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'does-not-exist');
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.text('Trip not found. It may not be public or may not exist.'),
        findsOneWidget,
      );
    });

    testWidgets('Cancel closes the dialog without navigating', (
      tester,
    ) async {
      final controller = CommunityController(MockTripRepository());

      await _pumpScreen(tester, controller);
      await tester.tap(find.byKey(const Key('community-search-by-id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Open Trip by ID'), findsNothing);
      expect(find.byType(PublicTripViewScreen), findsNothing);
    });
  });

  group('search by destination', () {
    testWidgets('search field is hidden until the toggle is tapped', (
      tester,
    ) async {
      final repository = MockTripRepository();
      await repository.addTrip(_publicTrip('public-1', destination: 'Kyoto'));
      final controller = CommunityController(repository);

      await _pumpScreen(tester, controller);

      expect(
        find.byKey(const Key('community-destination-search-field')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('community-destination-search-toggle')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('community-destination-search-field')),
        findsOneWidget,
      );
    });

    testWidgets('filters the list to trips matching the destination', (
      tester,
    ) async {
      final repository = MockTripRepository();
      await repository.addTrip(_publicTrip('public-1', destination: 'Kyoto, Japan'));
      await repository.addTrip(_publicTrip('public-2', destination: 'Melaka, Malaysia'));
      final controller = CommunityController(repository);

      await _pumpScreen(tester, controller);
      await tester.tap(
        find.byKey(const Key('community-destination-search-toggle')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('community-destination-search-field')),
        'kyoto',
      );
      await tester.pumpAndSettle();

      expect(find.text('Public Trip public-1'), findsOneWidget);
      expect(find.text('Public Trip public-2'), findsNothing);
    });

    testWidgets('shows the no-matches state when nothing matches', (
      tester,
    ) async {
      final repository = MockTripRepository();
      await repository.addTrip(_publicTrip('public-1', destination: 'Kyoto, Japan'));
      final controller = CommunityController(repository);

      await _pumpScreen(tester, controller);
      await tester.tap(
        find.byKey(const Key('community-destination-search-toggle')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('community-destination-search-field')),
        'nowhere',
      );
      await tester.pumpAndSettle();

      expect(find.text('No trips match this filter.'), findsOneWidget);
      expect(find.text('Public Trip public-1'), findsNothing);
    });

    testWidgets('Clear filter resets the query and restores the list', (
      tester,
    ) async {
      final repository = MockTripRepository();
      await repository.addTrip(_publicTrip('public-1', destination: 'Kyoto, Japan'));
      final controller = CommunityController(repository);

      await _pumpScreen(tester, controller);
      await tester.tap(
        find.byKey(const Key('community-destination-search-toggle')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('community-destination-search-field')),
        'nowhere',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear filter'));
      await tester.pumpAndSettle();

      expect(find.text('Public Trip public-1'), findsOneWidget);
    });

    testWidgets('toggling the search off clears the query', (tester) async {
      final repository = MockTripRepository();
      await repository.addTrip(_publicTrip('public-1', destination: 'Kyoto, Japan'));
      final controller = CommunityController(repository);

      await _pumpScreen(tester, controller);
      await tester.tap(
        find.byKey(const Key('community-destination-search-toggle')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('community-destination-search-field')),
        'nowhere',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('community-destination-search-toggle')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('community-destination-search-field')),
        findsNothing,
      );
      expect(find.text('Public Trip public-1'), findsOneWidget);
    });
  });

  group('guest mode (onSignIn)', () {
    testWidgets(
      'no "Sign in" affordance when onSignIn is null (the signed-in path)',
      (tester) async {
        final repository = MockTripRepository();
        await repository.addTrip(_publicTrip('public-1'));
        final controller = CommunityController(repository);

        await _pumpScreen(tester, controller);

        expect(
          find.byKey(const Key('guest-sign-in-button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'shows a "Sign in" AppBar action and calls onSignIn when tapped',
      (tester) async {
        final repository = MockTripRepository();
        await repository.addTrip(_publicTrip('public-1'));
        final controller = CommunityController(repository);
        var signInTapped = false;

        await _pumpScreen(
          tester,
          controller,
          onSignIn: () => signInTapped = true,
        );

        expect(find.byKey(const Key('guest-sign-in-button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('guest-sign-in-button')));

        expect(signInTapped, isTrue);
      },
    );

    testWidgets(
      'the empty state invites the guest to sign in instead of the '
      'signed-in "be the first" message',
      (tester) async {
        final controller = CommunityController(MockTripRepository());

        await _pumpScreen(tester, controller, onSignIn: () {});

        expect(
          find.text('Sign in to create and share your own trips!'),
          findsOneWidget,
        );
        expect(
          find.text('Be the first to share a trip with the community!'),
          findsNothing,
        );
        expect(
          find.byKey(const Key('guest-empty-state-sign-in-button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the signed-in empty state is unchanged when onSignIn is null',
      (tester) async {
        final controller = CommunityController(MockTripRepository());

        await _pumpScreen(tester, controller);

        expect(
          find.text('Be the first to share a trip with the community!'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('guest-empty-state-sign-in-button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'shows "Create your first trip" below a non-empty trip list and calls '
      'onSignIn when tapped',
      (tester) async {
        final repository = MockTripRepository();
        await repository.addTrip(_publicTrip('public-1'));
        final controller = CommunityController(repository);
        var signInTapped = false;

        await _pumpScreen(
          tester,
          controller,
          onSignIn: () => signInTapped = true,
        );

        expect(
          find.byKey(const Key('guest-create-first-trip-button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('guest-create-first-trip-button')));

        expect(signInTapped, isTrue);
      },
    );

    testWidgets(
      'no "Create your first trip" button on the signed-in path '
      '(onSignIn null)',
      (tester) async {
        final repository = MockTripRepository();
        await repository.addTrip(_publicTrip('public-1'));
        final controller = CommunityController(repository);

        await _pumpScreen(tester, controller);

        expect(
          find.byKey(const Key('guest-create-first-trip-button')),
          findsNothing,
        );
      },
    );
  });
}
