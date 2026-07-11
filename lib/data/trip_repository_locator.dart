import 'mock_trip_repository.dart';
import 'trip_repository.dart';

/// The one place the app resolves its [TripRepository] from — mirrors
/// `repository_locator.dart` so the phase-6 swap to Supabase (or to the
/// teammate's real Trip Management module) is a one-line change here.
final TripRepository tripRepository = MockTripRepository();
