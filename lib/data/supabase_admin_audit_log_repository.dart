import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_audit_log.dart';
import 'admin_audit_log_repository.dart';

/// Real [AdminAuditLogRepository] backed by the `admin_audit_log` table
/// (Phase 7 of ADMIN_MODULE_IMPLEMENTATION_PLAN.md; `getAllEntries` added
/// Phase 14 / Sprint 2 for PB-10 "Monitor Audit Log"). Reads are
/// RLS-scoped to `is_admin_user()` callers
/// (202608190001_admin_module_phase7.sql).
///
/// [recordAction] exists to satisfy the interface, but in practice every
/// entry is written by the privileged Edge Functions
/// (`admin-suspend-user`, `admin-reactivate-user`, and
/// `IssueReportRepository.updateStatus`'s composition) using the
/// service-role client, which bypasses RLS entirely — not this method.
class SupabaseAdminAuditLogRepository implements AdminAuditLogRepository {
  SupabaseAdminAuditLogRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> recordAction(AdminAuditLog entry) async {
    await _client.from('admin_audit_log').insert({
      'admin_user_id': entry.adminUserId,
      'target_type': entry.targetType.name,
      'target_id': entry.targetId,
      'action': entry.action.name,
      'reason': entry.reason,
    });
  }

  @override
  Future<List<AdminAuditLog>> getHistoryForTarget({
    required AdminAuditTargetType targetType,
    required String targetId,
  }) async {
    final rows = await _client
        .from('admin_audit_log')
        .select()
        .eq('target_type', targetType.name)
        .eq('target_id', targetId)
        .order('created_at', ascending: false);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<AdminAuditLog>> getAllEntries({
    AdminAuditTargetType? targetTypeFilter,
    AdminAction? actionFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var builder = _client.from('admin_audit_log').select();
    if (targetTypeFilter != null) {
      builder = builder.eq('target_type', targetTypeFilter.name);
    }
    if (actionFilter != null) {
      builder = builder.eq('action', actionFilter.name);
    }
    if (startDate != null) {
      builder = builder.gte('created_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      builder = builder.lte('created_at', endDate.toIso8601String());
    }
    final rows = await builder.order('created_at', ascending: false);
    return rows.map(_fromRow).toList();
  }

  AdminAuditLog _fromRow(Map<String, dynamic> row) {
    return AdminAuditLog(
      logId: row['log_id'] as String,
      adminUserId: row['admin_user_id'] as String,
      targetType: AdminAuditTargetType.values.firstWhere(
        (t) => t.name == row['target_type'],
      ),
      targetId: row['target_id'] as String,
      action: AdminAction.values.firstWhere((a) => a.name == row['action']),
      reason: row['reason'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
