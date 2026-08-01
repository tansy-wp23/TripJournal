import '../../models/journal_entry.dart';
import '../../models/mood.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Search/filter criteria for a trip's journal entries
/// (IMPLEMENTATION_PLAN_EXTRA_FEATURES.md #2). An empty/default filter
/// matches everything — the default (unfiltered) view is never broken.
class JournalFilter {
  const JournalFilter({
    this.query = '',
    this.mood,
    this.startDate,
    this.endDate,
  });

  /// Matched case-insensitively against title and body.
  final String query;

  /// When set, only entries with this exact mood match.
  final Mood? mood;

  /// Inclusive date range (date-only). Either bound may be null.
  final DateTime? startDate;
  final DateTime? endDate;

  bool get isActive =>
      query.trim().isNotEmpty ||
      mood != null ||
      startDate != null ||
      endDate != null;

  JournalFilter copyWith({
    String? query,
    Mood? mood,
    bool clearMood = false,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDateRange = false,
  }) {
    return JournalFilter(
      query: query ?? this.query,
      mood: clearMood ? null : (mood ?? this.mood),
      startDate: clearDateRange ? null : (startDate ?? this.startDate),
      endDate: clearDateRange ? null : (endDate ?? this.endDate),
    );
  }
}

/// Pure filter — no I/O, trivial to unit test. Runs over already-loaded
/// entries; a default [JournalFilter] returns [entries] unchanged.
List<JournalEntry> filterJournalEntries(
  List<JournalEntry> entries,
  JournalFilter filter,
) {
  if (!filter.isActive) return entries;

  final query = filter.query.trim().toLowerCase();
  final start = filter.startDate == null ? null : _dateOnly(filter.startDate!);
  final end = filter.endDate == null ? null : _dateOnly(filter.endDate!);

  return entries.where((entry) {
    if (query.isNotEmpty) {
      final matchesText =
          entry.title.toLowerCase().contains(query) ||
          entry.body.toLowerCase().contains(query);
      if (!matchesText) return false;
    }
    if (filter.mood != null && entry.mood != filter.mood) return false;

    final day = _dateOnly(entry.createdAt);
    if (start != null && day.isBefore(start)) return false;
    if (end != null && day.isAfter(end)) return false;

    return true;
  }).toList();
}
