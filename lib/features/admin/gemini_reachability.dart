import '../journal/ai/gemini_function_invoker.dart';

/// PB-14's real Gemini reachability check (Phase 21,
/// `docs/admin/PROGRESS.md`), now asked of the `gemini-proxy` Edge Function
/// rather than of Google directly — the app no longer holds an API key to
/// check with, which is the point (see `docs/GEMINI_PROXY_SETUP.md`).
///
/// The function answers using `ListModels`, not `generateContent`: this app
/// has been burned twice by free-tier quota exhaustion, and a health check
/// must not spend the same quota a real advice/detection/summary call would.
///
/// Returns a [GeminiHealth] describing what the *server* found. Never throws —
/// an unreachable function, an unauthenticated caller or a malformed answer
/// all read as "not reachable".
class GeminiHealth {
  const GeminiHealth({required this.configured, required this.reachable});

  /// Whether the server has a `GEMINI_API_KEY` secret set at all.
  final bool configured;

  /// Whether that key actually answered.
  final bool reachable;

  static const unavailable = GeminiHealth(
    configured: false,
    reachable: false,
  );
}

Future<GeminiHealth> checkGeminiReachability({
  required GeminiFunctionInvoker invoke,
}) async {
  try {
    final payload = await invoke('health', const {});
    final ok = payload['ok'];
    final configured = payload['configured'];
    if (ok is! bool || configured is! bool) return GeminiHealth.unavailable;
    return GeminiHealth(configured: configured, reachable: ok);
  } catch (_) {
    return GeminiHealth.unavailable;
  }
}
