import '../../models/trip.dart';

/// Filters [trips] to those whose destination contains [query]
/// (case-insensitive, substring match). Mirrors `sortAndFilterTrips`'s query
/// handling in `trip_list_sort.dart`. An empty/whitespace-only query returns
/// [trips] unchanged; a trip with no destination never matches a non-empty
/// query.
List<Trip> filterPublicTripsByDestination(List<Trip> trips, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return trips;
  return trips
      .where(
        (trip) => trip.destination?.toLowerCase().contains(normalized) ?? false,
      )
      .toList();
}
