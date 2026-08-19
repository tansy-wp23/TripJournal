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
/// three into one request with an embedded select; writes cannot, because
/// PostgREST has no multi-table transaction — see [_writeHealthLog] for how
/// that is kept consistent without one.
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
    final userId = _userIdProvider.requireUserId();
    await _client
        .from('journal_entries')
        .insert(journalEntryToSupabaseRow(entry, userId: userId));
    await _writeHealthLog(entry, userId: userId);
  }

  @override
  Future<void> updateEntry(JournalEntry entry) async {
    final userId = _userIdProvider.requireUserId();
    await _client
        .from('journal_entries')
        .update(journalEntryEditableFieldsToSupabaseRow(entry))
        .eq('id', entry.id);
    await _writeHealthLog(entry, userId: userId);
  }

  @override
  Future<void> deleteEntry(String id) async {
    await _client.from('journal_entries').delete().eq('id', id);
  }

  /// Replaces the entry's health log and meals wholesale.
  ///
  /// Replace rather than diff: meals are owned entirely by their log and
  /// nothing else references them, so working out which rows changed would buy
  /// nothing but a chance to get it wrong. The delete runs before the insert so
  /// a meal the user removed cannot survive the save.
  ///
  /// The stale-log delete before the upsert is load-bearing, not belt and
  /// braces: `tripjournal_schema.sql` declares `health_logs.entry_id` **unique**
  /// on top of its cascade, so upserting a log under a new id while the old row
  /// still exists violates that constraint outright rather than leaving a
  /// duplicate behind.
  Future<void> _writeHealthLog(
    JournalEntry entry, {
    required String userId,
  }) async {
    final log = entry.healthLog;

    if (log == null) {
      await _deleteMealsForEntry(entry.id);
      await _client.from('health_logs').delete().eq('entry_id', entry.id);
      return;
    }

    await _client.from('meals').delete().eq('health_log_id', log.id);

    // A log whose id changed (the entry previously had none, so the edit screen
    // minted a fresh one) would otherwise leave the old row behind, and the
    // embedded read picks the first of whatever comes back — making which log
    // wins a coin toss.
    await _client
        .from('health_logs')
        .delete()
        .eq('entry_id', entry.id)
        .neq('id', log.id);

    await _client
        .from('health_logs')
        .upsert(healthLogToSupabaseRow(log, userId: userId));

    if (log.meals.isEmpty) return;
    await _client.from('meals').insert([
      for (final meal in log.meals)
        mealToSupabaseRow(meal, userId: userId, healthLogId: log.id),
    ]);
  }

  /// Meals reachable only through the entry's log(s) — used on the path where
  /// the log itself is going away, so there is no single log id to filter on.
  Future<void> _deleteMealsForEntry(String entryId) async {
    final logRows = await _client
        .from('health_logs')
        .select('id')
        .eq('entry_id', entryId);
    final logIds = logRows.map((row) => row['id'] as String).toList();
    if (logIds.isEmpty) return;
    await _client.from('meals').delete().inFilter('health_log_id', logIds);
  }
}
