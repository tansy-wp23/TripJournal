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
}

/// Outcome of validating a submitted code.
enum CodeValidationResult { valid, invalid, expired }

/// Why a code-send attempt failed. The UI (Phase 4/9) maps each kind to a
/// plain-language message so a non-technical user gets an honest reason
/// without seeing raw exception types.
enum SendCodeFailureKind {
  /// The server rate-limited the send (one code per user+purpose per 60s).
  rateLimited,

  /// The server returned a 5xx — a server-side problem, not the user's fault.
  serverError,

  /// The request never reached the server (no connection, timeout, DNS…).
  networkError,

  /// Anything else (400/401/404, unexpected shapes, …).
  other,
}

/// Thrown by [VerificationCodeRepository.sendCode] when the code could not
/// be sent. Carries a [SendCodeFailureKind] so the UI can show an honest,
/// user-friendly message instead of a raw exception string.
class SendCodeException implements Exception {
  final SendCodeFailureKind kind;

  const SendCodeException(this.kind);

  @override
  String toString() => 'SendCodeException($kind)';
}
