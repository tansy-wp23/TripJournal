import '../models/admin_audit_log.dart';

/// Maps to the audit-log portion of PB-04/PB-05 (Suspend/Reactivate User).
/// Real implementation (Phase 7): `admin_audit_log` table, insert-only from
/// the privileged Edge Functions, readable by `role == admin` callers via
/// RLS — never written to directly from the client.
abstract class AdminAuditLogRepository {
  /// Appends an audit entry. Called by [AdminAccountActionsRepository]'s
  /// implementations, not directly by UI code.
  Future<void> recordAction(AdminAuditLog entry);

  /// All audit entries for [userId], newest first. This is what satisfies
  /// PB-05's "record status history" — there is no separate history table.
  Future<List<AdminAuditLog>> getHistoryForUser(String userId);
}