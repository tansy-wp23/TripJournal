import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls one action on the `gemini-proxy` Edge Function and returns its JSON
/// body. Mirrors `PlaceFunctionInvoker` in `lib/features/location/` — the same
/// seam, for the same reason: the services stay testable with a plain function
/// stub instead of a live Supabase client.
typedef GeminiFunctionInvoker =
    Future<Map<String, dynamic>> Function(
      String action,
      Map<String, dynamic> body,
    );

typedef SupabaseGeminiFunctionCall =
    Future<FunctionResponse> Function(
      String functionName, {
      required Map<String, dynamic> body,
    });

/// Thrown for every proxy failure. The three AI services already treat any
/// thrown error as "fall back to the mock / let the user retry", so this
/// carries a code mainly for logging and for tests to assert on.
class GeminiProxyException implements Exception {
  const GeminiProxyException(this.message, {this.code = 'provider_error'});

  final String message;
  final String code;

  @override
  String toString() => message;
}

/// The production invoker: `GEMINI_API_KEY` lives in Supabase secrets, so the
/// app never holds it — it sends its own session JWT and the function does the
/// Gemini call. `functions.invoke` attaches that JWT automatically.
GeminiFunctionInvoker get geminiFunctionInvoker => buildGeminiFunctionInvoker(
  call: (functionName, {required body}) =>
      Supabase.instance.client.functions.invoke(functionName, body: body),
);

GeminiFunctionInvoker buildGeminiFunctionInvoker({
  required SupabaseGeminiFunctionCall call,
}) {
  return (action, body) async {
    try {
      final response = await call(
        'gemini-proxy',
        body: {'action': action, ...body},
      );
      if (response.status < 200 || response.status >= 300) {
        throw _exceptionForResponse(response.status, response.data);
      }
      if (response.data is! Map) {
        throw const GeminiProxyException(
          'The AI service returned an invalid response.',
          code: 'invalid_response',
        );
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on GeminiProxyException {
      rethrow;
    } on FunctionException catch (error) {
      throw _exceptionForResponse(error.status, error.details);
    } on TimeoutException {
      throw const GeminiProxyException(
        'The AI request timed out. Please try again.',
        code: 'timeout',
      );
    } catch (_) {
      throw const GeminiProxyException(
        'The AI service is temporarily unavailable. Please try again.',
        code: 'provider_error',
      );
    }
  };
}

GeminiProxyException _exceptionForResponse(int status, Object? data) {
  final responseCode = _responseErrorCode(data);
  final code = switch (responseCode) {
    'unauthorized' ||
    'invalid_request' ||
    'payload_too_large' ||
    'timeout' ||
    'provider_error' ||
    'internal_error' => responseCode!,
    _ => switch (status) {
      400 => 'invalid_request',
      401 || 403 => 'unauthorized',
      413 => 'payload_too_large',
      408 || 504 => 'timeout',
      500 || 503 => 'internal_error',
      _ => 'provider_error',
    },
  };

  final message = switch (code) {
    'invalid_request' => 'The AI request is invalid.',
    'unauthorized' => 'Please sign in to use AI features.',
    'payload_too_large' => 'That photo is too large to analyse.',
    'timeout' => 'The AI request timed out. Please try again.',
    'internal_error' =>
      'The AI service is temporarily unavailable. Please try again.',
    _ => 'The AI service is temporarily unavailable. Please try again.',
  };
  return GeminiProxyException(message, code: code);
}

String? _responseErrorCode(Object? data) {
  if (data is! Map) return null;
  final error = data['error'];
  if (error is! Map) return null;
  final code = error['code'];
  return code is String ? code : null;
}
