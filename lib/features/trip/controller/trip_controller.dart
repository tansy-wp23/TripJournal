import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/journal_repository.dart';
import '../../../data/repository_locator.dart';
import '../../../data/trip_repository.dart';
import '../../../data/trip_repository_locator.dart';
import '../../../models/trip.dart';
import '../../../validation/trip_validation.dart';
import '../../journal/widgets/format_utils.dart';
import '../trip_overlap.dart';

class TripController extends ChangeNotifier {
  TripController(this._tripRepository, this._journalRepository);

  final TripRepository _tripRepository;
  final JournalRepository _journalRepository;

  String? _userId;
  List<Trip> _trips = [];
  bool _loading = false;
  String? _error;

  List<Trip> get trips => _trips;
  bool get loading => _loading;
  String? get error => _error;

  /// The trip whose date range contains today, or null if none does.
  Trip? get activeTrip {
    final now = DateTime.now();
    for (final trip in _trips) {
      if (trip.isActiveOn(now)) return trip;
    }
    return null;
  }

  Future<void> loadTrips(String userId) async {
    _userId = userId;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _trips = await _tripRepository.getTrips(userId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Validates [trip] against the rules in IMPLEMENTATION_PLAN_VALIDATION.md
  /// (title, date order, overlap with the user's other trips) and returns
  /// the first error message, or null if it's valid. Lives here — not just
  /// in the form — so it holds regardless of how create/edit is triggered.
  /// Reads from the already-loaded [trips] rather than re-querying the
  /// repository, since the form is only ever reached after Home/Trip View
  /// has loaded this user's trips.
  String? _validate(Trip trip, {String? excludingTripId}) {
    final titleError = validateTripTitle(trip.title);
    if (titleError != null) return titleError;

    final dateRangeError = validateTripDateRange(trip.startDate, trip.endDate);
    if (dateRangeError != null) return dateRangeError;

    final overlap = findOverlappingTrip(trip, _trips, excludingTripId: excludingTripId);
    if (overlap != null) {
      return 'You already have a trip during these dates '
          '(${overlap.title}, ${formatDate(overlap.startDate)} - ${formatDate(overlap.endDate)}). '
          'Please choose different dates.';
    }

    return null;
  }

  /// Validates [trip] without persisting anything — lets the UI (e.g. the
  /// notes-only editor) gate a save-confirmation dialog on validity first,
  /// same pattern as JournalController.validate (IMPLEMENTATION_PLAN_UX_
  /// POLISH.md §5). [createTrip]/[editTrip] always re-validate internally
  /// regardless — this is a UX pre-check, never a substitute for that.
  String? validate(Trip trip, {String? excludingTripId}) {
    return _validate(trip, excludingTripId: excludingTripId);
  }

  /// Creates [trip], or returns a validation/save error message without
  /// persisting anything.
  Future<String?> createTrip(Trip trip) async {
    final validationError = _validate(trip);
    if (validationError != null) return validationError;

    _error = null;
    try {
      await _tripRepository.addTrip(trip);
      await _refresh();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error;
    }
  }

  /// Edits [trip], or returns a validation/save error message without
  /// persisting anything. [trip] never collides with its own current dates
  /// — it's excluded from the overlap check by its own id.
  Future<String?> editTrip(Trip trip) async {
    final validationError = _validate(trip, excludingTripId: trip.id);
    if (validationError != null) return validationError;

    _error = null;
    try {
      await _tripRepository.updateTrip(trip);
      await _refresh();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error;
    }
  }

  /// Number of journal entries under [tripId] — for the delete-confirmation
  /// UI ("Delete this trip and its N journal entries?", decision #3 in
  /// IMPLEMENTATION_PLAN_HOMEPAGE.md).
  Future<int> countEntriesForTrip(String tripId) async {
    final entries = await _journalRepository.getEntries(tripId);
    return entries.length;
  }

  /// Deletes the trip and cascade-deletes its journal entries. The
  /// confirmation prompt itself is a UI concern (Phase 6) — by the time this
  /// is called, the user has already confirmed.
  Future<void> deleteTrip(String id) async {
    _error = null;
    try {
      final entries = await _journalRepository.getEntries(id);
      for (final entry in entries) {
        await _journalRepository.deleteEntry(entry.id);
      }
      await _tripRepository.moveToTrash(id);
      await _refresh();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> _refresh() async {
    final userId = _userId;
    if (userId == null) return;
    _trips = await _tripRepository.getTrips(userId);
    notifyListeners();
  }
}

/// The single place the app resolves its [TripController] from — mirrors
/// journalControllerProvider.
final tripControllerProvider = ChangeNotifierProvider<TripController>(
  (ref) => TripController(tripRepository, journalRepository),
);
