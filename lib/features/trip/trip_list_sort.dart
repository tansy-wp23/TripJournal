import '../../models/trip.dart';

/// Sort options for the home-screen trip list
/// (IMPLEMENTATION_PLAN_EXTRA_FEATURES.md #3). [defaultOrder] reproduces the
/// original grouped ordering (active, then upcoming soonest-first, then past
/// most-recent-first) — never mutates or persists trip data, view-only.
enum TripSortOption { defaultOrder, startDateNewest, startDateOldest, titleAZ }

/// Upcoming/Active/Past filter, derived from each trip's date range vs
/// [DateTime.now] — the same predicates the home screen already used before
/// this feature existed.
enum TripStatusFilter { all, active, upcoming, past }

/// Pure — no I/O, trivial to unit test. [now] defaults to [DateTime.now]
/// and exists only so tests can pin "today".
List<Trip> sortAndFilterTrips(
  List<Trip> trips, {
  required TripSortOption sort,
  required TripStatusFilter statusFilter,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final active = trips.where((t) => t.isActiveOn(today)).toList();
  final upcoming =
      trips
          .where((t) => !t.isActiveOn(today) && t.startDate.isAfter(today))
          .toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
  final past =
      trips
          .where((t) => !t.isActiveOn(today) && t.endDate.isBefore(today))
          .toList()
        ..sort((a, b) => b.endDate.compareTo(a.endDate));

  final byStatus = switch (statusFilter) {
    TripStatusFilter.all => [...active, ...upcoming, ...past],
    TripStatusFilter.active => active,
    TripStatusFilter.upcoming => upcoming,
    TripStatusFilter.past => past,
  };

  if (sort == TripSortOption.defaultOrder) return byStatus;

  final sorted = [...byStatus];
  switch (sort) {
    case TripSortOption.startDateNewest:
      sorted.sort((a, b) => b.startDate.compareTo(a.startDate));
    case TripSortOption.startDateOldest:
      sorted.sort((a, b) => a.startDate.compareTo(b.startDate));
    case TripSortOption.titleAZ:
      sorted.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    case TripSortOption.defaultOrder:
      break;
  }
  return sorted;
}
