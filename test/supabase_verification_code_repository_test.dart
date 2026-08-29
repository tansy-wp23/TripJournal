import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tripjournal/data/supabase_verification_code_repository.dart';
import 'package:tripjournal/data/verification_code_repository.dart';
import 'package:tripjournal/models/verification_code.dart';

const _baseUrl = 'https://example.supabase.co';

SupabaseVerificationCodeRepository _repository(MockClient httpClient) {
  final client = SupabaseClient(
    _baseUrl,
    'anon-key',
    httpClient: httpClient,
    accessToken: () async => 'test-token',
  );
  return SupabaseVerificationCodeRepository(client);
}

http.Response _jsonResponse(
  Object body, {
  required http.BaseRequest request,
  int statusCode = 200,
}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
    request: request,
  );
}

void main() {
  group('sendCode', () {
    test('invokes verification-send with the purpose', () async {
      final repository = _repository(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/functions/v1/verification-send');
          expect(jsonDecode(request.body), {'purpose': 'reactivation'});
          return _jsonResponse({'ok': true}, request: request);
        }),
      );

      await repository.sendCode(VerificationPurpose.reactivation);
    });

    test('maps a 429 response to rateLimited', () async {
      final repository = _repository(
        MockClient((request) async {
          return _jsonResponse(
            {'error': 'A code was sent too recently.'},
            request: request,
            statusCode: 429,
          );
        }),
      );

      await expectLater(
        repository.sendCode(VerificationPurpose.reactivation),
        throwsA(
          isA<SendCodeException>()
              .having((e) => e.kind, 'kind', SendCodeFailureKind.rateLimited),
        ),
      );
    });

    test('maps a 500 response to serverError', () async {
      final repository = _repository(
        MockClient((request) async {
          return _jsonResponse(
            {'error': 'Internal server error'},
            request: request,
            statusCode: 500,
          );
        }),
      );

      await expectLater(
        repository.sendCode(VerificationPurpose.reactivation),
        throwsA(
          isA<SendCodeException>()
              .having((e) => e.kind, 'kind', SendCodeFailureKind.serverError),
        ),
      );
    });

    test('maps a 400 response to other', () async {
      final repository = _repository(
        MockClient((request) async {
          return _jsonResponse(
            {'error': 'purpose must be ...'},
            request: request,
            statusCode: 400,
          );
        }),
      );

      await expectLater(
        repository.sendCode(VerificationPurpose.reactivation),
        throwsA(
          isA<SendCodeException>()
              .having((e) => e.kind, 'kind', SendCodeFailureKind.other),
        ),
      );
    });

    test('maps a network failure to networkError', () async {
      final repository = _repository(
        MockClient((request) async {
          throw http.ClientException('Connection refused');
        }),
      );

      await expectLater(
        repository.sendCode(VerificationPurpose.reactivation),
        throwsA(
          isA<SendCodeException>()
              .having((e) => e.kind, 'kind', SendCodeFailureKind.networkError),
        ),
      );
    });
  });

  group('validateCode', () {
    test('invokes verification-validate and maps valid', () async {
      final repository = _repository(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/functions/v1/verification-validate');
          expect(jsonDecode(request.body), {
            'purpose': 'reactivation',
            'code': '123456',
          });
          return _jsonResponse({'result': 'valid'}, request: request);
        }),
      );

      final result = await repository.validateCode(
        code: '123456',
        purpose: VerificationPurpose.reactivation,
      );

      expect(result, CodeValidationResult.valid);
    });

    test('maps expired result', () async {
      final repository = _repository(
        MockClient((request) async {
          return _jsonResponse({'result': 'expired'}, request: request);
        }),
      );

      final result = await repository.validateCode(
        code: '123456',
        purpose: VerificationPurpose.reactivation,
      );

      expect(result, CodeValidationResult.expired);
    });

    test('maps invalid and not_found to invalid', () async {
      for (final serverResult in ['invalid', 'not_found']) {
        final repository = _repository(
          MockClient((request) async {
            return _jsonResponse({'result': serverResult}, request: request);
          }),
        );

        final result = await repository.validateCode(
          code: '123456',
          purpose: VerificationPurpose.reactivation,
        );

        expect(result, CodeValidationResult.invalid,
            reason: 'server result "$serverResult" should map to invalid');
      }
    });

    test('maps locked result to locked', () async {
      final repository = _repository(
        MockClient((request) async {
          return _jsonResponse({'result': 'locked'}, request: request);
        }),
      );

      final result = await repository.validateCode(
        code: '123456',
        purpose: VerificationPurpose.reactivation,
      );

      expect(result, CodeValidationResult.locked);
    });

    test('maps a missing result field to invalid', () async {
      final repository = _repository(
        MockClient((request) async {
          return _jsonResponse({}, request: request);
        }),
      );

      final result = await repository.validateCode(
        code: '123456',
        purpose: VerificationPurpose.reactivation,
      );

      expect(result, CodeValidationResult.invalid);
    });
  });
}
