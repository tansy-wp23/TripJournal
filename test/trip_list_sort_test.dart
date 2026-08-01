import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/trip_list_sort.dart';
import 'package:tripjournal/models/trip.dart';

Trip _trip({required String id, required String title, required DateTime start, required DateTime end}) {
  return Trip(id: id, userId: 'u', title: title, startDate: start, endDate: end, createdAt: start, updatedAt: start);
}

void main() {
  final now = DateTime(2026, 6, 15);

  // Active: spans "now". Upcoming: starts after "now". Past: ends before "now".
  final active = _trip(id: 'active', title: 'Zermatt', start: DateTime(2026, 6, 10), end: DateTime(2026, 6, 20));
  final upcomingNear = _trip(
    id: 'upcoming-near',
    title: 'Bali',
    start: DateTime(2026, 7, 1),
    end: DateTime(2026, 7, 5),
  );
  final upcomingFar = _trip(
    id: 'upcoming-far',
    title: 'Anchorage',
    start: DateTime(2026, 9, 1),
    end: DateTime(2026, 9, 5),
  );
  final pastRecent = _trip(
    id: 'past-recent',
    title: 'Kyoto',
    start: DateTime(2026, 5, 1),
    end: DateTime(2026, 5, 10),
  );
  final pastOld = _trip(id: 'past-old', title: 'Osaka', start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 5));

  final trips = [pastOld, upcomingFar, active, pastRecent, upcomingNear];

  group('sortAndFilterTrips', () {
    test('defaultOrder + all reproduces active, then upcoming soonest-first, then past newest-first', () {
      final result = sortAndFilterTrips(
        trips,
        sort: TripSortOption.defaultOrder,
        statusFilter: TripStatusFilter.all,
        now: now,
      );
      expect(result.map((t) => t.id), ['active', 'upcoming-near', 'upcoming-far', 'past-recent', 'past-old']);
    });

    test('statusFilter narrows to just that bucket', () {
      expect(
        sortAndFilterTrips(trips, sort: TripSortOption.defaultOrder, statusFilter: TripStatusFilter.active, now: now)
            .map((t) => t.id),
        ['active'],
      );
      expect(
        sortAndFilterTrips(
          trips,
          sort: TripSortOption.defaultOrder,
          statusFilter: TripStatusFilter.upcoming,
          now: now,
        ).map((t) => t.id),
        ['upcoming-near', 'upcoming-far'],
      );
      expect(
        sortAndFilterTrips(trips, sort: TripSortOption.defaultOrder, statusFilter: TripStatusFilter.past, now: now)
            .map((t) => t.id),
        ['past-recent', 'past-old'],
      );
    });

    test('startDateNewest sorts every visible trip by start date descending', () {
      final result = sortAndFilterTrips(
        trips,
        sort: TripSortOption.startDateNewest,
        statusFilter: TripStatusFilter.all,
        now: now,
      );
      expect(result.map((t) => t.id), ['upcoming-far', 'upcoming-near', 'active', 'past-recent', 'past-old']);
    });

    test('startDateOldest sorts every visible trip by start date ascending', () {
      final result = sortAndFilterTrips(
        trips,
        sort: TripSortOption.startDateOldest,
        statusFilter: TripStatusFilter.all,
        now: now,
      );
      expect(result.map((t) => t.id), ['past-old', 'past-recent', 'active', 'upcoming-near', 'upcoming-far']);
    });

    test('titleAZ sorts alphabetically, case-insensitively', () {
      final result = sortAndFilterTrips(
        trips,
        sort: TripSortOption.titleAZ,
        statusFilter: TripStatusFilter.all,
        now: now,
      );
      expect(result.map((t) => t.title), ['Anchorage', 'Bali', 'Kyoto', 'Osaka', 'Zermatt']);
    });

    test('sort applies within a narrowed status filter too', () {
      final result = sortAndFilterTrips(
        trips,
        sort: TripSortOption.titleAZ,
        statusFilter: TripStatusFilter.upcoming,
        now: now,
      );
      expect(result.map((t) => t.title), ['Anchorage', 'Bali']);
    });

    test('an empty trip list produces an empty result regardless of options', () {
      expect(
        sortAndFilterTrips(const [], sort: TripSortOption.titleAZ, statusFilter: TripStatusFilter.all, now: now),
        isEmpty,
      );
    });
  });
}
