import '../features/trip/mock_user.dart';
import '../models/trip.dart';
import 'trip_repository.dart';

class MockTripRepository implements TripRepository {
  final List<Trip> _trips = _seedTrips();

  @override
  Future<List<Trip>> getTrips(String userId) async {
    return _trips.where((t) => t.userId == userId).toList();
  }

  @override
  Future<Trip?> getTrip(String id) async {
    try {
      return _trips.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addTrip(Trip trip) async {
    _trips.add(trip);
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    final index = _trips.indexWhere((t) => t.id == trip.id);
    if (index != -1) {
      _trips[index] = trip;
    }
  }

  @override
  Future<void> deleteTrip(String id) async {
    _trips.removeWhere((t) => t.id == id);
  }

  static List<Trip> _seedTrips() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return [
      // trip-001 — ACTIVE. Spans the existing seeded Kyoto journal entries
      // (entry-1..3, dated April 2026) through a couple of days past today,
      // so `isActiveOn(today)` is always true and the timeline shows those
      // filled days plus a run of empty days up to (and just past) today.
      Trip(
        id: 'trip-001',
        userId: kMockUserId,
        title: 'Kyoto Trip',
        coverPhotoPath: 'assets/mock/kyoto_arrival_1.jpg',
        startDate: DateTime(2026, 4, 10),
        endDate: today.add(const Duration(days: 2)),
        notes: 'Renew rail pass before boarding. Confirm ryokan check-in time.',
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      ),
      // trip-002 — PAST. Matches the existing Osaka journal entry (entry-4,
      // dated March 20 2026), already behind `today`. Deliberately placed
      // *before* trip-001 starts (April 10): trip-001 must span from its
      // April entries through today to stay ACTIVE, so any trip-002 dates
      // inside that window would structurally violate the no-overlap rule
      // added in IMPLEMENTATION_PLAN_ENHANCEMENTS.md §6 — the two seeded
      // trips must never overlap either.
      Trip(
        id: 'trip-002',
        userId: kMockUserId,
        title: 'Osaka Trip',
        coverPhotoPath: 'assets/mock/dotonbori_night.jpg',
        startDate: DateTime(2026, 3, 20),
        endDate: DateTime(2026, 3, 21),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      ),
      // trip-003 — UPCOMING. No journal entries yet (future days aren't
      // writable) — demonstrates the trip-level Notes/Reminders field.
      Trip(
        id: 'trip-003',
        userId: kMockUserId,
        title: 'Taipei Trip',
        startDate: today.add(const Duration(days: 30)),
        endDate: today.add(const Duration(days: 34)),
        notes: 'Pack rain jacket. Book airport shuttle. Exchange currency.',
        createdAt: today,
        updatedAt: today,
      ),
    ];
  }
}
