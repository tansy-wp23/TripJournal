import '../../models/trip.dart';
import 'journal_reminder_service.dart';
import 'settings_controller.dart';

class JournalReminderCoordinator {
  JournalReminderCoordinator(
    this._service,
    this._settings, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final JournalReminderService _service;
  final SettingsController _settings;
  final DateTime Function() _clock;
  List<Trip>? _pendingTrips;
  Future<void>? _drainInProgress;

  Future<void> reconcile(List<Trip> trips) async {
    _pendingTrips = List.unmodifiable(trips);
    while (true) {
      final active = _drainInProgress ??= _drain();
      await active;
      if (identical(_drainInProgress, active)) {
        _drainInProgress = null;
      }
      if (_pendingTrips == null) return;
    }
  }

  Future<void> _drain() async {
    await _settings.load();
    while (_pendingTrips != null) {
      final trips = _pendingTrips!;
      _pendingTrips = null;
      final preferences = _settings.preferences;
      if (!preferences.journalReminderEnabled) {
        await _service.cancelAll();
      } else {
        await _service.replaceScheduled(planJournalReminders(
          trips: trips,
          now: _clock(),
          time: preferences.journalReminderTime,
        ));
      }
    }
  }
}
