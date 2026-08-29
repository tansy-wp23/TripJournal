import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/verification_code.dart';
import 'account_lifecycle_repository.dart';
import 'profile_repository.dart';
import 'verification_code_repository.dart';

/// Real [AccountLifecycleRepository] backed by the Phase 6 Edge Functions
/// (`account-deactivate-confirm`, `account-reactivate-confirm`) and the
/// [VerificationCodeRepository] for send/resend.
///
/// Deactivation must call `auth.admin.signOut(userId)` (requires service
/// role) — that's why it's a privileged Edge Function, not a plain
/// RLS-guarded table write. Reactivation just sets `Profile.status = active`
/// (the session was never revoked, only gated — Architecture Decision 7).
///
/// IMPORTANT: confirmDeactivation/confirmReactivation call the confirm Edge
/// Function directly and do NOT pre-validate the code via
/// VerificationCodeRepository.validateCode() first. That function has a
/// side effect on the code row (it appears to touch used_at/attempt_count
/// even outside the account-*-confirm flow), so calling it as a pre-check
/// consumed the code before the real confirm function's own server-side
/// validateCode() call ran — causing a spurious not_found on the second,
/// real check, even for a correct code. The confirm Edge Functions already
/// validate server-side; that's the single source of truth for consuming a
/// code, so the client should call them directly and surface whatever error
/// they return rather than validating twice.
class SupabaseAccountLifecycleRepository implements AccountLifecycleRepository {
  SupabaseAccountLifecycleRepository(
    this._client,
    this._verificationCodeRepository,
    this._profileRepository,
  );

  final SupabaseClient _client;
  final VerificationCodeRepository _verificationCodeRepository;
  final ProfileRepository _profileRepository;

  @override
  Future<void> requestDeactivation() async {
    await _verificationCodeRepository.sendCode(
      VerificationPurpose.deactivation,
    );
  }

  @override
  Future<void> confirmDeactivation(String code) async {
    try {
      // The Edge Function validates the code server-side (and consumes it
      // on success), sets status = deactivated, and calls
      // auth.admin.signOut(userId). This is the only validate+consume call
      // in this flow — do not call VerificationCodeRepository.validateCode()
      // beforehand, see class doc comment.
      await _client.functions.invoke(
        'account-deactivate-confirm',
        body: {'code': code},
      );
    } on FunctionException catch (e) {
      throw _mapConfirmError(e);
    }
  }

  @override
  Future<void> requestReactivation() async {
    await _verificationCodeRepository.sendCode(
      VerificationPurpose.reactivation,
    );
  }

  @override
  Future<void> confirmReactivation(String code) async {
    // Admin Module Phase 5 guard: a suspended account can only be cleared
    // by AdminAccountActionsRepository.reactivateUser, never by this
    // self-service flow — see AccountSuspendedException's doc comment.
    // Checked before calling the confirm function so a suspended user never
    // triggers (and burns) a code attempt for a flow they can't complete.
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      final profile = await _profileRepository.getProfile(userId);
      if (profile != null && profile.isSuspended) {
        throw const AccountSuspendedException();
      }
    }

    try {
      // The Edge Function validates the code server-side (and consumes it
      // on success) and sets status = active, clearing deactivated_at. Same
      // rule as confirmDeactivation — no client-side pre-validate call.
      await _client.functions.invoke(
        'account-reactivate-confirm',
        body: {'code': code},
      );
    } on FunctionException catch (e) {
      throw _mapConfirmError(e);
    }
  }

  @override
  Future<void> requestDeletion() async {
    await _verificationCodeRepository.sendCode(VerificationPurpose.deletion);
  }

  @override
  Future<void> deleteAccount(String code) async {
    try {
      // The Edge Function validates the code server-side (and consumes it
      // on success) and deletes the auth.users row, which cascades to
      // profiles and verification_codes. Same rule as the other confirm
      // functions — no client-side pre-validate call.
      await _client.functions.invoke(
        'account-delete-confirm',
        body: {'code': code},
      );
    } on FunctionException catch (e) {
      throw _mapConfirmError(e);
    }
  }

  /// Maps a 400 `{"error": "invalid_code:<reason>"}` response from either
  /// confirm function into the same [CodeValidationException] shape the
  /// rest of the app already expects. Any other status/shape is rethrown
  /// as-is so genuine failures (network, 401, 500) aren't misreported as an
  /// invalid code.
  Object _mapConfirmError(FunctionException e) {
    final details = e.details;
    if (e.status == 400 && details is Map && details['error'] is String) {
      final errorStr = details['error'] as String;
      const prefix = 'invalid_code:';
      if (errorStr.startsWith(prefix)) {
        final reason = errorStr.substring(prefix.length);
        final result = switch (reason) {
          'expired' => CodeValidationResult.expired,
          'locked' => CodeValidationResult.locked,
          _ => CodeValidationResult.invalid,
        };
        return CodeValidationException(
          result,
          'Invalid, expired, or locked code.',
        );
      }
    }
    return e;
  }
}