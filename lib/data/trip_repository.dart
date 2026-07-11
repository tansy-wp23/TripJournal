import '../models/trip.dart';

abstract class TripRepository {
  Future<List<Trip>> getTrips(String userId);
  Future<Trip?> getTrip(String id);
  Future<void> addTrip(Trip trip);
  Future<void> updateTrip(Trip trip);
  Future<void> deleteTrip(String id);
}
