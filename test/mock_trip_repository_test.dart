import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_trip_repository.dart';
import 'package:tripjournal/features/trip/mock_user.dart';
import 'package:tripjournal/models/trip.dart';

Trip _newTrip({
  String id = 'trip-new',
  String userId = kMockUserId,
  DateTime? deletedAt,
}) {
  final now = DateTime.utc(2026, 8, 5, 12);
  return Trip(
    id: id,
    userId: userId,
    title: 'New Trip',
    startDate: now,
    endDate: now,
    createdAt: now,
    updatedAt: now,
    deletedAt: deletedAt,
  );
}

void main() {
  late MockTripRepository repository;
  final now = DateTime.utc(2026, 8, 5, 12);

  setUp(() {
    repository = MockTripRepository(clock: () => now);
  });

  group('seed data', () {
    test(
      'getTrips returns exactly the 3 seeded trips for the mock user',
      () async {
        final trips = await repository.getTrips(kMockUserId);
        expect(trips.length, 3);
        expect(trips.map((t) => t.id).toSet(), {
          'trip-001',
          'trip-002',
          'trip-003',
        });
      },
    );

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
    test(
      'addTrip makes the trip retrievable via getTrip and getTrips',
      () async {
        final trip = _newTrip();
        await repository.addTrip(trip);

        expect((await repository.getTrip(trip.id))?.title, 'New Trip');
        expect(
          (await repository.getTrips(kMockUserId)).any((t) => t.id == trip.id),
          isTrue,
        );
      },
    );

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

    test(
      'moveToTrash hides a trip from active queries and stamps UTC time',
      () async {
        final trip = _newTrip();
        await repository.addTrip(trip);

        await repository.moveToTrash(trip.id);

        expect(
          (await repository.getTrips(kMockUserId)).any((t) => t.id == trip.id),
          isFalse,
        );
        expect((await repository.getTrip(trip.id))?.deletedAt, now);
      },
    );

    test(
      'getDeletedTrips returns recoverable rows newest deletion first',
      () async {
        final older = _newTrip(
          id: 'trash-older',
          deletedAt: now.subtract(const Duration(days: 2)),
        );
        final newer = _newTrip(
          id: 'trash-newer',
          deletedAt: now.subtract(const Duration(days: 1)),
        );
        final anotherUser = _newTrip(
          id: 'trash-another-user',
          userId: 'another-user',
          deletedAt: now.subtract(const Duration(hours: 1)),
        );
        await repository.addTrip(older);
        await repository.addTrip(newer);
        await repository.addTrip(anotherUser);

        final deleted = await repository.getDeletedTrips(kMockUserId);

        expect(deleted.map((trip) => trip.id), ['trash-newer', 'trash-older']);
        expect(
          (await repository.getTrips(kMockUserId)).map((trip) => trip.id),
          isNot(contains(anyOf('trash-newer', 'trash-older'))),
        );
      },
    );

    test(
      'restoreTrip replaces the row, clears deletedAt, and makes it active',
      () async {
        final trashed = _newTrip(
          id: 'trash-restored',
          deletedAt: now.subtract(const Duration(days: 1)),
        );
        await repository.addTrip(trashed);

        await repository.restoreTrip(trashed.copyWith(title: 'Restored Trip'));

        final restored = await repository.getTrip(trashed.id);
        expect(restored?.title, 'Restored Trip');
        expect(restored?.deletedAt, isNull);
        expect(
          (await repository.getTrips(kMockUserId)).map((trip) => trip.id),
          contains(trashed.id),
        );
        expect(
          (await repository.getDeletedTrips(
            kMockUserId,
          )).map((trip) => trip.id),
          isNot(contains(trashed.id)),
        );
      },
    );

    test(
      'getDeletedTrips excludes the exact 30-day recovery boundary',
      () async {
        final justRecoverable = _newTrip(
          id: 'trash-just-recoverable',
          deletedAt: now.subtract(const Duration(days: 30, microseconds: -1)),
        );
        final expiredAtBoundary = _newTrip(
          id: 'trash-expired',
          deletedAt: now.subtract(const Duration(days: 30)),
        );
        await repository.addTrip(justRecoverable);
        await repository.addTrip(expiredAtBoundary);

        final deleted = await repository.getDeletedTrips(kMockUserId);

        expect(
          deleted.map((trip) => trip.id),
          contains('trash-just-recoverable'),
        );
        expect(
          deleted.map((trip) => trip.id),
          isNot(contains('trash-expired')),
        );
      },
    );
  });
}
