import '../models/trip.dart';

abstract class TripRepository {
  Future<List<Trip>> getTrips(String userId);
  Future<List<Trip>> getDeletedTrips(String userId);
  Future<Trip?> getTrip(String id);
  Future<void> addTrip(Trip trip);
  Future<void> updateTrip(Trip trip);
  Future<void> moveToTrash(String id);
  Future<void> restoreTrip(Trip trip);
  Future<List<Trip>> getPublicTrips();
}
