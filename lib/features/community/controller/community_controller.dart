import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/trip_repository.dart';
import '../../../data/trip_repository_locator.dart';
import '../../../models/trip.dart';

class CommunityController extends ChangeNotifier {
  CommunityController(this._tripRepository);

  final TripRepository _tripRepository;

  List<Trip> _trips = [];
  bool _loading = false;
  String? _error;

  List<Trip> get trips => _trips;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadPublicTrips() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _trips = await _tripRepository.getPublicTrips();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Looks up a single trip by ID from the already-loaded public trips.
  /// Returns null if not found (the trip may not be public, or may not exist).
  Trip? findById(String tripId) {
    for (final trip in _trips) {
      if (trip.id == tripId) return trip;
    }
    return null;
  }

  /// Fetches a single public trip by ID directly from the repository.
  /// This is used for the "open by ID" flow where the trip may not be in
  /// the already-loaded list.
  Future<Trip?> fetchPublicTrip(String tripId) async {
    try {
      final trip = await _tripRepository.getTrip(tripId);
      if (trip == null || !trip.isPublic || trip.deletedAt != null) return null;
      return trip;
    } catch (_) {
      return null;
    }
  }
}

final communityControllerProvider =
    ChangeNotifierProvider<CommunityController>(
      (ref) => CommunityController(tripRepository),
    );
