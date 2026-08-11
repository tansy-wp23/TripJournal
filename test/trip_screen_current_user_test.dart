import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/current_user_id_provider.dart';
import 'package:tripjournal/data/journal_repository.dart';
import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/data/mock_trip_cover_storage.dart';
import 'package:tripjournal/data/trip_repository.dart';
import 'package:tripjournal/features/home/home_screen.dart';
import 'package:tripjournal/features/journal/ai/daily_advice_locator.dart';
import 'package:tripjournal/features/journal/controller/journal_controller.dart';
import 'package:tripjournal/features/trip/controller/trip_controller.dart';
import 'package:tripjournal/features/trip/trip_form_screen.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';
import 'package:tripjournal/models/journal_entry.dart';
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

  testWidgets(
    'Trip View rejects unauthenticated access when old-user trips are cached',
    (tester) async {
      const oldUserId = '22222222-2222-4222-8222-222222222222';
      final repository = _RecordingTripRepository([_trip(userId: oldUserId)]);
      final journalRepository = _RecordingJournalRepository();
      final controller = TripController(
        repository,
        journalRepository,
        MockTripCoverStorage(),
      );
      await controller.loadTrips(oldUserId);
      repository.requestedUserIds.clear();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripControllerProvider.overrideWith((ref) => controller),
            journalControllerProvider.overrideWith(
              (ref) => JournalController(journalRepository, dailyAdviceService),
            ),
          ],
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
      expect(journalRepository.requestedTripIds, isEmpty);
      expect(find.text('Please sign in to manage trips.'), findsOneWidget);
    },
  );

  testWidgets('Trip View reloads when cached trips belong to another user', (
    tester,
  ) async {
    const oldUserId = '22222222-2222-4222-8222-222222222222';
    final repository = _RecordingTripRepository([_trip(userId: oldUserId)]);
    final journalRepository = _RecordingJournalRepository();
    final controller = TripController(
      repository,
      journalRepository,
      MockTripCoverStorage(),
    );
    await controller.loadTrips(oldUserId);
    repository.requestedUserIds.clear();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripControllerProvider.overrideWith((ref) => controller),
          journalControllerProvider.overrideWith(
            (ref) => JournalController(journalRepository, dailyAdviceService),
          ),
        ],
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
    expect(journalRepository.requestedTripIds, isEmpty);
    expect(find.text('Trip not found.'), findsOneWidget);
    expect(find.text('Provider Trip'), findsNothing);
  });

  testWidgets('Trip View reuses a matching-user cache and loads its journal', (
    tester,
  ) async {
    final repository = _RecordingTripRepository([_trip(userId: userId)]);
    final journalRepository = _RecordingJournalRepository();
    final controller = TripController(
      repository,
      journalRepository,
      MockTripCoverStorage(),
    );
    await controller.loadTrips(userId);
    repository.requestedUserIds.clear();
    final userIdProvider = _RecordingUserIdProvider(userId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripControllerProvider.overrideWith((ref) => controller),
          journalControllerProvider.overrideWith(
            (ref) => JournalController(journalRepository, dailyAdviceService),
          ),
        ],
        child: MaterialApp(
          home: TripViewScreen(
            tripId: 'provider-trip',
            userIdProvider: userIdProvider,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(userIdProvider.requireCalls, greaterThanOrEqualTo(1));
    expect(repository.requestedUserIds, isEmpty);
    expect(journalRepository.requestedTripIds, ['provider-trip']);
    expect(find.text('Provider Trip'), findsWidgets);
  });

  testWidgets('create flow passes its injected user provider to Trip View', (
    tester,
  ) async {
    final repository = _RecordingTripRepository([]);
    final controller = TripController(
      repository,
      MockJournalRepository(),
      MockTripCoverStorage(),
    );
    final provider = _RecordingUserIdProvider(userId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(home: TripFormScreen(userIdProvider: provider)),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('trip-title-field')),
      'Created Provider Trip',
    );
    await tester.enterText(
      find.byKey(const Key('trip-destination-field')),
      'Test destination',
    );
    await tester.tap(find.byKey(const Key('save-trip-button')));
    await tester.pumpAndSettle();

    expect(provider.requireCalls, greaterThanOrEqualTo(2));
    expect(find.text('Created Provider Trip'), findsWidgets);
  });
}

Trip _trip({required String userId}) => Trip(
  id: 'provider-trip',
  userId: userId,
  title: 'Provider Trip',
  destination: 'Test destination',
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

final class _RecordingUserIdProvider implements CurrentUserIdProvider {
  _RecordingUserIdProvider(this.userId);

  final String userId;
  int requireCalls = 0;

  @override
  String requireUserId() {
    requireCalls++;
    return userId;
  }
}

final class _RecordingTripRepository implements TripRepository {
  _RecordingTripRepository(List<Trip> trips) : trips = List.of(trips);

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
  Future<void> addTrip(Trip trip) async => trips.add(trip);

  @override
  Future<void> updateTrip(Trip trip) async {}

  @override
  Future<void> moveToTrash(String id) async {}

  @override
  Future<void> restoreTrip(Trip trip) async {}
}

final class _RecordingJournalRepository implements JournalRepository {
  final List<String> requestedTripIds = [];

  @override
  Future<List<JournalEntry>> getEntries(String tripId) async {
    requestedTripIds.add(tripId);
    return const [];
  }

  @override
  Future<JournalEntry?> getEntry(String id) async => null;

  @override
  Future<void> addEntry(JournalEntry entry) async {}

  @override
  Future<void> updateEntry(JournalEntry entry) async {}

  @override
  Future<void> deleteEntry(String id) async {}
}
