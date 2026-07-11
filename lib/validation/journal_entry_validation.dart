import '../models/trip.dart';

const kEntryTitleMaxLength = 100;
const kEntryBodyMaxLength = 5000;

/// The combined title+body text budget across the whole entry — see the
/// "journal is 50k" cap in IMPLEMENTATION_PLAN_VALIDATION.md. Far above the
/// individual field caps today (100 + 5000 = 5100), but kept as an explicit
/// ceiling for when the entry grows more text areas.
const kEntryTotalTextMaxLength = 50000;

/// Content rule: a title OR a body is enough — not both required.
String? validateEntryContent(String title, String body) {
  if (title.trim().isEmpty && body.trim().isEmpty) {
    return 'Please add a title or write something in your entry.';
  }
  return null;
}

String? validateEntryTitleLength(String title) {
  if (title.length > kEntryTitleMaxLength) {
    return 'Title must be $kEntryTitleMaxLength characters or fewer.';
  }
  return null;
}

String? validateEntryBodyLength(String body) {
  if (body.length > kEntryBodyMaxLength) {
    return 'Entry body must be 5,000 characters or fewer.';
  }
  return null;
}

String? validateEntryTotalTextLength(String title, String body) {
  if (title.length + body.length > kEntryTotalTextMaxLength) {
    return 'This entry is too long. Please shorten it.';
  }
  return null;
}

/// Entry-date rule: no future days ever; and when [trip] is known, the day
/// must fall within its [Trip.startDate, Trip.endDate]. Only meaningful for
/// NEW entries — editing never changes an entry's day (see
/// IMPLEMENTATION_PLAN_ENHANCEMENTS.md §5), so callers should skip this on
/// edit rather than re-validate an unrelated field change against dates that
/// may have shifted since the entry was created.
String? validateEntryDate(DateTime day, {required DateTime now, Trip? trip}) {
  final entryDay = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  if (entryDay.isAfter(today)) {
    return "You can't add an entry for a future day.";
  }

  if (trip != null) {
    final tripStart = DateTime(trip.startDate.year, trip.startDate.month, trip.startDate.day);
    final tripEnd = DateTime(trip.endDate.year, trip.endDate.month, trip.endDate.day);
    if (entryDay.isBefore(tripStart) || entryDay.isAfter(tripEnd)) {
      return 'This date is outside your trip dates.';
    }
  }

  return null;
}
