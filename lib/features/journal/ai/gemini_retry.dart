import 'package:http/http.dart' as http;

/// Statuses worth trying again. `503 UNAVAILABLE` is the one that actually
/// bites: `gemini-flash-latest` is a shared alias, and Google returns
/// "This model is currently experiencing high demand" under load — measured
/// at roughly a coin flip during one such spike, which turned a working
/// feature into an intermittently broken one with no code change. The rest
/// are the usual transient upstream failures.
///
/// Deliberately excludes 400/401/403/404: a bad key, a revoked key or a
/// retired model name fail identically on every attempt, so retrying only
/// makes the user wait longer for the same answer.
const _retryableStatuses = {429, 500, 502, 503, 504};

/// Per-attempt ceiling. The underlying client has no timeout of its own, so
/// without this a stalled connection hangs the "Detecting..." spinner
/// indefinitely rather than falling back to manual entry.
const _attemptTimeout = Duration(seconds: 30);

/// POSTs to Gemini, retrying transient failures with exponential backoff.
///
/// Returns the last response even when it is still an error, so callers keep
/// their existing "give up and let the user do it manually" behaviour — this
/// widens the window in which the call succeeds, it does not change what
/// failure means.
///
/// [sleep] is a testing seam: tests inject a no-op so the backoff costs no
/// real time.
Future<http.Response> postGeminiWithRetry(
  http.Client client,
  Uri url,
  String body, {
  int attempts = 3,
  Duration initialDelay = const Duration(milliseconds: 600),
  Future<void> Function(Duration)? sleep,
}) async {
  final wait = sleep ?? Future<void>.delayed;
  var delay = initialDelay;
  Object? lastError;

  for (var attempt = 1; attempt <= attempts; attempt++) {
    try {
      final response = await client
          .post(
            url,
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_attemptTimeout);

      final isLast = attempt == attempts;
      if (!_retryableStatuses.contains(response.statusCode) || isLast) {
        return response;
      }
    } catch (error) {
      // A network drop or timeout is as transient as a 503; only give up on
      // it once the attempts are spent.
      lastError = error;
      if (attempt == attempts) rethrow;
    }

    await wait(delay);
    delay *= 2;
  }

  // Unreachable: the loop either returns or rethrows on its final attempt.
  throw StateError('postGeminiWithRetry exhausted attempts: $lastError');
}
