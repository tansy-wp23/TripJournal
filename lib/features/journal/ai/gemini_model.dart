/// Single source of truth for which Gemini model the real AI services call.
///
/// Free-tier quota is granted per model *name*, not per API key, so this
/// constant is a quota decision as much as a capability one. Two versions of
/// that lesson so far:
///
/// - `gemini-2.0-flash` (the original pin) silently regressed to 429
///   `RESOURCE_EXHAUSTED` (`limit: 0`) once Google wound its free tier down,
///   even with billing enabled.
/// - `gemini-flash-latest` (the alias that replaced it) then exhausted its
///   *daily* request cap in ordinary use. Probing showed the alias returning
///   429 while `gemini-3.7-flash` — the very model it resolves to — answered
///   normally, so the alias carries its own quota bucket rather than sharing
///   the concrete version's. Pinning a version is therefore the fix, not a
///   workaround.
///
/// `gemini-2.5-flash` is NOT an option despite still appearing in
/// `ListModels`: calling it returns 404 "no longer available to new users",
/// naming `gemini-3.6-flash` as its replacement. Listed does not mean
/// callable — verify with a real request before pinning anything here.
///
/// The cost of pinning a version instead of an alias is that this will not
/// follow Google forward on its own; when 3.6 is retired the symptom is one
/// of the two failures above. Check
/// https://ai.google.dev/gemini-api/docs/models for current model names —
/// they change — and swap the value here. Must stay vision-capable since
/// [GeminiFoodDetectionService] sends inline image data.
const geminiModel = 'gemini-3.6-flash';
