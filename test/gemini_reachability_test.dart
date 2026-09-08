import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/gemini_reachability.dart';
import 'package:tripjournal/features/journal/ai/gemini_function_invoker.dart';

void main() {
  group('checkGeminiReachability', () {
    test('reports a configured, reachable key', () async {
      String? seenAction;
      final health = await checkGeminiReachability(
        invoke: (action, _) async {
          seenAction = action;
          return {'ok': true, 'configured': true};
        },
      );

      expect(seenAction, 'health');
      expect(health.configured, isTrue);
      expect(health.reachable, isTrue);
    });

    test('reports a configured key that did not answer', () async {
      final health = await checkGeminiReachability(
        invoke: (_, _) async => {'ok': false, 'configured': true},
      );

      expect(health.configured, isTrue);
      expect(health.reachable, isFalse);
    });

    test('reports a server with no key set at all', () async {
      final health = await checkGeminiReachability(
        invoke: (_, _) async => {'ok': false, 'configured': false},
      );

      expect(health.configured, isFalse);
      expect(health.reachable, isFalse);
    });

    test('never throws when the function itself is unreachable', () async {
      final health = await checkGeminiReachability(
        invoke: (_, _) async =>
            throw const GeminiProxyException('down', code: 'provider_error'),
      );

      expect(health.configured, isFalse);
      expect(health.reachable, isFalse);
    });

    test('treats a malformed answer as unavailable', () async {
      final health = await checkGeminiReachability(
        invoke: (_, _) async => {'ok': 'yes'},
      );

      expect(health.reachable, isFalse);
    });
  });
}
