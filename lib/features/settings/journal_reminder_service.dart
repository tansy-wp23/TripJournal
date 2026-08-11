import 'package:flutter/material.dart';

import '../../models/trip.dart';

class ScheduledJournalReminder {
  const ScheduledJournalReminder({required this.id, required this.when});
  final int id;
  final DateTime when;
}

List<ScheduledJournalReminder> planJournalReminders({
  required List<Trip> trips,
  required DateTime now,
  required TimeOfDay time,
  int limit = 60,
}) {
  final planned = <DateTime>{};
  for (final trip in trips) {
    for (final day in trip.dayList) {
      final when = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      if (when.isAfter(now)) planned.add(when);
    }
  }
  final ordered = planned.toList()..sort();
  return [
    for (var i = 0; i < ordered.length && i < limit; i++)
      ScheduledJournalReminder(id: 41000 + i, when: ordered[i]),
  ];
}

abstract class JournalReminderService {
  bool get isSupported;
  Future<bool> requestPermission();
  Future<void> replaceScheduled(List<ScheduledJournalReminder> reminders);
  Future<void> cancelAll();
}

class UnsupportedJournalReminderService implements JournalReminderService {
  const UnsupportedJournalReminderService();
  @override
  bool get isSupported => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> replaceScheduled(List<ScheduledJournalReminder> reminders) async {}
  @override
  Future<void> cancelAll() async {}
}
