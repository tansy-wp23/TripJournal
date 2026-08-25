import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_trip_repository.dart';
import 'package:tripjournal/data/trip_repository.dart';
import 'package:tripjournal/features/community/controller/community_controller.dart';
import 'package:tripjournal/features/trip/mock_user.dart';
import 'package:tripjournal/models/trip.dart';

Trip _publicTrip({required String id, DateTime? publishedAt}) {
  final now = DateTime.utc(2026, 8, 5, 12);
  return Trip(
    id: id,
    userId: kMockUserId,
    title: 'Public Trip $id',
    startDate: now,
    endDate: now,
    createdAt: now,
    updatedAt: now,
    isPublic: true,
    publishedAt: publishedAt ?? now,
    publisherDisplayName: 'Alice',
  );
}

void main() {
  late MockTripRepository tripRepository;
  late CommunityController controller;

  setUp(() {
    tripRepository = MockTripRepository();
    controller = CommunityController(tripRepository);
  });

  test('loadPublicTrips populates trips from the repository', () async {
    await tripRepository.addTrip(_publicTrip(id: 'public-1'));

    await controller.loadPublicTrips();

    expect(controller.loading, isFalse);
    expect(controller.error, isNull);
    expect(controller.trips.map((t) => t.id), contains('public-1'));
  });

  test('loadPublicTrips surfaces a repository error', () async {
    final failing = _FailingTripRepository();
    final failingController = CommunityController(failing);

    await failingController.loadPublicTrips();

    expect(failingController.loading, isFalse);
    expect(failingController.error, isNotNull);
    expect(failingController.trips, isEmpty);
  });

  test('findById looks up an already-loaded public trip', () async {
    await tripRepository.addTrip(_publicTrip(id: 'public-1'));
    await controller.loadPublicTrips();

    expect(controller.findById('public-1')?.id, 'public-1');
    expect(controller.findById('does-not-exist'), isNull);
  });

  group('fetchPublicTrip', () {
    test('returns the trip when it is public and not deleted', () async {
      await tripRepository.addTrip(_publicTrip(id: 'public-1'));

      final trip = await controller.fetchPublicTrip('public-1');

      expect(trip?.id, 'public-1');
    });

    test('returns null when the trip is private', () async {
      final now = DateTime.utc(2026, 8, 5, 12);
      await tripRepository.addTrip(
        Trip(
          id: 'private-1',
          userId: kMockUserId,
          title: 'Private Trip',
          startDate: now,
          endDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(await controller.fetchPublicTrip('private-1'), isNull);
    });

    test('returns null when the trip does not exist', () async {
      expect(await controller.fetchPublicTrip('does-not-exist'), isNull);
    });
  });
}

class _FailingTripRepository implements TripRepository {
  @override
  Future<List<Trip>> getPublicTrips() async {
    throw StateError('boom');
  }

  @override
  Future<Trip?> getTrip(String id) async => null;

  @override
  Future<List<Trip>> getTrips(String userId) async => const [];

  @override
  Future<List<Trip>> getDeletedTrips(String userId) async => const [];

  @override
  Future<void> addTrip(Trip trip) async {}

  @override
  Future<void> updateTrip(Trip trip) async {}

  @override
  Future<void> moveToTrash(String id) async {}

  @override
  Future<void> restoreTrip(Trip trip) async {}
}
