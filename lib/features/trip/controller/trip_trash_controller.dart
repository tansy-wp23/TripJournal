import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/current_user_id_provider.dart';
import '../../../data/trip_repository.dart';
import '../../../data/trip_repository_locator.dart';
import '../../../models/trip.dart';
import '../../../validation/trip_validation.dart';
import '../../journal/widgets/format_utils.dart';
import '../trip_overlap.dart';

enum TripRestoreStatus { restored, conflict, expired, failed }

class TripRestoreResult {
  const TripRestoreResult({required this.status, this.conflict, this.message});

  final TripRestoreStatus status;
  final Trip? conflict;
  final String? message;
}

class TripTrashController extends ChangeNotifier {
  TripTrashController(
    this._tripRepository,
    this._currentUserIdProvider, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final TripRepository _tripRepository;
  final CurrentUserIdProvider _currentUserIdProvider;
  final DateTime Function() _clock;

  List<Trip> _trips = const [];
  final Set<String> _restoringTripIds = {};
  bool _loading = false;
  bool _disposed = false;
  int _loadGeneration = 0;
  String? _error;

  List<Trip> get trips => _trips;
  bool get loading => _loading;
  String? get error => _error;
  DateTime get now => _clock();

  bool isRestoring(String tripId) => _restoringTripIds.contains(tripId);

  Future<void> load() async {
    final generation = ++_loadGeneration;
    _loading = true;
    _error = null;
    _notify();

    try {
      final userId = _currentUserIdProvider.requireUserId();
      final loaded = await _tripRepository.getDeletedTrips(userId);
      if (_disposed || generation != _loadGeneration) return;
      _trips = _recoverableNewestFirst(loaded);
    } catch (error) {
      if (_disposed || generation != _loadGeneration) return;
      _error = error.toString();
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<TripRestoreResult> restore(Trip trip) {
    return _restore(trip);
  }

  Future<TripRestoreResult> restoreWithChanges(Trip editedTrip) {
    return _restore(editedTrip);
  }

  Future<TripRestoreResult> _restore(Trip candidate) async {
    if (_restoringTripIds.contains(candidate.id)) {
      return const TripRestoreResult(
        status: TripRestoreStatus.failed,
        message: 'A restore for this trip is already in progress.',
      );
    }

    final titleError = validateTripTitle(candidate.title);
    if (titleError != null) {
      return TripRestoreResult(
        status: TripRestoreStatus.failed,
        message: titleError,
      );
    }
    final rangeError = validateTripDateRange(
      candidate.startDate,
      candidate.endDate,
    );
    if (rangeError != null) {
      return TripRestoreResult(
        status: TripRestoreStatus.failed,
        message: rangeError,
      );
    }
    if (!candidate.isRecoverableAt(_clock())) {
      return const TripRestoreResult(
        status: TripRestoreStatus.expired,
        message: 'This trip\'s recovery period has expired.',
      );
    }

    _restoringTripIds.add(candidate.id);
    _error = null;
    _notify();
    try {
      final userId = _currentUserIdProvider.requireUserId();
      if (candidate.userId != userId) {
        return const TripRestoreResult(
          status: TripRestoreStatus.failed,
          message: 'This trip does not belong to the current user.',
        );
      }

      final activeTrips = await _tripRepository.getTrips(userId);
      final conflict = findOverlappingTrip(
        candidate,
        activeTrips,
        excludingTripId: candidate.id,
      );
      if (conflict != null) return _conflictResult(conflict);

      try {
        await _tripRepository.restoreTrip(candidate);
      } catch (error) {
        if (!candidate.isRecoverableAt(_clock()) ||
            error.toString().contains('trip_restore_expired')) {
          return const TripRestoreResult(
            status: TripRestoreStatus.expired,
            message: 'This trip\'s recovery period has expired.',
          );
        }
        if (error.toString().contains('trip_restore_overlap')) {
          final latestActiveTrips = await _tripRepository.getTrips(userId);
          final latestConflict = findOverlappingTrip(
            candidate,
            latestActiveTrips,
            excludingTripId: candidate.id,
          );
          if (latestConflict != null) return _conflictResult(latestConflict);
        }
        return TripRestoreResult(
          status: TripRestoreStatus.failed,
          message: error.toString(),
        );
      }

      // Invalidate any older load that captured this row before the restore.
      // Its eventual response must not reinsert the successfully restored trip.
      final refreshGeneration = ++_loadGeneration;
      _loading = false;
      _trips = _trips
          .where((deletedTrip) => deletedTrip.id != candidate.id)
          .toList();
      _notify();

      try {
        final loaded = await _tripRepository.getDeletedTrips(userId);
        if (!_disposed && refreshGeneration == _loadGeneration) {
          _trips = _recoverableNewestFirst(
            loaded.where((trip) => trip.id != candidate.id),
          );
          _notify();
        }
      } catch (error) {
        return TripRestoreResult(
          status: TripRestoreStatus.restored,
          message:
              'Trip restored, but Recently Deleted could not refresh: $error',
        );
      }

      return const TripRestoreResult(status: TripRestoreStatus.restored);
    } catch (error) {
      return TripRestoreResult(
        status: TripRestoreStatus.failed,
        message: error.toString(),
      );
    } finally {
      _restoringTripIds.remove(candidate.id);
      _notify();
    }
  }

  TripRestoreResult _conflictResult(Trip conflict) {
    return TripRestoreResult(
      status: TripRestoreStatus.conflict,
      conflict: conflict,
      message:
          'You already have a trip during these dates '
          '(${conflict.title}, ${formatDate(conflict.startDate)} - '
          '${formatDate(conflict.endDate)}). Please choose different dates.',
    );
  }

  List<Trip> _recoverableNewestFirst(Iterable<Trip> trips) {
    final recoverable = trips
        .where((trip) => trip.isRecoverableAt(_clock()))
        .toList();
    recoverable.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return recoverable;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final tripTrashControllerProvider = ChangeNotifierProvider<TripTrashController>(
  (ref) => TripTrashController(tripRepository, currentUserIdProvider),
);
