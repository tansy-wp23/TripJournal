import '../models/admin_audit_log.dart';
import 'admin_audit_log_repository.dart';

/// In-memory fake of [AdminAuditLogRepository] so UI work never blocks on a
/// backend.
class MockAdminAuditLogRepository implements AdminAuditLogRepository {
  final List<AdminAuditLog> _entries = [];

  /// Monotonic counter so two entries recorded in the same millisecond
  /// still get distinct ids, mirroring
  /// `MockVerificationCodeRepository`'s `_codeCounter` pattern.
  int _logCounter = 0;

  /// All recorded entries, exposed for tests to inspect state.
  List<AdminAuditLog> get entries => List.unmodifiable(_entries);

  @override
  Future<void> recordAction(AdminAuditLog entry) async {
    _entries.add(entry);
  }

  @override
  Future<List<AdminAuditLog>> getHistoryForTarget({
    required AdminAuditTargetType targetType,
    required String targetId,
  }) async {
    final matches = _entries
        .where((e) => e.targetType == targetType && e.targetId == targetId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches;
  }

  @override
  Future<List<AdminAuditLog>> getAllEntries({
    AdminAuditTargetType? targetTypeFilter,
    AdminAction? actionFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final matches = _entries.where((e) {
      if (targetTypeFilter != null && e.targetType != targetTypeFilter) return false;
      if (actionFilter != null && e.action != actionFilter) return false;
      if (startDate != null && e.createdAt.isBefore(startDate)) return false;
      if (endDate != null && e.createdAt.isAfter(endDate)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches;
  }

  /// Generates a unique log id for callers composing an [AdminAuditLog]
  /// before calling [recordAction] (e.g.
  /// [MockAdminAccountActionsRepository]).
  String nextLogId() {
    _logCounter++;
    return 'audit-${DateTime.now().millisecondsSinceEpoch}-$_logCounter';
  }
}
