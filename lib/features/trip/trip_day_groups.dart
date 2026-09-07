import '../../models/journal_entry.dart';
import '../../models/trip.dart';

/// One day of a trip's timeline. [entries] holds every journal entry whose
/// logical calendar date falls on [date], ordered by immutable creation order — a day may hold zero, one,
/// or many entries (decision #2 in IMPLEMENTATION_PLAN_HOMEPAGE.md).
class DayGroup {
  const DayGroup({
    required this.date,
    required this.dayNumber,
    required this.entries,
  });

  /// Date-only (midnight), 1-based within the trip.
  final DateTime date;
  final int dayNumber;
  final List<JournalEntry> entries;

  bool get isEmpty => entries.isEmpty;
}

/// Pure aggregation — no I/O, easy to unit test directly. Builds one
/// [DayGroup] per day in [trip.dayList], grouping [entries] by the calendar
/// day stored in `entry_date`.
List<DayGroup> buildDayGroups(Trip trip, List<JournalEntry> entries) {
  final entriesByDay = <DateTime, List<JournalEntry>>{};
  for (final entry in entries) {
    final day = entry.calendarDate;
    entriesByDay.putIfAbsent(day, () => []).add(entry);
  }
  for (final dayEntries in entriesByDay.values) {
    dayEntries.sort((a, b) {
      final byCreationOrder = a.creationOrderAt.compareTo(b.creationOrderAt);
      if (byCreationOrder != 0) return byCreationOrder;
      return a.id.compareTo(b.id);
    });
  }

  final days = trip.dayList;
  return [
    for (var i = 0; i < days.length; i++)
      DayGroup(
        date: days[i],
        dayNumber: i + 1,
        entries: entriesByDay[days[i]] ?? const [],
      ),
  ];
}
