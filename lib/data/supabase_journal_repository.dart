import '../models/journal_entry.dart';
import 'journal_repository.dart';

// TODO(phase6): implement against Supabase tables `journal_entries`,
// `health_logs`, and `meals`, then swap the locator in
// repository_locator.dart from MockJournalRepository to this class.
class SupabaseJournalRepository implements JournalRepository {
  @override
  Future<List<JournalEntry>> getEntries(String tripId) async {
    throw UnimplementedError();
  }

  @override
  Future<JournalEntry?> getEntry(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<void> addEntry(JournalEntry entry) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateEntry(JournalEntry entry) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEntry(String id) async {
    throw UnimplementedError();
  }
}
