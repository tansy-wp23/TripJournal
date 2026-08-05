import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/data/mock_trip_cover_storage.dart';
import 'package:tripjournal/data/mock_trip_repository.dart';
import 'package:tripjournal/features/trip/controller/trip_controller.dart';
import 'package:tripjournal/features/trip/mock_user.dart';
import 'package:tripjournal/models/trip.dart';

void main() {
  late TripController controller;

  setUp(() async {
    controller = TripController(
      MockTripRepository(),
      MockJournalRepository(),
      MockTripCoverStorage(),
    );
    await controller.loadTrips(kMockUserId);
  });

  Trip newTrip({
    required String id,
    required String title,
    required DateTime start,
    required DateTime end,
  }) {
    return Trip(
      id: id,
      userId: kMockUserId,
      title: title,
      startDate: start,
      endDate: end,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  test(
    'createTrip rejects a title over 100 chars — validation lives in the controller, not just the form',
    () async {
      final trip = newTrip(
        id: 'new-trip',
        title: 'a' * 101,
        start: DateTime(2027, 1, 1),
        end: DateTime(2027, 1, 2),
      );

      final error = await controller.createTrip(trip);

      expect(error, 'Trip title must be 100 characters or fewer.');
      expect(controller.trips.any((t) => t.id == 'new-trip'), isFalse);
    },
  );

  test(
    'createTrip rejects overlapping dates against the seeded active trip',
    () async {
      // trip-001 (Kyoto) covers April 10 2026 through "today + 2" in the seed.
      final trip = newTrip(
        id: 'new-trip',
        title: 'Conflicting Trip',
        start: DateTime(2026, 4, 11),
        end: DateTime(2026, 4, 12),
      );

      final error = await controller.createTrip(trip);

      expect(error, isNotNull);
      expect(error, contains('You already have a trip during these dates'));
      expect(error, contains('Kyoto Trip'));
      expect(controller.trips.any((t) => t.id == 'new-trip'), isFalse);
    },
  );

  test('editTrip rejects end-before-start', () async {
    final osaka = controller.trips.firstWhere((t) => t.id == 'trip-002');
    final invalid = osaka.copyWith(
      endDate: osaka.startDate.subtract(const Duration(days: 1)),
    );

    final error = await controller.editTrip(invalid);

    expect(error, 'End date must be on or after the start date.');
  });

  test('editTrip does not collide with its own unchanged dates', () async {
    final osaka = controller.trips.firstWhere((t) => t.id == 'trip-002');
    final renamed = osaka.copyWith(title: 'Osaka Trip (renamed)');

    final error = await controller.editTrip(renamed);

    expect(error, isNull);
    expect(
      controller.trips.firstWhere((t) => t.id == 'trip-002').title,
      'Osaka Trip (renamed)',
    );
  });

  test('createTrip succeeds and persists when everything is valid', () async {
    final trip = newTrip(
      id: 'new-trip',
      title: 'Valid Future Trip',
      start: DateTime(2027, 1, 1),
      end: DateTime(2027, 1, 5),
    );

    final error = await controller.createTrip(trip);

    expect(error, isNull);
    expect(controller.trips.any((t) => t.id == 'new-trip'), isTrue);
  });
}
