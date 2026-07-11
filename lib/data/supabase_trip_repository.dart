import '../models/trip.dart';
import 'trip_repository.dart';

// TODO(phase6): implement against a Supabase `trips` table, then swap the
// locator in trip_repository_locator.dart from MockTripRepository to this
// class.
class SupabaseTripRepository implements TripRepository {
  @override
  Future<List<Trip>> getTrips(String userId) async {
    throw UnimplementedError();
  }

  @override
  Future<Trip?> getTrip(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<void> addTrip(Trip trip) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTrip(String id) async {
    throw UnimplementedError();
  }
}
