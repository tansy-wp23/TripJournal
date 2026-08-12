/// A record of an administrator-initiated action.
///
/// Owned by the Admin module (`ADMIN_MODULE_IMPLEMENTATION_PLAN.md`,
/// Architecture Decision 5) — this is the `Audit_Log` table that
/// `USER_MANAGEMENT_IMPLEMENTATION_PLAN.md` explicitly left out of its own
/// scope. A single generic table serves every kind of admin action: PB-04's
/// "record audit log" and PB-05's "record status history" for a user
/// (`targetType: user`), and Sprint 2's PB-09 "record action in audit log"
/// for an issue report (`targetType: issueReport`) — status history for a
/// target is just [AdminAuditLogRepository.getHistoryForTarget] filtered to
/// it, ordered newest-first; there is no separate history table per target
/// type (Architecture Decision 6, `ADMIN_MODULE_IMPLEMENTATION_PLAN.md`
/// Sprint 2 — this generalized `targetType`/`targetId` pair from a
/// Sprint-1-only `targetUserId`, see `docs/admin/PROGRESS.md` Phase 8).
class AdminAuditLog {
  final String logId;
  final String adminUserId;
  final AdminAuditTargetType targetType;
  final String targetId;
  final AdminAction action;
  final String? reason;
  final DateTime createdAt;

  const AdminAuditLog({
    required this.logId,
    required this.adminUserId,
    required this.targetType,
    required this.targetId,
    required this.action,
    this.reason,
    required this.createdAt,
  });

  factory AdminAuditLog.fromJson(Map<String, dynamic> json) {
    return AdminAuditLog(
      logId: json['logId'] as String,
      adminUserId: json['adminUserId'] as String,
      targetType: AdminAuditTargetType.values.firstWhere(
        (t) => t.name == json['targetType'],
      ),
      targetId: json['targetId'] as String,
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
      'targetType': targetType.name,
      'targetId': targetId,
      'action': action.name,
      'reason': reason,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// What kind of entity an [AdminAuditLog] entry's [AdminAuditLog.targetId]
/// refers to.
enum AdminAuditTargetType { user, issueReport }

/// The kind of administrator action an [AdminAuditLog] entry records.
/// `suspend`/`reactivate` target a `user`; `issueMarkInProgress`/
/// `issueMarkResolved`/`issueReopen` target an `issueReport` — one enum
/// value per specific admin-initiated transition, not a generic
/// "statusChanged", mirroring how `suspend`/`reactivate` were already
/// specific verbs rather than one generic value.
enum AdminAction {
  suspend,
  reactivate,
  issueMarkInProgress,
  issueMarkResolved,
  issueReopen,
}
