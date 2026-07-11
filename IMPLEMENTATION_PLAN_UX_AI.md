# Implementation Plan — UX Refinements & Holistic AI Advice

> Fifth companion file. Builds on: `IMPLEMENTATION_PLAN.md` (Wellness Journal),
> `IMPLEMENTATION_PLAN_HOMEPAGE.md` (Homepage & Trip Timeline),
> `IMPLEMENTATION_PLAN_ENHANCEMENTS.md` (health/photos/etc.), and
> `IMPLEMENTATION_PLAN_VALIDATION.md`. Read `CLAUDE.md` first.
>
> **Purpose:** four confirmed refinements:
> 1. Portion size on meal entry (improves calorie honesty)
> 2. Holistic daily AI advice (food + steps + mood, not food only)
> 3. Stay on the entry screen after saving; show the AI suggestion in place
> 4. Homepage active-trip card: whole card tappable → opens trip; stats inside
>    are display-only (not a separate tap target, but don't block the card tap)

---

## 1. Portion Size on Meal Entry

Portion is the single biggest source of calorie variance ("nasi lemak" can be
400 or 900+ kcal). Capturing portion lets the user control accuracy themselves —
which is the only place accuracy can come from, since only they know what they
ate. This is cheaper and more honest than photo recognition (which has the same
accuracy problem anyway).

### `Meal` model change — `lib/models/meal.dart`
Add:
| Field | Type | Notes |
|---|---|---|
| `portion` | PortionSize (enum) | small / regular / large (default: regular) |

- Enum `PortionSize { small, regular, large }`.
- Optionally store a multiplier mapping (small ×0.7, regular ×1.0, large ×1.4 —
  team can tune) IF you auto-scale calorie estimates. If calories are purely
  user-entered, portion is still recorded as context and shown on the meal.
- Update `fromJson`/`toJson`/`copyWith` and mock seed data.

### UI
- Meal add/edit form: a portion selector (segmented control or dropdown),
  defaulting to "regular".
- Display the portion on the meal row (e.g. "Nasi lemak · large · ~600 kcal").

### Honesty framing (carry over from prior decisions)
- Show calories as an **estimate**: "~600 kcal", not "600 kcal".
- Calories remain **descriptive, not a target/goal**. No deficit framing.

---

## 2. Holistic Daily AI Advice (food + steps + mood)

Broaden the existing food-advice feature from food-only to a **daily wellbeing
summary** that considers the whole day: meals, step count, and mood together.

### Interface change — `lib/features/journal/ai/`
Rename/repurpose the existing `FoodAdviceService` to a broader
`DailyAdviceService` (keep the interface pattern):
```dart
abstract class DailyAdviceService {
  Future<String> adviceFor({
    required List<Meal> meals,
    required int? steps,
    required Mood mood,
    int? caloriesEaten,
    int? caloriesBurned,
  });
}
```
- `MockDailyAdviceService` — rule-based canned advice (build/emulator), covering
  the cases below. No network.
- Real impl (`OpenAiDailyAdviceService` / `GeminiDailyAdviceService`) —
  DEFERRED to the later AI phase; same interface. Uses OpenAI or Gemini text API
  (see `CLAUDE.md`). Prompt includes the day's meals, steps, mood, calorie
  figures; returns supportive text.

### Advice logic (what it should cover)
- **Food:** comment on the day's meals / calorie intake (gentle, estimate-aware).
- **Steps low:** encourage light movement ("a short walk might feel good").
- **Steps very high:** acknowledge the activity; suggest rest/hydration.
- **Mood low / bad:** suggest something restorative — a walk, rest, reaching out
  to someone. Supportive, optional-sounding.
- **Mood tired:** suggest resting early / winding down.
- Combine into one short, friendly paragraph — not a list of commands.

### CRITICAL — tone & safety constraints (do NOT violate)
- **Supportive and non-prescriptive.** The AI **suggests and encourages**; it
  never diagnoses, never issues medical/clinical instructions, never pressures.
- **Mood advice especially:** gentle wellbeing suggestions only
  ("feeling low? a short walk or talking to someone close might help"). Never
  clinical language, never "you should" in a directive medical sense, never
  anything that could read as mental-health diagnosis or treatment.
- **No disordered-eating-adjacent framing:** do not tell the user to restrict,
  skip meals, hit calorie targets, or "make up for" eating with exercise. Keep
  food advice descriptive and balanced.
- Mood data is sensitive (PDPA + wellbeing). Handle it with care in the prompt
  and the output. Note this feature in the proposal's ethics/privacy section.
- The real LLM prompt MUST encode these constraints (system prompt) so the
  model stays supportive and non-prescriptive.

---

## 3. Stay on Entry Screen After Save + Show AI Suggestion In Place

Currently saving an entry returns the user to the homepage, which hides the AI
suggestion — the payoff of the whole feature. Fix the flow so the user stays and
sees the advice.

### New save flow (create/edit entry screen)
1. User taps Save.
2. Validate (per validation plan). If invalid, stay and show errors.
3. Persist the entry via the repository (existing).
4. **Do NOT navigate away.** Remain on the entry screen.
5. Trigger `DailyAdviceService.adviceFor(...)` with the saved day's data.
6. Show a **loading indicator** in the advice area while it generates (it's an
   API call in the real impl; mock can be near-instant but still show the state
   briefly for consistency).
7. Render the returned advice text in an **AI Suggestion** section on the same
   screen. Store it in `HealthLog.aiAdvice` (existing field).
8. The screen now reflects a saved state (e.g. Save button → "Saved" / an edit
   affordance), with the suggestion visible. User leaves manually (back button)
   when ready.

### Details
- Handle advice-generation failure gracefully: if the AI call fails, the entry
  is still saved — show a small "Couldn't generate suggestion, tap to retry"
  rather than losing the save or blocking the user.
- If the user edits and re-saves, regenerate the advice for the updated data.
- Keep the transition smooth (no full-screen reload that loses scroll position).

---

## 4. Homepage Active-Trip Card Navigation

Fix the interaction so the most prominent element behaves as users expect.

### Behaviour
- The **entire active-trip hero card is tappable** → opens that trip's view
  (the day-by-day journal timeline). This is the primary way into the active
  trip.
- The **wellness stats inside the card** (steps, calories eaten, calories
  burned, mood) are **display-only**:
  - They are NOT a separate tap target / do NOT navigate anywhere of their own.
  - They do NOT block the card's tap — **decision (b)**: tapping anywhere on the
    card, stats area included, opens the trip. No dead zones.
- Implementation note: make the whole card one tap target (e.g. a single
  InkWell/GestureDetector wrapping the card). Render the stats as plain,
  non-interactive widgets inside it — do not wrap them in their own tap
  handlers. This yields "tap anywhere → open trip" with the stats as passive
  content.

### Consistency
- The "Your Trips" list cards below already open their trip on tap — the active
  card now behaves the same way, so navigation is consistent across the page.
- The "Write today's entry" nudge button (from the homepage plan) remains its
  own explicit action (deep-links to create-entry for today). A tap on that
  specific button does its thing; a tap elsewhere on the card opens the trip.
  Make sure the button's tap doesn't also trigger the card tap (stop
  propagation on the button).

---

## Suggested Build Order for Claude Code

```
Phase 1 → Meal model: add PortionSize enum + portion field; update json/copyWith
          + mock data; portion selector in meal add/edit UI; show portion on row;
          calories displayed as estimate ("~X kcal").
Phase 2 → AI service: rename FoodAdviceService → DailyAdviceService with the
          broader signature; MockDailyAdviceService rule-based advice covering
          food/steps/mood cases; encode tone/safety constraints. (Real LLM impl
          stays deferred.)
Phase 3 → Save flow: on save, persist then stay on the entry screen; loading
          state; generate + render AI suggestion in place; store in aiAdvice;
          graceful failure + regenerate-on-edit.
Phase 4 → Homepage active-trip card: whole card one tap target → opens trip;
          stats non-interactive but non-blocking (decision b); ensure the
          "write today" button stops propagation.
Phase 5 → Tests: portion persisted + shown; DailyAdviceService returns advice
          for each case (low steps, high steps, bad mood, tired mood, food);
          save keeps user on screen and populates aiAdvice; card tap opens trip
          from anywhere including the stats area; write-today button doesn't
          double-trigger the card tap.
```

Run + commit after each phase. Mock-first: AI advice uses the mock service; the
real LLM swap is a later phase.

---

## Cross-Cutting Notes

- **AI advice is supportive, never prescriptive** — this is the most important
  constraint in this file. It applies to the mock rules AND the real LLM prompt.
  Food and especially mood advice must stay gentle, optional-sounding, and free
  of clinical/diagnostic or restrictive-eating language.
- **Never lose a saved entry** because advice generation failed — save first,
  advise second, degrade gracefully.
- **Calories stay estimates and stay descriptive** — portion size improves the
  estimate; it does not turn the feature into a precise or target-based tracker.
- **One tap target per card** — passive stats inside an actionable card; no dead
  zones, no competing tap targets (except the explicit "write today" button).

---

*Keep this beside the other four plans in the repo root. Update as decisions
firm up.*
