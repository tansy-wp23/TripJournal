import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tripjournal/features/admin/gemini_reachability.dart';

void main() {
  group('checkGeminiReachability', () {
    test('returns true on a 200 response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, contains('/v1beta/models'));
        return http.Response('{"models": []}', 200);
      });

      final result = await checkGeminiReachability('fake-key', client: client);

      expect(result, isTrue);
    });

    test('returns false on a non-200 response (e.g. an invalid key)', () async {
      final client = MockClient((request) async {
        return http.Response('{"error": {"message": "API key not valid"}}', 400);
      });

      final result = await checkGeminiReachability('bad-key', client: client);

      expect(result, isFalse);
    });

    test('returns false, never throws, when the request itself fails', () async {
      final client = MockClient((request) async {
        throw Exception('network unreachable');
      });

      final result = await checkGeminiReachability('fake-key', client: client);

      expect(result, isFalse);
    });

    test('calls the ListModels endpoint, not generateContent — this must '
        'never cost the same quota a real AI call does', () async {
      Uri? calledUri;
      final client = MockClient((request) async {
        calledUri = request.url;
        return http.Response('{}', 200);
      });

      await checkGeminiReachability('fake-key', client: client);

      expect(calledUri?.path, endsWith('/v1beta/models'));
      expect(calledUri?.path, isNot(contains('generateContent')));
    });
  });
}
