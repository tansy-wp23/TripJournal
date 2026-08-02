import '../models/verification_code.dart';

/// Maps to the "Verification Code" component from Component.md. Fully
/// hand-built — Supabase Auth has no concept of emailing a one-time code to
/// confirm an action.
///
/// Real implementation (Phase 6) calls privileged Edge Functions that hash
/// the code (never store plaintext), enforce `attempt_count` lockout and
/// `expires_at`, and send the email.
abstract class VerificationCodeRepository {
  /// Sends a one-time code to the current user's email for [purpose].
  ///
  /// In mock mode the code is logged to the console (always `"123456"`).
  Future<void> sendCode(VerificationPurpose purpose);

  /// Validates [code] for [purpose]. Returns a [CodeValidationResult]
  /// distinguishing wrong-code from expired-code so the UI (Phase 4) can
  /// show the correct error state.
  Future<CodeValidationResult> validateCode({
    required String code,
    required VerificationPurpose purpose,
  });

  /// Invalidates the previous code and sends a fresh one.
  Future<void> resendCode(VerificationPurpose purpose);
}

/// Outcome of validating a submitted code.
enum CodeValidationResult { valid, invalid, expired }