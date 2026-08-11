import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/settings/journal_reminder_service.dart';
import 'package:tripjournal/models/trip.dart';

Trip _trip(String id, DateTime start, DateTime end) => Trip(
      id: id,
      userId: 'user',
      title: id,
      destination: 'Somewhere',
      startDate: start,
      endDate: end,
      createdAt: start,
      updatedAt: start,
    );

void main() {
  test('plans reminders only on trip dates at the selected local time', () {
    final reminders = planJournalReminders(
      trips: [_trip('trip', DateTime(2026, 8, 12), DateTime(2026, 8, 14))],
      now: DateTime(2026, 8, 11, 21),
      time: const TimeOfDay(hour: 19, minute: 30),
    );
    expect(reminders.map((item) => item.when), [
      DateTime(2026, 8, 12, 19, 30),
      DateTime(2026, 8, 13, 19, 30),
      DateTime(2026, 8, 14, 19, 30),
    ]);
  });

  test('skips elapsed times today and caps the rolling schedule at 60', () {
    final reminders = planJournalReminders(
      trips: [_trip('long', DateTime(2026, 8, 1), DateTime(2027, 8, 1))],
      now: DateTime(2026, 8, 11, 21),
      time: const TimeOfDay(hour: 20, minute: 0),
    );
    expect(reminders, hasLength(60));
    expect(reminders.first.when, DateTime(2026, 8, 12, 20));
  });
}
