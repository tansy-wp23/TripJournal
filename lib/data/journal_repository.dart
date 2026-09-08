import '../models/journal_entry.dart';

abstract class JournalRepository {
  /// Published entries for [tripId], oldest first.
  ///
  /// Drafts are excluded unless [includeDrafts] is set, and that default is
  /// the safety net: callers that know nothing about drafts — the public
  /// trip view, PDF export, the map, trip stats, the AI summary — cannot
  /// leak a half-written entry by forgetting to filter. Only the trip
  /// timeline and the editor opt in.
  Future<List<JournalEntry>> getEntries(
    String tripId, {
    bool includeDrafts = false,
  });
  Future<JournalEntry?> getEntry(String id);
  Future<void> addEntry(JournalEntry entry);
  Future<void> updateEntry(JournalEntry entry);
  Future<void> deleteEntry(String id);
}
