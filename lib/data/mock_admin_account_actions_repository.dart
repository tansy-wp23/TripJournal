import '../models/admin_audit_log.dart';
import '../models/profile.dart';
import 'admin_account_actions_repository.dart';
import 'mock_admin_audit_log_repository.dart';
import 'mock_admin_user_store.dart';

/// In-memory fake of [AdminAccountActionsRepository] so UI work in Phases
/// 2–6 never blocks on a backend. Mutates the shared [MockAdminUserStore]
/// and writes through to [MockAdminAuditLogRepository].
///
/// This is a plain state transition only — "validate suspension request"
/// (e.g. reject suspending an already-suspended user or an admin account)
/// is Phase 5 controller/UI validation, not enforced here, matching how
/// `MockAccountLifecycleRepository` also leaves higher-level validation to
/// its callers.
class MockAdminAccountActionsRepository implements AdminAccountActionsRepository {
  final MockAdminUserStore store;
  final MockAdminAuditLogRepository auditLogRepository;

  MockAdminAccountActionsRepository({
    required this.store,
    required this.auditLogRepository,
  });

  @override
  Future<void> suspendUser({
    required String adminUserId,
    required String targetUserId,
    String? reason,
  }) async {
    final index = _indexOf(targetUserId);
    final now = DateTime.now();
    store.profiles[index] = store.profiles[index].copyWith(
      status: AccountStatus.suspended,
      deactivatedAt: now,
      updatedAt: now,
    );
    await auditLogRepository.recordAction(
      AdminAuditLog(
        logId: auditLogRepository.nextLogId(),
        adminUserId: adminUserId,
        targetType: AdminAuditTargetType.user,
        targetId: targetUserId,
        action: AdminAction.suspend,
        reason: reason,
        createdAt: now,
      ),
    );
    // Real backend (Phase 7) also calls auth.admin.signOut(targetUserId)
    // here to terminate the target's active session (PB-04). No live
    // session exists to terminate in mock mode — see
    // ADMIN_MODULE_IMPLEMENTATION_PLAN.md Phase 1, task 4.
  }

  @override
  Future<void> reactivateUser({
    required String adminUserId,
    required String targetUserId,
  }) async {
    final index = _indexOf(targetUserId);
    final now = DateTime.now();
    store.profiles[index] = store.profiles[index].copyWith(
      status: AccountStatus.active,
      clearDeactivatedAt: true,
      updatedAt: now,
    );
    await auditLogRepository.recordAction(
      AdminAuditLog(
        logId: auditLogRepository.nextLogId(),
        adminUserId: adminUserId,
        targetType: AdminAuditTargetType.user,
        targetId: targetUserId,
        action: AdminAction.reactivate,
        createdAt: now,
      ),
    );
  }

  int _indexOf(String targetUserId) {
    final index = store.profiles.indexWhere((p) => p.userID == targetUserId);
    if (index == -1) {
      throw StateError('No user with id $targetUserId.');
    }
    return index;
  }
}