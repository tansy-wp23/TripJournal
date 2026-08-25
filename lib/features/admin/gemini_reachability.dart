import 'package:http/http.dart' as http;

/// PB-14's real Gemini reachability check (Phase 21,
/// `docs/admin/PROGRESS.md`) — calls the `ListModels` endpoint, not
/// `generateContent`. Deliberately not the same endpoint the three real AI
/// services use: this app has already been burned twice by Gemini free-tier
/// quota exhaustion (see `gemini_model.dart`'s own doc comment), and
/// `ListModels` is a lightweight metadata call, not a generation request —
/// checking "is the API reachable and this key valid" shouldn't cost the
/// same quota a real advice/detection/summary call would.
///
/// Returns `true` if the API answered with a successful response, `false`
/// otherwise (bad key, network failure, non-200 status) — this function
/// never throws.
Future<bool> checkGeminiReachability(String apiKey, {http.Client? client}) async {
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient
        .get(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey'))
        .timeout(const Duration(seconds: 10));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    if (client == null) httpClient.close();
  }
}
