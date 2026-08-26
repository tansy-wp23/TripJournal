import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_access_attempt_log.dart';
import 'admin_access_attempt_log_repository.dart';

/// Real [AdminAccessAttemptLogRepository] backed by the
/// `admin_access_attempt_log` table (Phase 7 of
/// ADMIN_MODULE_IMPLEMENTATION_PLAN.md). Insert is allowed for any
/// signed-in caller recording an attempt about themselves
/// (`auth.uid() = attempted_user_id`) — deliberately not
/// `is_admin_user()`-gated, since the whole point is recording a *failed*
/// admin check; reads are `is_admin_user()`-scoped
/// (202608190001_admin_rbac_and_audit_logs.sql).
class SupabaseAdminAccessAttemptLogRepository
    implements AdminAccessAttemptLogRepository {
  SupabaseAdminAccessAttemptLogRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> recordAttempt(AdminAccessAttemptLog entry) async {
    await _client.from('admin_access_attempt_log').insert({
      'attempted_user_id': entry.attemptedUserId,
      'attempted_email': entry.attemptedEmail,
      'reason': entry.reason.name,
    });
  }

  @override
  Future<List<AdminAccessAttemptLog>> getRecentAttempts({int? limit}) async {
    var builder = _client
        .from('admin_access_attempt_log')
        .select()
        .order('created_at', ascending: false);
    if (limit != null) {
      builder = builder.limit(limit);
    }
    final rows = await builder;
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<AdminAccessAttemptLog>> getAttemptsForUserId(String userId) async {
    final rows = await _client
        .from('admin_access_attempt_log')
        .select()
        .eq('attempted_user_id', userId)
        .order('created_at', ascending: false);
    return rows.map(_fromRow).toList();
  }

  AdminAccessAttemptLog _fromRow(Map<String, dynamic> row) {
    return AdminAccessAttemptLog(
      logId: row['log_id'] as String,
      attemptedUserId: row['attempted_user_id'] as String,
      attemptedEmail: row['attempted_email'] as String,
      reason: AdminAccessAttemptReason.values.firstWhere(
        (r) => r.name == row['reason'],
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
