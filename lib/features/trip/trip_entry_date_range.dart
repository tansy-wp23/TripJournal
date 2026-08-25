import '../../models/journal_entry.dart';
import '../../models/trip.dart';

bool isEntryWithinTrip(Trip trip, JournalEntry entry) {
  final entryDay = _localDateOnly(entry.createdAt);
  final startDay = _localDateOnly(trip.startDate);
  final endDay = _localDateOnly(trip.endDate);
  return !entryDay.isBefore(startDay) && !entryDay.isAfter(endDay);
}

List<JournalEntry> entriesWithinTrip(
  Trip trip,
  Iterable<JournalEntry> entries,
) => entries.where((entry) => isEntryWithinTrip(trip, entry)).toList();

DateTime _localDateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}
