import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/community/public_trip_search.dart';
import 'package:tripjournal/models/trip.dart';

Trip _trip(String id, {String? destination}) {
  final now = DateTime.utc(2026, 8, 5, 12);
  return Trip(
    id: id,
    userId: 'user-1',
    title: 'Trip $id',
    destination: destination,
    startDate: now,
    endDate: now,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('filterPublicTripsByDestination', () {
    test('empty query returns every trip unchanged', () {
      final trips = [_trip('a', destination: 'Kyoto'), _trip('b')];
      expect(filterPublicTripsByDestination(trips, ''), trips);
    });

    test('whitespace-only query returns every trip unchanged', () {
      final trips = [_trip('a', destination: 'Kyoto')];
      expect(filterPublicTripsByDestination(trips, '   '), trips);
    });

    test('matches a destination substring case-insensitively', () {
      final kyoto = _trip('a', destination: 'Kyoto, Japan');
      final melaka = _trip('b', destination: 'Melaka, Malaysia');

      final result = filterPublicTripsByDestination([kyoto, melaka], 'KYOTO');

      expect(result, [kyoto]);
    });

    test('a trip with no destination never matches a non-empty query', () {
      final noDestination = _trip('a');

      expect(filterPublicTripsByDestination([noDestination], 'kyoto'), isEmpty);
    });

    test('returns an empty list when nothing matches', () {
      final trips = [_trip('a', destination: 'Kyoto')];
      expect(filterPublicTripsByDestination(trips, 'nowhere'), isEmpty);
    });
  });
}
