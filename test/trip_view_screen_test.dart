import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/data/mock_trip_cover_storage.dart';
import 'package:tripjournal/data/mock_trip_repository.dart';
import 'package:tripjournal/data/trip_repository.dart';
import 'package:tripjournal/features/home/home_screen.dart';
import 'package:tripjournal/features/trip/controller/trip_controller.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';
import 'package:tripjournal/models/trip.dart';

Widget _wrapped(String tripId) {
  return ProviderScope(
    child: MaterialApp(home: TripViewScreen(tripId: tripId)),
  );
}

void main() {
  testWidgets('today/past days show an Add entry action, no Upcoming marker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // trip-002 (Osaka) is fully in the past — both its days are writable.
    await tester.pumpWidget(_wrapped('trip-002'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-entry-day-1')), findsOneWidget);
    expect(find.byKey(const Key('add-entry-day-2')), findsOneWidget);
    expect(find.text('Upcoming'), findsNothing);
  });

  testWidgets('future days are muted with no Add entry action', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // trip-003 (Taipei) is fully in the future.
    await tester.pumpWidget(_wrapped('trip-003'));
    await tester.pumpAndSettle();

    expect(find.text('Upcoming'), findsWidgets);
    expect(find.textContaining('Add entry'), findsNothing);
  });

  testWidgets(
    'moving a trip to trash returns Home and reloads dashboard data',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _CountingTripRepository();
      final controller = TripController(
        repository,
        MockJournalRepository(),
        MockTripCoverStorage(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [tripControllerProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.getTripsCalls, 1);
      await tester.tap(find.text('Osaka Trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('trip-view-delete-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to Trash'));
      await tester.pumpAndSettle();

      expect(find.text('Your Trips'), findsOneWidget);
      expect(find.text('Osaka Trip'), findsNothing);
      expect(repository.getTripsCalls, 3);
    },
  );

  testWidgets(
    'create then trash forwards success through Trip View and reloads Home',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _EmptyCountingTripRepository();
      final controller = TripController(
        repository,
        MockJournalRepository(),
        MockTripCoverStorage(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [tripControllerProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.getTripsCalls, 1);
      await tester.tap(find.text('Create your first trip'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('trip-title-field')),
        'Create then trash',
      );
      await tester.enterText(
        find.byKey(const Key('trip-destination-field')),
        'Test destination',
      );
      await tester.tap(find.byKey(const Key('save-trip-button')));
      await tester.pumpAndSettle();
      expect(find.text('Create then trash'), findsWidgets);

      await tester.tap(find.byKey(const Key('trip-view-delete-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to Trash'));
      await tester.pumpAndSettle();

      expect(find.text('No trips yet'), findsOneWidget);
      expect(repository.getTripsCalls, 4);
    },
  );
}

final class _CountingTripRepository extends MockTripRepository {
  int getTripsCalls = 0;

  @override
  Future<List<Trip>> getTrips(String userId) {
    getTripsCalls++;
    return super.getTrips(userId);
  }
}

final class _EmptyCountingTripRepository implements TripRepository {
  final List<Trip> trips = [];
  int getTripsCalls = 0;

  @override
  Future<List<Trip>> getTrips(String userId) async {
    getTripsCalls++;
    return trips
        .where((trip) => trip.userId == userId && trip.deletedAt == null)
        .toList();
  }

  @override
  Future<List<Trip>> getDeletedTrips(String userId) async => const [];

  @override
  Future<Trip?> getTrip(String id) async {
    for (final trip in trips) {
      if (trip.id == id) return trip;
    }
    return null;
  }

  @override
  Future<void> addTrip(Trip trip) async => trips.add(trip);

  @override
  Future<void> updateTrip(Trip trip) async {
    final index = trips.indexWhere((candidate) => candidate.id == trip.id);
    trips[index] = trip;
  }

  @override
  Future<void> moveToTrash(String id) async {
    trips.removeWhere((trip) => trip.id == id);
  }

  @override
  Future<void> restoreTrip(Trip trip) async => trips.add(trip);
}
