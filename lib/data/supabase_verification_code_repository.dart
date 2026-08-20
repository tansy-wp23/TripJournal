import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/verification_code.dart';
import 'verification_code_repository.dart';

/// Real [VerificationCodeRepository] backed by the Phase 6 Edge Functions
/// (`verification-send`, `verification-validate`).
///
/// The Edge Functions handle code generation, hashing (never store
/// plaintext), `attempt_count` lockout, `expires_at` checks, and email
/// sending. The client only passes the purpose/code and reads the result.
///
/// Note: code *resend* reuses `sendCode` → `verification-send` (which
/// invalidates prior unused codes and sends a fresh one). The separate
/// `verification-resend` Edge Function was removed as dead code — the
/// app's "Resend code" button goes through AccountLifecycleRepository →
/// sendCode, never through a resend-specific function.
class SupabaseVerificationCodeRepository implements VerificationCodeRepository {
  SupabaseVerificationCodeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> sendCode(VerificationPurpose purpose) async {
    try {
      await _client.functions.invoke(
        'verification-send',
        body: {'purpose': purpose.name},
      );
    } on FunctionException catch (e) {
      // Map the server's HTTP status to a user-friendly failure kind. The
      // raw exception is rethrown as a SendCodeException so the UI never
      // has to know about FunctionException.
      final kind = switch (e.status) {
        429 => SendCodeFailureKind.rateLimited,
        >= 500 && <= 599 => SendCodeFailureKind.serverError,
        _ => SendCodeFailureKind.other,
      };
      throw SendCodeException(kind);
    } on http.ClientException {
      // The request never reached the server (connection refused, DNS, …).
      throw const SendCodeException(SendCodeFailureKind.networkError);
    } on SocketException {
      throw const SendCodeException(SendCodeFailureKind.networkError);
    } on TimeoutException {
      throw const SendCodeException(SendCodeFailureKind.networkError);
    }
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
}
