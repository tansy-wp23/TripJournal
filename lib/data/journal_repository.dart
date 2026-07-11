import '../models/journal_entry.dart';

abstract class JournalRepository {
  Future<List<JournalEntry>> getEntries(String tripId);
  Future<JournalEntry?> getEntry(String id);
  Future<void> addEntry(JournalEntry entry);
  Future<void> updateEntry(JournalEntry entry);
  Future<void> deleteEntry(String id);
}
