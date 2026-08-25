import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/journal_entry.dart';
import 'current_user_id_provider.dart';
import 'journal_repository.dart';
import 'journal_supabase_mapper.dart';

/// Real [JournalRepository] backed by Supabase — mirrors
/// `SupabaseTripRepository`.
///
/// One [JournalEntry] spans three tables: `journal_entries`, the single
/// `health_logs` row hanging off it, and that log's `meals`. Reads collapse all
/// three into one request with an embedded select; writes use the
/// `save_journal_entry_bundle` database function so all three tables commit or
/// roll back together.
///
/// Every method assumes a signed-in user. That is not defensiveness about
/// nulls: each of the three tables has RLS gating on `auth.uid()`, so an
/// anonymous session does not error, it silently reads back nothing and writes
/// rows nobody can see. [CurrentUserIdProvider.requireUserId] turns that into a
/// thrown [UnauthenticatedTripUserException] at the point of the write instead.
class SupabaseJournalRepository implements JournalRepository {
  SupabaseJournalRepository(this._client, this._userIdProvider);

  final SupabaseClient _client;
  final CurrentUserIdProvider _userIdProvider;

  /// The entry plus its log plus that log's meals, in one round trip.
  ///
  /// `health_logs` embeds as a *list* because the foreign key sits on the child
  /// table — the mapper collapses it. See [healthLogFromEmbeddedRows].
  // No spaces: postgrest strips them before sending, so keeping them here
  // only makes the constant disagree with what goes on the wire.
  static const _entrySelect = '*,health_logs(*,meals(*))';

  @override
  Future<List<JournalEntry>> getEntries(String tripId) async {
    final rows = await _client
        .from('journal_entries')
        .select(_entrySelect)
        .eq('trip_id', tripId)
        // Ascending explicitly: postgrest's `order` defaults to *descending*,
        // which would hand the timeline back newest-first here while
        // MockJournalRepository returns it oldest-first. Same app, same screen,
        // different order depending on the backend.
        .order('created_at', ascending: true);
    return rows.map(journalEntryFromSupabaseRow).toList();
  }

  @override
  Future<JournalEntry?> getEntry(String id) async {
    final row = await _client
        .from('journal_entries')
        .select(_entrySelect)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : journalEntryFromSupabaseRow(row);
  }

  @override
  Future<void> addEntry(JournalEntry entry) async {
    await _saveBundle(entry);
  }

  @override
  Future<void> updateEntry(JournalEntry entry) async {
    await _saveBundle(entry);
  }

  @override
  Future<void> deleteEntry(String id) async {
    await _client.from('journal_entries').delete().eq('id', id);
  }

  Future<void> _saveBundle(JournalEntry entry) async {
    final userId = _userIdProvider.requireUserId();
    final entryRow = journalEntryToSupabaseRow(entry, userId: userId)
      ..remove('user_id');
    final log = entry.healthLog;
    final logRow = log == null
        ? null
        : (healthLogToSupabaseRow(log, userId: userId)..remove('user_id'));
    final mealRows = log == null
        ? const <Map<String, dynamic>>[]
        : [
            for (final meal in log.meals)
              (mealToSupabaseRow(meal, userId: userId, healthLogId: log.id)
                ..remove('user_id')),
          ];

    await _client.rpc(
      'save_journal_entry_bundle',
      params: {
        'p_entry': entryRow,
        'p_health_log': logRow,
        'p_meals': mealRows,
      },
    );
  }
}
