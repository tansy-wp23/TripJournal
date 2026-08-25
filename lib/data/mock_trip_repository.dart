import '../features/trip/mock_user.dart';
import '../models/trip.dart';
import 'trip_repository.dart';

class MockTripRepository implements TripRepository {
  MockTripRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final List<Trip> _trips = _seedTrips();

  @override
  Future<List<Trip>> getTrips(String userId) async {
    return _trips
        .where((trip) => trip.userId == userId && trip.deletedAt == null)
        .toList();
  }

  @override
  Future<List<Trip>> getDeletedTrips(String userId) async {
    final now = _clock();
    final deletedTrips = _trips
        .where(
          (trip) =>
              trip.userId == userId &&
              trip.deletedAt != null &&
              trip.isRecoverableAt(now),
        )
        .toList();
    deletedTrips.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return deletedTrips;
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
  Future<void> moveToTrash(String id) async {
    final index = _trips.indexWhere((trip) => trip.id == id);
    if (index != -1) {
      _trips[index] = _trips[index].copyWith(deletedAt: _clock().toUtc());
    }
  }

  @override
  Future<void> restoreTrip(Trip trip) async {
    final index = _trips.indexWhere((storedTrip) => storedTrip.id == trip.id);
    if (index != -1) {
      _trips[index] = trip.copyWith(clearDeletedAt: true);
    }
  }

  @override
  Future<List<Trip>> getPublicTrips() async {
    return _trips.where((trip) => trip.isPublic && trip.deletedAt == null).toList()
      ..sort(
        (a, b) =>
            (b.publishedAt ?? b.createdAt).compareTo(a.publishedAt ?? a.createdAt),
      );
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
        destination: 'Kyoto, Japan',
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
        destination: 'Osaka, Japan',
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
        destination: 'Taipei, Taiwan',
        startDate: today.add(const Duration(days: 30)),
        endDate: today.add(const Duration(days: 34)),
        notes: 'Pack rain jacket. Book airport shuttle. Exchange currency.',
        createdAt: today,
        updatedAt: today,
      ),
    ];
  }
}
