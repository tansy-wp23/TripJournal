import '../../models/trip.dart';

/// Returns the first trip in [existingTrips] whose dates overlap
/// [candidate]'s, or null if none do.
///
/// Pass [excludingTripId] (the trip being edited, if any) so a trip never
/// collides with its own current dates — editing a trip to the same dates
/// it already has must not be rejected as an overlap with itself. Overlaps
/// are disallowed entirely (decision in
/// IMPLEMENTATION_PLAN_ENHANCEMENTS.md §6), which is what keeps
/// [TripController.activeTrip] provably unique.
Trip? findOverlappingTrip(Trip candidate, List<Trip> existingTrips, {String? excludingTripId}) {
  for (final other in existingTrips) {
    if (other.id == excludingTripId) continue;
    if (candidate.overlapsWith(other)) return other;
  }
  return null;
}
