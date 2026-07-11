import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/trip_day_groups.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';
import 'package:tripjournal/models/trip.dart';

Trip _trip({required DateTime start, required DateTime end}) {
  return Trip(
    id: 't',
    userId: 'u',
    title: 'Test Trip',
    startDate: start,
    endDate: end,
    createdAt: start,
    updatedAt: start,
  );
}

JournalEntry _entry({required String id, required DateTime createdAt}) {
  return JournalEntry(
    id: id,
    tripId: 't',
    title: 'title-$id',
    body: 'body',
    mood: Mood.neutral,
    photoPaths: const [],
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

void main() {
  test('produces exactly one group per day in the trip range, in order', () {
    final trip = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 14));
    final groups = buildDayGroups(trip, const []);

    expect(groups.length, 5);
    expect(groups.map((g) => g.dayNumber), [1, 2, 3, 4, 5]);
    expect(groups.first.date, DateTime(2026, 4, 10));
    expect(groups.last.date, DateTime(2026, 4, 14));
    expect(groups.every((g) => g.isEmpty), isTrue);
  });

  test('single-day trip produces exactly one group', () {
    final trip = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 10));
    final groups = buildDayGroups(trip, const []);
    expect(groups.length, 1);
    expect(groups.single.dayNumber, 1);
  });

  test('multiple entries on the same day land in one group, ordered by time', () {
    final trip = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 11));
    final entries = [
      _entry(id: 'evening', createdAt: DateTime(2026, 4, 10, 20)),
      _entry(id: 'morning', createdAt: DateTime(2026, 4, 10, 8)),
      _entry(id: 'afternoon', createdAt: DateTime(2026, 4, 10, 14)),
    ];

    final groups = buildDayGroups(trip, entries);

    expect(groups[0].entries.map((e) => e.id), ['morning', 'afternoon', 'evening']);
    expect(groups[1].isEmpty, isTrue);
  });

  test('entries outside the trip range are ignored', () {
    final trip = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 11));
    final entries = [_entry(id: 'outside', createdAt: DateTime(2026, 5, 1))];

    final groups = buildDayGroups(trip, entries);

    expect(groups.every((g) => g.isEmpty), isTrue);
  });

  test('the day slot matching today has the correct day number', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final trip = _trip(
      start: today.subtract(const Duration(days: 2)),
      end: today.add(const Duration(days: 2)),
    );

    final groups = buildDayGroups(trip, const []);
    final todayGroup = groups.firstWhere((g) => g.date == today);

    expect(todayGroup.dayNumber, 3); // 2 days before today, so today is day 3
  });
}
