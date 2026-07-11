import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_trip_repository.dart';
import 'package:tripjournal/features/trip/mock_user.dart';
import 'package:tripjournal/models/trip.dart';

Trip _newTrip({String id = 'trip-new', String userId = kMockUserId}) {
  final now = DateTime.now();
  return Trip(
    id: id,
    userId: userId,
    title: 'New Trip',
    startDate: now,
    endDate: now,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late MockTripRepository repository;

  setUp(() {
    repository = MockTripRepository();
  });

  group('seed data', () {
    test('getTrips returns exactly the 3 seeded trips for the mock user', () async {
      final trips = await repository.getTrips(kMockUserId);
      expect(trips.length, 3);
      expect(trips.map((t) => t.id).toSet(), {'trip-001', 'trip-002', 'trip-003'});
    });

    test('getTrips returns empty for an unknown user', () async {
      expect(await repository.getTrips('someone-else'), isEmpty);
    });

    test('exactly one seeded trip is active, one past, one upcoming', () async {
      final trips = await repository.getTrips(kMockUserId);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final active = trips.where((t) => t.isActiveOn(now));
      final past = trips.where((t) => t.endDate.isBefore(today));
      final upcoming = trips.where((t) => t.startDate.isAfter(today));

      expect(active.length, 1);
      expect(past.length, 1);
      expect(upcoming.length, 1);
    });

    test('getTrip finds a seeded trip by id', () async {
      final trip = await repository.getTrip('trip-002');
      expect(trip?.title, 'Osaka Trip');
    });

    test('getTrip returns null for an unknown id', () async {
      expect(await repository.getTrip('does-not-exist'), isNull);
    });
  });

  group('CRUD', () {
    test('addTrip makes the trip retrievable via getTrip and getTrips', () async {
      final trip = _newTrip();
      await repository.addTrip(trip);

      expect((await repository.getTrip(trip.id))?.title, 'New Trip');
      expect((await repository.getTrips(kMockUserId)).any((t) => t.id == trip.id), isTrue);
    });

    test('updateTrip replaces the trip with matching id', () async {
      final trip = _newTrip();
      await repository.addTrip(trip);

      await repository.updateTrip(trip.copyWith(title: 'Renamed Trip'));

      expect((await repository.getTrip(trip.id))?.title, 'Renamed Trip');
    });

    test('updateTrip is a no-op when the id does not exist', () async {
      final before = await repository.getTrips(kMockUserId);
      await repository.updateTrip(_newTrip(id: 'not-in-repo'));
      final after = await repository.getTrips(kMockUserId);
      expect(after.length, before.length);
    });

    test('deleteTrip removes the trip', () async {
      final trip = _newTrip();
      await repository.addTrip(trip);
      expect(await repository.getTrip(trip.id), isNotNull);

      await repository.deleteTrip(trip.id);

      expect(await repository.getTrip(trip.id), isNull);
    });

    test('deleteTrip is a no-op when the id does not exist', () async {
      final before = await repository.getTrips(kMockUserId);
      await repository.deleteTrip('not-in-repo');
      final after = await repository.getTrips(kMockUserId);
      expect(after.length, before.length);
    });
  });
}
