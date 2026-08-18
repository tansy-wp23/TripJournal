import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tripjournal/features/journal/ai/gemini_retry.dart';

void main() {
  final url = Uri.parse('https://example.invalid/v1beta/models/x:generateContent');

  // The backoff is real time in production; tests inject a no-op so a
  // three-attempt case stays instant instead of costing seconds.
  Future<void> noSleep(Duration _) async {}

  test('returns a 200 without retrying', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{"ok":true}', 200);
    });

    final response = await postGeminiWithRetry(client, url, '{}', sleep: noSleep);

    expect(response.statusCode, 200);
    expect(calls, 1);
  });

  test('retries a 503 and returns the first success', () async {
    // The live failure this exists for: gemini-flash-latest returning
    // "experiencing high demand" for one call and succeeding on the next.
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      if (calls < 3) {
        return http.Response('{"error":{"code":503}}', 503);
      }
      return http.Response('{"ok":true}', 200);
    });

    final response = await postGeminiWithRetry(client, url, '{}', sleep: noSleep);

    expect(response.statusCode, 200);
    expect(calls, 3);
  });

  test('gives up after the attempt budget and returns the last error response',
      () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{"error":{"code":503}}', 503);
    });

    final response = await postGeminiWithRetry(
      client,
      url,
      '{}',
      attempts: 3,
      sleep: noSleep,
    );

    // Returned rather than thrown, so callers keep their existing
    // "fall back to manual entry" behaviour unchanged.
    expect(response.statusCode, 503);
    expect(calls, 3);
  });

  test('does not retry a 400 — a bad request fails identically every time',
      () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{"error":{"code":400}}', 400);
    });

    final response = await postGeminiWithRetry(client, url, '{}', sleep: noSleep);

    expect(response.statusCode, 400);
    expect(calls, 1);
  });

  test('does not retry a 403, so a revoked key fails fast', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{"error":{"code":403}}', 403);
    });

    await postGeminiWithRetry(client, url, '{}', sleep: noSleep);

    expect(calls, 1);
  });

  test('retries a network failure and can still succeed', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      if (calls == 1) throw const SocketExceptionStub();
      return http.Response('{"ok":true}', 200);
    });

    final response = await postGeminiWithRetry(client, url, '{}', sleep: noSleep);

    expect(response.statusCode, 200);
    expect(calls, 2);
  });

  test('rethrows a network failure once attempts are spent', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      throw const SocketExceptionStub();
    });

    await expectLater(
      postGeminiWithRetry(client, url, '{}', attempts: 2, sleep: noSleep),
      throwsA(isA<SocketExceptionStub>()),
    );
    expect(calls, 2);
  });

  test('backs off exponentially between attempts', () async {
    final delays = <Duration>[];
    final client = MockClient((_) async => http.Response('{}', 503));

    await postGeminiWithRetry(
      client,
      url,
      '{}',
      attempts: 3,
      initialDelay: const Duration(milliseconds: 100),
      sleep: (d) async => delays.add(d),
    );

    // Two waits for three attempts, doubling each time.
    expect(delays, const [
      Duration(milliseconds: 100),
      Duration(milliseconds: 200),
    ]);
  });
}

/// Stand-in for a transport failure; the helper must treat any thrown error
/// the same way it treats a retryable status.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
