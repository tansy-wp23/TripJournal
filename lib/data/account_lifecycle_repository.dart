import '../models/verification_code.dart';
import 'verification_code_repository.dart';

/// Maps to the "Account Deactivation" and "Account Reactivation" components
/// from Component.md.
///
/// These are the only operations that need privileged server-side logic
/// (Phase 6 Edge Functions): deactivation must call
/// `auth.admin.signOut(userId)` (requires service role), and both flows
/// validate a code before mutating `Profile.status`.
abstract class AccountLifecycleRepository {
  /// Requests deactivation: sends a code to the user's email for
  /// [VerificationPurpose.deactivation]. The user must then call
  /// [confirmDeactivation] with that code.
  Future<void> requestDeactivation();

  /// Confirms deactivation with [code]. On success, sets
  /// `Profile.status = deactivated` and ends the session
  /// (`auth.admin.signOut` server-side in Phase 6).
  ///
  /// Throws [CodeValidationException] if the code is invalid or expired.
  Future<void> confirmDeactivation(String code);

  /// Requests reactivation: sends a code to the user's (Google/social)
  /// email for [VerificationPurpose.reactivation]. There is no separate
  /// "enter your email" step — the email is whatever Supabase Auth already
  /// has on file for the identity.
  Future<void> requestReactivation();

  /// Confirms reactivation with [code]. On success, sets
  /// `Profile.status = active`. The existing (already-valid) Supabase
  /// session is then treated as fully authenticated — no second Google
  /// sign-in needed (Architecture Decision 7).
  ///
  /// Throws [CodeValidationException] if the code is invalid or expired.
  /// Throws [AccountSuspendedException] if the profile's status is
  /// `AccountStatus.suspended` rather than `AccountStatus.deactivated` —
  /// see that exception's doc comment.
  Future<void> confirmReactivation(String code);

  /// Requests permanent account deletion: sends a code to the user's email
  /// for [VerificationPurpose.deletion]. The user must then call
  /// [deleteAccount] with that code.
  ///
  /// Distinct from deactivation: deactivation is reversible (data intact,
  /// "I might come back"); deletion is irreversible (right-to-erasure, "I
  /// want this gone"). Phase 9.
  Future<void> requestDeletion();

  /// Confirms permanent account deletion with [code]. On success, the
  /// `auth.users` row is deleted server-side, which cascades to `profiles`
  /// and `verification_codes` (both have `on delete cascade` FKs). The
  /// caller must then clear local app state and sign out client-side — the
  /// local Supabase session now points at a user that no longer exists.
  ///
  /// Throws [CodeValidationException] if the code is invalid or expired.
  Future<void> deleteAccount(String code);
}

/// Thrown by [AccountLifecycleRepository.confirmReactivation] when the
/// profile's status is `AccountStatus.suspended` rather than
/// `AccountStatus.deactivated`. An admin-imposed suspension
/// (`AdminAccountActionsRepository.suspendUser`) must not be undoable by
/// this self-service flow — only `AdminAccountActionsRepository.reactivateUser`
/// may clear it. Added for the Admin module
/// (`ADMIN_MODULE_IMPLEMENTATION_PLAN.md` Open Decision 2, wired in
/// Phase 5 — see `docs/admin/PROGRESS.md`). **Cross-module change**: this
/// file is owned by the User Management module — coordinate before
/// merging, per that module's own note on `Profile.status` gaining
/// `suspended` back in Phase 0.
class AccountSuspendedException implements Exception {
  const AccountSuspendedException();

  @override
  String toString() =>
      'AccountSuspendedException: this account was suspended by an administrator.';
}

/// Thrown when a submitted verification code is wrong or expired.
class CodeValidationException implements Exception {
  final CodeValidationResult result;
  final String message;

  const CodeValidationException(this.result, this.message);

  @override
  String toString() => 'CodeValidationException($result): $message';
}