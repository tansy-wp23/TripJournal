/// Maps to PB-04 (Suspend User) and PB-05 (Reactivate User). Each method is
/// a composition — update `Profile.status` + write an `AdminAuditLog` entry
/// — not raw table access. The real implementation (Phase 7) additionally
/// terminates the target's active session inside [suspendUser], via the
/// same privileged `auth.admin.signOut(userId)` pattern the User Management
/// module uses for self-deactivation
/// (`USER_MANAGEMENT_IMPLEMENTATION_PLAN.md` Architecture Decision 3).
///
/// "Validate suspension request" (e.g. reject suspending an already
/// suspended user, or an admin account) is Phase 5 UI/controller-level
/// validation, not enforced by this interface's mocks in Phase 1.
abstract class AdminAccountActionsRepository {
  /// Suspends [targetUserId]. Sets `Profile.status = AccountStatus.suspended`
  /// (distinct from self-service `deactivated` — see
  /// `AccountStatus.suspended`'s doc comment) and records an
  /// `AdminAuditLog` entry with `action = AdminAction.suspend`.
  Future<void> suspendUser({
    required String adminUserId,
    required String targetUserId,
    String? reason,
  });

  /// Reactivates [targetUserId]. Sets `Profile.status =
  /// AccountStatus.active` and records an `AdminAuditLog` entry with
  /// `action = AdminAction.reactivate`.
  Future<void> reactivateUser({
    required String adminUserId,
    required String targetUserId,
  });
}