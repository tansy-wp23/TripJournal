import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/current_user_id_provider.dart';
import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/data/mock_trip_cover_storage.dart';
import 'package:tripjournal/data/trip_repository.dart';
import 'package:tripjournal/features/home/home_screen.dart';
import 'package:tripjournal/features/trip/controller/trip_controller.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';
import 'package:tripjournal/models/trip.dart';

void main() {
  const userId = '11111111-1111-4111-8111-111111111111';

  testWidgets('Home loads trips with the injected current user ID', (
    tester,
  ) async {
    final repository = _RecordingTripRepository([_trip(userId: userId)]);
    final controller = TripController(
      repository,
      MockJournalRepository(),
      MockTripCoverStorage(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripControllerProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(
          home: HomeScreen(userIdProvider: _FixedUserIdProvider(userId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.requestedUserIds, [userId]);
    expect(find.text('Provider Trip'), findsWidgets);
  });

  testWidgets('Trip View loads trips with the injected current user ID', (
    tester,
  ) async {
    final repository = _RecordingTripRepository([_trip(userId: userId)]);
    final controller = TripController(
      repository,
      MockJournalRepository(),
      MockTripCoverStorage(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripControllerProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(
          home: TripViewScreen(
            tripId: 'provider-trip',
            userIdProvider: _FixedUserIdProvider(userId),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.requestedUserIds, [userId]);
    expect(find.text('Provider Trip'), findsWidgets);
  });

  testWidgets('Home unauthenticated state does not query a fallback user', (
    tester,
  ) async {
    final repository = _RecordingTripRepository(const []);
    final controller = TripController(
      repository,
      MockJournalRepository(),
      MockTripCoverStorage(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripControllerProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(
          home: HomeScreen(userIdProvider: _UnauthenticatedUserIdProvider()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.requestedUserIds, isEmpty);
    expect(find.text('Please sign in to manage trips.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Trip View unauthenticated state does not query a fallback user',
    (tester) async {
      final repository = _RecordingTripRepository(const []);
      final controller = TripController(
        repository,
        MockJournalRepository(),
        MockTripCoverStorage(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tripControllerProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(
            home: TripViewScreen(
              tripId: 'provider-trip',
              userIdProvider: _UnauthenticatedUserIdProvider(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.requestedUserIds, isEmpty);
      expect(find.text('Please sign in to manage trips.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Trip _trip({required String userId}) => Trip(
  id: 'provider-trip',
  userId: userId,
  title: 'Provider Trip',
  startDate: DateTime(2040, 1, 1),
  endDate: DateTime(2040, 1, 2),
  createdAt: DateTime.utc(2039, 12, 1),
  updatedAt: DateTime.utc(2039, 12, 1),
);

final class _FixedUserIdProvider implements CurrentUserIdProvider {
  const _FixedUserIdProvider(this.userId);

  final String userId;

  @override
  String requireUserId() => userId;
}

final class _UnauthenticatedUserIdProvider implements CurrentUserIdProvider {
  const _UnauthenticatedUserIdProvider();

  @override
  String requireUserId() => throw const UnauthenticatedTripUserException();
}

final class _RecordingTripRepository implements TripRepository {
  _RecordingTripRepository(this.trips);

  final List<Trip> trips;
  final List<String> requestedUserIds = [];

  @override
  Future<List<Trip>> getTrips(String userId) async {
    requestedUserIds.add(userId);
    return trips.where((trip) => trip.userId == userId).toList();
  }

  @override
  Future<List<Trip>> getDeletedTrips(String userId) async => const [];

  @override
  Future<Trip?> getTrip(String id) async => null;

  @override
  Future<void> addTrip(Trip trip) async {}

  @override
  Future<void> updateTrip(Trip trip) async {}

  @override
  Future<void> moveToTrash(String id) async {}

  @override
  Future<void> restoreTrip(Trip trip) async {}
}
