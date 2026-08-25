import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/data/mock_trip_cover_storage.dart';
import 'package:tripjournal/data/mock_trip_repository.dart';
import 'package:tripjournal/features/trip/controller/trip_controller.dart';
import 'package:tripjournal/features/trip/mock_user.dart';

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

  test(
    'publishTrip marks the trip public and snapshots the publisher identity',
    () async {
      final trip = controller.trips.firstWhere((t) => t.id == 'trip-001');

      final error = await controller.publishTrip(
        trip,
        publisherDisplayName: 'Alice',
        publisherAvatarUrl: 'https://example.com/avatar.png',
      );

      expect(error, isNull);
      final updated = controller.trips.firstWhere((t) => t.id == 'trip-001');
      expect(updated.isPublic, isTrue);
      expect(updated.publishedAt, isNotNull);
      expect(updated.publisherDisplayName, 'Alice');
      expect(updated.publisherAvatarUrl, 'https://example.com/avatar.png');
    },
  );

  test(
    'unpublishTrip clears isPublic and the publisher identity snapshot',
    () async {
      final trip = controller.trips.firstWhere((t) => t.id == 'trip-001');
      await controller.publishTrip(trip, publisherDisplayName: 'Alice');
      final published = controller.trips.firstWhere((t) => t.id == 'trip-001');

      final error = await controller.unpublishTrip(published);

      expect(error, isNull);
      final updated = controller.trips.firstWhere((t) => t.id == 'trip-001');
      expect(updated.isPublic, isFalse);
      expect(updated.publishedAt, isNull);
      expect(updated.publisherDisplayName, isNull);
      expect(updated.publisherAvatarUrl, isNull);
    },
  );
}
