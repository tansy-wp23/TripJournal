import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/trip_repository.dart';
import 'package:tripjournal/features/community/controller/community_controller.dart';
import 'package:tripjournal/features/community/public_trip_view_screen.dart';
import 'package:tripjournal/features/trip/trip_link.dart';
import 'package:tripjournal/features/trip/trip_link_listener.dart';
import 'package:tripjournal/models/trip.dart';

/// Returns exactly [trip] for [tripId], regardless of who's asking -
/// `fetchPublicTrip` is the same anon-readable query for guest and signed-in
/// callers alike, so one fake repository is enough to prove both work.
class _FakeTripRepository implements TripRepository {
  _FakeTripRepository(this.tripId, this.trip);

  final String tripId;
  final Trip? trip;

  @override
  Future<Trip?> getTrip(String id) async => id == tripId ? trip : null;

  @override
  Future<List<Trip>> getTrips(String userId) async => [];
  @override
  Future<List<Trip>> getDeletedTrips(String userId) async => [];
  @override
  Future<void> addTrip(Trip trip) async {}
  @override
  Future<void> updateTrip(Trip trip) async {}
  @override
  Future<void> moveToTrash(String id) async {}
  @override
  Future<void> restoreTrip(Trip trip) async {}
  @override
  Future<List<Trip>> getPublicTrips() async => [];
}

Trip _publicTrip(String id) {
  final now = DateTime(2026, 4, 10);
  return Trip(
    id: id,
    userId: 'owner-1',
    title: 'Shared via link',
    startDate: now,
    endDate: now,
    createdAt: now,
    updatedAt: now,
    isPublic: true,
  );
}

Future<StreamController<Uri>> pumpListener(
  WidgetTester tester, {
  required TripRepository tripRepository,
  required Widget child,
}) async {
  final linkController = StreamController<Uri>();
  final navigatorKey = GlobalKey<NavigatorState>();
  addTearDown(linkController.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communityControllerProvider.overrideWith(
          (ref) => CommunityController(tripRepository),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: TripLinkListener(
          navigatorKey: navigatorKey,
          linkStream: linkController.stream,
          child: child,
        ),
      ),
    ),
  );
  await tester.pump();
  return linkController;
}

void main() {
  testWidgets(
    'a valid link opens the trip on top of a guest (signed-out) screen',
    (tester) async {
      final trip = _publicTrip('shared-trip-1');
      final linkController = await pumpListener(
        tester,
        tripRepository: _FakeTripRepository('shared-trip-1', trip),
        child: const Scaffold(body: Text('Guest Community feed')),
      );

      expect(find.text('Guest Community feed'), findsOneWidget);
      expect(find.byType(PublicTripViewScreen), findsNothing);

      linkController.add(Uri.parse(tripLinkFor('shared-trip-1')));
      await tester.pumpAndSettle();

      expect(find.byType(PublicTripViewScreen), findsOneWidget);
      expect(find.text('Shared via link'), findsWidgets);
    },
  );

  testWidgets(
    'a valid link opens the trip on top of a signed-in screen',
    (tester) async {
      final trip = _publicTrip('shared-trip-2');
      final linkController = await pumpListener(
        tester,
        tripRepository: _FakeTripRepository('shared-trip-2', trip),
        child: const Scaffold(body: Text('Signed-in Home')),
      );

      expect(find.text('Signed-in Home'), findsOneWidget);
      expect(find.byType(PublicTripViewScreen), findsNothing);

      linkController.add(Uri.parse(tripLinkFor('shared-trip-2')));
      await tester.pumpAndSettle();

      expect(find.byType(PublicTripViewScreen), findsOneWidget);
      expect(find.text('Shared via link'), findsWidgets);
    },
  );

  testWidgets(
    'a link to a private/missing trip shows a not-found dialog instead',
    (tester) async {
      final linkController = await pumpListener(
        tester,
        tripRepository: _FakeTripRepository('shared-trip-3', null),
        child: const Scaffold(body: Text('Signed-in Home')),
      );

      linkController.add(Uri.parse(tripLinkFor('some-other-id')));
      await tester.pumpAndSettle();

      expect(find.text('Trip not found'), findsOneWidget);
      expect(find.byType(PublicTripViewScreen), findsNothing);

      await tester.tap(find.byKey(const Key('trip-link-not-found-ok')));
      await tester.pumpAndSettle();
      expect(find.text('Trip not found'), findsNothing);
    },
  );

  testWidgets('a link with the wrong scheme/host is ignored entirely', (
    tester,
  ) async {
    final trip = _publicTrip('shared-trip-4');
    final linkController = await pumpListener(
      tester,
      tripRepository: _FakeTripRepository('shared-trip-4', trip),
      child: const Scaffold(body: Text('Signed-in Home')),
    );

    linkController.add(Uri.parse('https://example.com/not-a-trip-link'));
    await tester.pumpAndSettle();

    expect(find.text('Signed-in Home'), findsOneWidget);
    expect(find.byType(PublicTripViewScreen), findsNothing);
    expect(find.text('Trip not found'), findsNothing);
  });
}
