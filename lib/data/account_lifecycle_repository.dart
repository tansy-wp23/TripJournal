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
  Future<void> confirmReactivation(String code);
}

/// Thrown when a submitted verification code is wrong or expired.
class CodeValidationException implements Exception {
  final CodeValidationResult result;
  final String message;

  const CodeValidationException(this.result, this.message);

  @override
  String toString() => 'CodeValidationException($result): $message';
}