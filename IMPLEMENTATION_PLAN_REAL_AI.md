# Implementation Plan — Real AI Integration (Gemini)

> Replaces the mock AI services with real Google Gemini calls, behind the SAME
> interfaces already in the code. Covers both AI features:
>   1. Daily wellbeing advice (food + steps + mood)  — DailyAdviceService
>   2. Food image detection (photo -> food name + calorie estimate) — FoodDetectionService
> Read `CLAUDE.md` first. This is the deferred "real-AI phase" from the earlier
> plans (`_UX_AI`, `_UX_POLISH`).
>
> **Prerequisite (done by the developer, not Claude Code):** a Gemini API key
> from Google AI Studio must exist in `.env` as `GEMINI_API_KEY`. Without it,
> keep using the mock services.

---

## Ground Rules (non-negotiable)

1. **Same interfaces, drop-in swap.** Implement the real services against the
   existing `DailyAdviceService` and `FoodDetectionService` interfaces. The UI,
   controllers, and save flow must NOT change. Swapping mock -> real is a
   one-line change in the provider/locator.
2. **Keep the mocks. Do NOT delete them.** They are the fallback for
   emulator/offline/rate-limit situations and for tests. Ideally select
   mock vs real by a config flag / `--dart-define`, defaulting to mock in
   development so tests and offline runs still work.
3. **Never lose user data on an AI failure.** The entry is saved FIRST; the AI
   call happens after. If the AI call fails (network, rate limit, bad response),
   the saved entry stays intact and the UI shows a retry option — never a crash,
   never a lost entry. (This already exists for the mock flow; preserve it.)
4. **API key from env, never hardcoded, never committed.** Read
   `GEMINI_API_KEY` via `dotenv`. Add `GEMINI_API_KEY=` to `.env.example`.
5. **Vision model for detection.** Food detection sends an IMAGE, so it needs a
   vision-capable Gemini model, not a text-only one. Advice is text-only.
6. **Supportive, non-prescriptive tone (advice).** The advice prompt MUST encode
   the wellbeing constraints already agreed: gentle and supportive, never
   clinical/diagnostic, never restrictive-eating or "make up for it with
   exercise" framing. Mood advice especially stays soft and optional-sounding.
7. **Detection output is an editable estimate.** The detected food name and
   calories PRE-FILL the meal fields and remain fully editable. Accuracy is not
   assumed (consistent with the tutor's "accuracy not important" note).

---

## 1. Dependency & Config

- Add the Gemini Dart SDK (e.g. `google_generative_ai` on pub.dev, or call the
  REST API via the existing `http` package). Let the tool resolve the current
  version; do not hardcode.
- Ensure `GEMINI_API_KEY` is loaded from `.env` (dotenv is already set up).
- Add `GEMINI_API_KEY=` to `.env.example`.
- Confirm the Android INTERNET permission is present (already added for
  Supabase) — the AI calls need network access too.

---

## 2. Real Daily Advice Service

`lib/features/journal/ai/gemini_daily_advice_service.dart` implementing the
existing `DailyAdviceService` interface.

### Behaviour
- Build a text prompt from the entry's data: meals (name, calories, portion),
  step count, mood, and the calories eaten/burned figures.
- Call a Gemini **text** model; return the generated advice string.
- On any failure (network, rate limit, empty/invalid response) -> throw or
  return a sentinel the controller already handles as "show retry"; the saved
  entry is untouched.

### Prompt constraints (encode as a system/instruction preamble)
- Produce ONE short, friendly paragraph of supportive daily wellbeing advice.
- Consider food, steps, and mood together.
- **Must NOT**: diagnose, give medical/clinical instructions, set calorie
  targets, tell the user to restrict or skip meals, or frame exercise as
  compensation for eating.
- Mood: gentle, optional-sounding suggestions only (e.g. "a short walk or
  reaching out to someone might help") — never clinical.
- Keep it concise and non-judgemental.

---

## 3. Real Food Detection Service

`lib/features/journal/ai/gemini_food_detection_service.dart` implementing the
existing `FoodDetectionService` interface.

### Behaviour
- Input: the meal photo (from the existing image picker path).
- Call a Gemini **vision** model with the image + a prompt asking it to identify
  the food and estimate calories.
- Parse the response into `DetectedFood { name, estimatedCalories }`.
  - Prompt the model to return a simple, parseable format (e.g. a short JSON
    object like `{"name": "...", "calories": 000}`) so parsing is reliable;
    strip any markdown fences before parsing.
- Return `null` (the interface's "couldn't detect" result) on failure or if the
  model can't identify a food — the UI then falls back to manual entry.

### Constraints
- Result is a PRE-FILL only: it populates the meal name + calories fields, which
  stay editable. Never treat it as final.
- The photo remains a transient input — it is NOT persisted (existing decision;
  meals have no photo column).
- Handle a non-food photo / unparseable response gracefully -> null -> manual
  entry, no crash.

---

## 4. Wiring / Swap

- In the provider/locator, choose the service implementation:
  - Default (dev/emulator/tests) -> Mock services.
  - Real Gemini services -> selected via a flag (e.g.
    `--dart-define=USE_REAL_AI=true`) or when a key is present.
- No other code changes: the entry save flow, the "detect from photo" flow, the
  loading indicators, and the retry handling all already exist and call the
  interfaces.

---

## 5. Testing

### Unit (works anywhere, use mocks)
- Advice service failure path returns the retry sentinel; entry stays saved.
- Detection parsing: valid JSON -> DetectedFood; malformed/empty -> null.
- Detection non-food/failure -> null -> manual entry path.

### Real-call verification (needs the key + network)
> Do these manually with `--dart-define=USE_REAL_AI=true` and a valid key.
1. Save an entry with meals/steps/mood -> real advice appears, tone is
   supportive and within constraints.
2. Detect from a real food photo -> plausible name + calorie estimate pre-fills,
   and remains editable.
3. Turn off network / use a bad key -> app does NOT crash; shows retry (advice)
   / manual entry (detection); saved entry intact.
4. Fire several calls quickly -> if rate-limited, failures degrade gracefully.

---

## Suggested Build Order for Claude Code

```
Phase 1 → Add Gemini dependency; load GEMINI_API_KEY from .env; update .env.example.
Phase 2 → GeminiDailyAdviceService (text) against the existing interface, with the
          constrained supportive prompt + graceful failure.
Phase 3 → GeminiFoodDetectionService (vision) against the existing interface, with
          robust response parsing -> DetectedFood, null on failure.
Phase 4 → Locator swap by flag (default mock; USE_REAL_AI selects Gemini). Keep mocks.
Phase 5 → Tests (unit with mocks) + manual real-call checklist on device.
```

Commit after each phase. The mock services remain the default so tests and
offline/emulator runs are unaffected.

---

## Report / Demo Notes

- Document this as: the AI features are built on a repository-style interface,
  developed mock-first, and swapped to real Gemini services with a one-line
  change — evidence of good architecture, not just a working feature.
- **Demo safety:** keep the mock swap available. If the key rate-limits or the
  network is flaky during the demo, switch back to the mock so the feature still
  shows. Mention the real integration is implemented and can be enabled with the
  key.
- Note the honest framing on detection: AI output is an editable estimate the
  user confirms; accuracy is not claimed. This is a strength (safe design), not
  a limitation.

---

*Keep this beside the other plans in the repo root. Requires GEMINI_API_KEY in
`.env` before the real services will function.*
