/// Single source of truth for which Gemini model the real AI services call.
///
/// Free-tier quota is granted per model, not per API key, and Google
/// periodically retires model versions — a hardcoded `gemini-2.0-flash`
/// silently regressed to 429 `RESOURCE_EXHAUSTED` (`limit: 0`) even with
/// billing enabled. `gemini-flash-latest` is Google's maintained alias for
/// the current recommended flash model, so it tracks whichever concrete
/// version currently has quota instead of pinning to one that can be
/// deprecated later.
///
/// If this ever starts failing again, check
/// https://ai.google.dev/gemini-api/docs/models for current model names —
/// they change — and swap the value here. Must stay vision-capable since
/// [GeminiFoodDetectionService] sends inline image data.
const geminiModel = 'gemini-flash-latest';
