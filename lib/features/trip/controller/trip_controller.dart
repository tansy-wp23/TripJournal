import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/journal_repository.dart';
import '../../../data/repository_locator.dart';
import '../../../data/trip_cover_storage.dart';
import '../../../data/trip_repository.dart';
import '../../../data/trip_repository_locator.dart';
import '../../../models/journal_entry.dart';
import '../../../models/trip.dart';
import '../../../validation/trip_validation.dart';
import '../../journal/widgets/format_utils.dart';
import '../trip_overlap.dart';
import '../trip_entry_date_range.dart';

class TripController extends ChangeNotifier {
  TripController(
    this._tripRepository,
    this._journalRepository,
    this._tripCoverStorage,
  );

  final TripRepository _tripRepository;
  final JournalRepository _journalRepository;
  final TripCoverStorage _tripCoverStorage;

  String? _userId;
  int _loadGeneration = 0;
  List<Trip> _trips = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _cleanupWarning;
  String? _refreshWarning;

  List<Trip> get trips => _trips;
  String? get loadedUserId => _userId;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;
  String? get cleanupWarning => _cleanupWarning;
  String? get refreshWarning => _refreshWarning;

  void clearCleanupWarning() {
    if (_cleanupWarning == null) return;
    _cleanupWarning = null;
    notifyListeners();
  }

  void clearRefreshWarning() {
    if (_refreshWarning == null) return;
    _refreshWarning = null;
    notifyListeners();
  }

  /// The trip whose date range contains today, or null if none does.
  Trip? get activeTrip {
    final now = DateTime.now();
    for (final trip in _trips) {
      if (trip.isActiveOn(now)) return trip;
    }
    return null;
  }

  Future<void> loadTrips(String userId) async {
    final generation = ++_loadGeneration;
    final switchingUser = _userId != userId;
    if (switchingUser) {
      _userId = null;
      _trips = [];
    }
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final trips = await _tripRepository.getTrips(userId);
      if (generation != _loadGeneration) return;
      _trips = trips;
      _userId = userId;
      _refreshWarning = null;
    } catch (e) {
      if (generation != _loadGeneration) return;
      _error = e.toString();
    } finally {
      if (generation == _loadGeneration) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void clearLoadedTrips() {
    _loadGeneration++;
    _userId = null;
    _trips = [];
    _loading = false;
    _error = null;
    _refreshWarning = null;
    notifyListeners();
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

    final overlap = findOverlappingTrip(
      trip,
      _trips,
      excludingTripId: excludingTripId,
    );
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
  Future<String?> createTrip(Trip trip, {TripCoverDraft? coverDraft}) async {
    final validationError = _validate(trip);
    if (validationError != null) return validationError;
    if (_saving) return 'A trip save is already in progress.';

    _saving = true;
    notifyListeners();
    try {
      _error = null;
      _cleanupWarning = null;
      _refreshWarning = null;
      String? uploadedCoverUrl;
      var tripToPersist = trip;
      try {
        final pendingCover = _pendingCoverDraft(trip, coverDraft);
        if (pendingCover != null) {
          uploadedCoverUrl = await _tripCoverStorage.uploadCover(
            userId: trip.userId,
            tripId: trip.id,
            cover: pendingCover,
          );
          tripToPersist = _copyWithCover(trip, uploadedCoverUrl);
        }
        await _tripRepository.addTrip(tripToPersist);
      } catch (e) {
        if (uploadedCoverUrl != null) {
          await _cleanupCover(uploadedCoverUrl);
        }
        _error = e.toString();
        notifyListeners();
        return _error;
      }

      if (_userId != tripToPersist.userId) {
        _trips = [tripToPersist];
      } else {
        _trips = [..._trips, tripToPersist];
      }
      _userId = tripToPersist.userId;
      notifyListeners();
      await _refreshAfterMutation();
      return null;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Edits [trip], or returns a validation/save error message without
  /// persisting anything. [trip] never collides with its own current dates
  /// — it's excluded from the overlap check by its own id.
  Future<String?> editTrip(Trip trip, {TripCoverDraft? coverDraft}) async {
    final validationError = _validate(trip, excludingTripId: trip.id);
    if (validationError != null) return validationError;
    if (_saving) return 'A trip save is already in progress.';

    _saving = true;
    notifyListeners();
    try {
      _error = null;
      _cleanupWarning = null;
      _refreshWarning = null;
      final existingTrip = _tripForId(trip.id);
      if (existingTrip != null && _datesChanged(existingTrip, trip)) {
        late final List<JournalEntry> existingEntries;
        try {
          existingEntries = await _journalRepository.getEntries(trip.id);
        } catch (e) {
          _error = e.toString();
          notifyListeners();
          return _error;
        }
        if (existingEntries.any((entry) => !isEntryWithinTrip(trip, entry))) {
          return 'Trip dates must include all existing journal entries.';
        }
      }
      final previousCover = _coverForTrip(trip.id);
      String? uploadedCoverUrl;
      var tripToPersist = trip;
      try {
        final pendingCover = _pendingCoverDraft(trip, coverDraft);
        if (pendingCover != null) {
          uploadedCoverUrl = await _tripCoverStorage.uploadCover(
            userId: trip.userId,
            tripId: trip.id,
            cover: pendingCover,
          );
          tripToPersist = _copyWithCover(trip, uploadedCoverUrl);
        }
        await _tripRepository.updateTrip(tripToPersist);
      } catch (e) {
        if (uploadedCoverUrl != null && uploadedCoverUrl != previousCover) {
          await _cleanupCover(uploadedCoverUrl);
        }
        _error = e.toString();
        notifyListeners();
        return _error;
      }

      if (_userId != tripToPersist.userId) {
        _trips = [];
      }
      _userId = tripToPersist.userId;
      final index = _trips.indexWhere(
        (candidate) => candidate.id == tripToPersist.id,
      );
      if (index == -1) {
        _trips = [..._trips, tripToPersist];
      } else {
        _trips = [..._trips]..[index] = tripToPersist;
      }
      notifyListeners();

      if (_isRemoteCover(previousCover) &&
          previousCover != tripToPersist.coverPhotoPath) {
        await _cleanupCover(previousCover);
      }

      await _refreshAfterMutation();
      return null;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Number of journal entries under [tripId] for dashboard statistics.
  Future<int> countEntriesForTrip(String tripId) async {
    final entries = await _journalRepository.getEntries(tripId);
    return entries.length;
  }

  /// Moves the trip to recoverable trash without touching journal entries.
  Future<String?> moveToTrash(String id) async {
    _error = null;
    _refreshWarning = null;
    try {
      await _tripRepository.moveToTrash(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error;
    }

    _trips = _trips.where((trip) => trip.id != id).toList();
    notifyListeners();
    await _refreshAfterMutation();
    return null;
  }

  /// Marks [trip] as public and snapshots the publisher's identity.
  Future<String?> publishTrip(
    Trip trip, {
    required String publisherDisplayName,
    String? publisherAvatarUrl,
  }) async {
    final publishedTrip = trip.copyWith(
      isPublic: true,
      publishedAt: DateTime.now(),
      publisherDisplayName: publisherDisplayName,
      publisherAvatarUrl: publisherAvatarUrl,
      updatedAt: DateTime.now(),
    );
    return editTrip(publishedTrip);
  }

  /// Marks [trip] as private (removes it from the community feed).
  Future<String?> unpublishTrip(Trip trip) async {
    final unpublishedTrip = trip.copyWith(
      isPublic: false,
      clearPublishedAt: true,
      clearPublisherDisplayName: true,
      clearPublisherAvatarUrl: true,
      updatedAt: DateTime.now(),
    );
    return editTrip(unpublishedTrip);
  }

  String? _coverForTrip(String tripId) {
    for (final trip in _trips) {
      if (trip.id == tripId) return trip.coverPhotoPath;
    }
    return null;
  }

  Trip? _tripForId(String tripId) {
    for (final trip in _trips) {
      if (trip.id == tripId) return trip;
    }
    return null;
  }

  bool _datesChanged(Trip before, Trip after) =>
      !_sameLocalDate(before.startDate, after.startDate) ||
      !_sameLocalDate(before.endDate, after.endDate);

  bool _sameLocalDate(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  bool _isRemoteCover(String? cover) {
    if (cover == null) return false;
    final scheme = Uri.tryParse(cover)?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https' || scheme == 'mock-cover';
  }

  bool _isLocalCover(String? cover) => cover != null && !_isRemoteCover(cover);

  TripCoverDraft? _pendingCoverDraft(Trip trip, TripCoverDraft? selectedCover) {
    if (selectedCover != null) return selectedCover;
    final localPath = trip.coverPhotoPath;
    return _isLocalCover(localPath)
        ? TripCoverDraft.fromPath(localPath!)
        : null;
  }

  Trip _copyWithCover(Trip trip, String? coverPhotoPath) {
    return Trip(
      id: trip.id,
      userId: trip.userId,
      title: trip.title,
      destination: trip.destination,
      coverPhotoPath: coverPhotoPath,
      startDate: trip.startDate,
      endDate: trip.endDate,
      notes: trip.notes,
      summary: trip.summary,
      createdAt: trip.createdAt,
      updatedAt: trip.updatedAt,
      deletedAt: trip.deletedAt,
      isPublic: trip.isPublic,
      publishedAt: trip.publishedAt,
      publisherDisplayName: trip.publisherDisplayName,
      publisherAvatarUrl: trip.publisherAvatarUrl,
    );
  }

  Future<void> _cleanupCover(String? coverUrl) async {
    try {
      await _tripCoverStorage.deleteCoverUrl(coverUrl);
    } catch (e) {
      _cleanupWarning = e.toString();
      notifyListeners();
    }
  }

  Future<void> _refreshAfterMutation() async {
    try {
      await _refresh();
      _refreshWarning = null;
    } catch (e) {
      _refreshWarning = e.toString();
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
  (ref) => TripController(tripRepository, journalRepository, tripCoverStorage),
);
