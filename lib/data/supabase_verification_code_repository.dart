import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/verification_code.dart';
import 'verification_code_repository.dart';

/// Real [VerificationCodeRepository] backed by the Phase 6 Edge Functions
/// (`verification-send`, `verification-validate`, `verification-resend`).
///
/// The Edge Functions handle code generation, hashing (never store
/// plaintext), `attempt_count` lockout, `expires_at` checks, and email
/// sending. The client only passes the purpose/code and reads the result.
class SupabaseVerificationCodeRepository implements VerificationCodeRepository {
  SupabaseVerificationCodeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> sendCode(VerificationPurpose purpose) async {
    await _client.functions.invoke(
      'verification-send',
      body: {'purpose': purpose.name},
    );
  }

  @override
  Future<CodeValidationResult> validateCode({
    required String code,
    required VerificationPurpose purpose,
  }) async {
    final response = await _client.functions.invoke(
      'verification-validate',
      body: {'purpose': purpose.name, 'code': code},
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final result = data['result'] as String?;
      return switch (result) {
        'valid' => CodeValidationResult.valid,
        'expired' => CodeValidationResult.expired,
        _ => CodeValidationResult.invalid,
      };
    }
    return CodeValidationResult.invalid;
  }

  @override
  Future<void> resendCode(VerificationPurpose purpose) async {
    await _client.functions.invoke(
      'verification-resend',
      body: {'purpose': purpose.name},
    );
  }
}