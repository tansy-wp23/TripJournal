import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/settings/journal_reminder_coordinator.dart';
import 'package:tripjournal/features/settings/journal_reminder_service.dart';
import 'package:tripjournal/features/settings/settings_controller.dart';
import 'package:tripjournal/features/settings/settings_preferences.dart';
import 'package:tripjournal/models/trip.dart';

void main() {
  test('serializes overlapping reconciliations and applies the newest trip snapshot last', () async {
    final store = _Store();
    final settings = SettingsController(store);
    await settings.load();
    await settings.setReminderEnabled(true);
    final service = _BlockingService();
    final coordinator = JournalReminderCoordinator(service, settings, clock: () => DateTime(2026, 8, 11));

    final first = coordinator.reconcile([_trip('old', DateTime(2026, 8, 12))]);
    await service.firstStarted.future;
    final second = coordinator.reconcile([_trip('new', DateTime(2026, 8, 20))]);
    service.releaseFirst.complete();
    await Future.wait([first, second]);

    expect(service.schedules, hasLength(2));
    expect(service.schedules.last.single.when, DateTime(2026, 8, 20, 20));
  });
}

Trip _trip(String id, DateTime day) => Trip(
      id: id,
      userId: 'user',
      title: id,
      destination: 'Somewhere',
      startDate: day,
      endDate: day,
      createdAt: day,
      updatedAt: day,
    );

class _Store implements SettingsStore {
  SettingsPreferences value = SettingsPreferences.defaults;
  @override
  Future<SettingsPreferences> load() async => value;
  @override
  Future<void> save(SettingsPreferences preferences) async => value = preferences;
}

class _BlockingService implements JournalReminderService {
  final firstStarted = Completer<void>();
  final releaseFirst = Completer<void>();
  final schedules = <List<ScheduledJournalReminder>>[];
  @override
  bool get isSupported => true;
  @override
  Future<void> cancelAll() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> replaceScheduled(List<ScheduledJournalReminder> reminders) async {
    schedules.add(reminders);
    if (schedules.length == 1) {
      firstStarted.complete();
      await releaseFirst.future;
    }
  }
}
