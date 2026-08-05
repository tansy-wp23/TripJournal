/// A record of an administrator-initiated action taken on a user account.
///
/// Owned by the Admin module (`ADMIN_MODULE_IMPLEMENTATION_PLAN.md`,
/// Architecture Decision 5) — this is the `Audit_Log` table that
/// `USER_MANAGEMENT_IMPLEMENTATION_PLAN.md` explicitly left out of its own
/// scope. A single generic table serves both PB-04's "record audit log" and
/// PB-05's "record status history": status history for a user is just
/// [AdminAuditLogRepository.getHistoryForUser] filtered to that user,
/// ordered newest-first — there is no separate history table.
class AdminAuditLog {
  final String logId;
  final String adminUserId;
  final String targetUserId;
  final AdminAction action;
  final String? reason;
  final DateTime createdAt;

  const AdminAuditLog({
    required this.logId,
    required this.adminUserId,
    required this.targetUserId,
    required this.action,
    this.reason,
    required this.createdAt,
  });

  factory AdminAuditLog.fromJson(Map<String, dynamic> json) {
    return AdminAuditLog(
      logId: json['logId'] as String,
      adminUserId: json['adminUserId'] as String,
      targetUserId: json['targetUserId'] as String,
      action: AdminAction.values.firstWhere(
        (a) => a.name == json['action'],
      ),
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'logId': logId,
      'adminUserId': adminUserId,
      'targetUserId': targetUserId,
      'action': action.name,
      'reason': reason,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// The kind of administrator action an [AdminAuditLog] entry records.
enum AdminAction { suspend, reactivate }