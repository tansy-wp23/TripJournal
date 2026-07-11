import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/trip_overlap.dart';
import 'package:tripjournal/models/trip.dart';

Trip _trip({
  String id = 't',
  DateTime? start,
  DateTime? end,
}) {
  final s = start ?? DateTime(2026, 4, 10);
  final e = end ?? DateTime(2026, 4, 12);
  return Trip(
    id: id,
    userId: 'user-001',
    title: 'title-$id',
    startDate: s,
    endDate: e,
    createdAt: s,
    updatedAt: s,
  );
}

void main() {
  group('Trip.overlapsWith', () {
    test('exact same dates overlap', () {
      final a = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 12));
      final b = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 12));
      expect(a.overlapsWith(b), isTrue);
    });

    test('partial overlap — b starts inside a', () {
      final a = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 15));
      final b = _trip(start: DateTime(2026, 4, 13), end: DateTime(2026, 4, 20));
      expect(a.overlapsWith(b), isTrue);
      expect(b.overlapsWith(a), isTrue); // symmetric
    });

    test('envelope — one trip fully contains the other', () {
      final outer = _trip(start: DateTime(2026, 4, 1), end: DateTime(2026, 4, 30));
      final inner = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 12));
      expect(outer.overlapsWith(inner), isTrue);
      expect(inner.overlapsWith(outer), isTrue);
    });

    test('touching endpoints DO overlap under the inclusive rule', () {
      // a ends the exact day b starts.
      final a = _trip(start: DateTime(2026, 4, 1), end: DateTime(2026, 4, 10));
      final b = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 15));
      expect(a.overlapsWith(b), isTrue);
      expect(b.overlapsWith(a), isTrue);
    });

    test('a genuine gap between trips does not overlap', () {
      final a = _trip(start: DateTime(2026, 4, 1), end: DateTime(2026, 4, 9));
      final b = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 15));
      expect(a.overlapsWith(b), isFalse);
      expect(b.overlapsWith(a), isFalse);
    });

    test('single-day trips can overlap', () {
      final a = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 10));
      final b = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 10));
      expect(a.overlapsWith(b), isTrue);
    });
  });

  group('findOverlappingTrip', () {
    test('finds the overlapping trip among several non-overlapping ones', () {
      final candidate = _trip(id: 'candidate', start: DateTime(2026, 6, 5), end: DateTime(2026, 6, 10));
      final others = [
        _trip(id: 'a', start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 5)),
        _trip(id: 'b', start: DateTime(2026, 6, 8), end: DateTime(2026, 6, 20)), // overlaps
        _trip(id: 'c', start: DateTime(2026, 12, 1), end: DateTime(2026, 12, 5)),
      ];
      final found = findOverlappingTrip(candidate, others);
      expect(found?.id, 'b');
    });

    test('returns null when nothing overlaps', () {
      final candidate = _trip(id: 'candidate', start: DateTime(2026, 6, 5), end: DateTime(2026, 6, 10));
      final others = [
        _trip(id: 'a', start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 5)),
        _trip(id: 'c', start: DateTime(2026, 12, 1), end: DateTime(2026, 12, 5)),
      ];
      expect(findOverlappingTrip(candidate, others), isNull);
    });

    test('editing a trip to its own current dates does not collide with itself', () {
      final trip = _trip(id: 'trip-x', start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 12));
      // The "existing trips" list, as loaded from the repository, still
      // includes trip-x itself — the caller must exclude it by id.
      final allTrips = [trip, _trip(id: 'other', start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 3))];

      final result = findOverlappingTrip(trip, allTrips, excludingTripId: 'trip-x');
      expect(result, isNull);
    });

    test('excluding self still catches a real overlap against a different trip', () {
      final trip = _trip(id: 'trip-x', start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 12));
      final conflicting = _trip(id: 'trip-y', start: DateTime(2026, 4, 11), end: DateTime(2026, 4, 20));
      final allTrips = [trip, conflicting];

      final result = findOverlappingTrip(trip, allTrips, excludingTripId: 'trip-x');
      expect(result?.id, 'trip-y');
    });
  });
}
