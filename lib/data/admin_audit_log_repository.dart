import '../models/admin_audit_log.dart';

/// Maps to the audit-log portion of PB-04/PB-05 (Suspend/Reactivate User)
/// and, since Sprint 2, PB-09 (Update Issue Status) and PB-10 (Monitor
/// Audit Log). Real implementation (Phase 7): `admin_audit_log` table,
/// insert-only from the privileged Edge Functions, readable by `role ==
/// admin` callers via RLS — never written to directly from the client.
abstract class AdminAuditLogRepository {
  /// Appends an audit entry. Called by [AdminAccountActionsRepository]'s
  /// and `IssueReportRepository`'s implementations, not directly by UI
  /// code.
  Future<void> recordAction(AdminAuditLog entry);

  /// All audit entries for one target (a user or an issue report), newest
  /// first. This is what satisfies PB-05's "record status history" and
  /// Sprint 2's equivalent for issue reports — there is no separate history
  /// table per target type. Renamed from Sprint 1's `getHistoryForUser`
  /// when the target concept was generalized (Sprint 2, Phase 8 —
  /// `docs/admin/PROGRESS.md`).
  Future<List<AdminAuditLog>> getHistoryForTarget({
    required AdminAuditTargetType targetType,
    required String targetId,
  });

  /// Every audit entry across every admin and every target, newest first,
  /// optionally narrowed by [targetTypeFilter], [actionFilter], and/or a
  /// `[startDate, endDate]` window — backs PB-10's "Monitor Audit Log"
  /// (Sprint 2), which Sprint 1 never needed since its screens were always
  /// scoped to one user via [getHistoryForTarget]. Plain `DateTime`
  /// bounds, not `package:flutter/material.dart`'s `DateTimeRange` — this
  /// layer has no Flutter UI dependency anywhere else in the codebase and
  /// shouldn't be the first to add one.
  Future<List<AdminAuditLog>> getAllEntries({
    AdminAuditTargetType? targetTypeFilter,
    AdminAction? actionFilter,
    DateTime? startDate,
    DateTime? endDate,
  });
}
