# Implementation Plan — UX Polish & AI Food Detection

> Sixth companion file. Builds on the prior five plans (`IMPLEMENTATION_PLAN.md`,
> `_HOMEPAGE`, `_ENHANCEMENTS`, `_VALIDATION`, `_UX_AI`). Read `CLAUDE.md` first.
>
> **Purpose:** six confirmed changes:
> 1. Portion size **scales the calorie estimate** (editable suggestion)
> 2. **AI food image detection** — optional photo → detect food + calories
>    (vision model, mocked now; result is an editable pre-fill)
> 3. Photo **thumbnails** show image content in a square box (not filename)
> 4. Each entry within a day = a **distinct, clearly-tappable card**, visually
>    separated from the day container
> 5. **Save confirmation** dialog (prevent accidental save)
> 6. **Discard-changes guard** on back when the form is dirty

---

## 1. Portion Size Scales the Calorie Estimate

Refines the portion feature from `_UX_AI` plan: portion should actually adjust
the calorie number, not just record context.

- Keep `PortionSize { small, regular, large }` on `Meal`.
- Define a multiplier map (tune later): small ×0.7, regular ×1.0, large ×1.4.
- **Behaviour (decision b — suggested, not forced):**
  - When the user sets/changes portion, compute a **suggested** calorie value
    from the base estimate × multiplier and **auto-fill** it into the calories
    field.
  - The value remains **fully editable** — the user can override the suggestion
    (they may know the real figure). Do not lock it.
- Display stays estimate-framed: "~600 kcal", descriptive, not a target.
- Update any calorie-sum logic (`caloriesEaten`) to use the final (possibly
  overridden) per-meal value.

---

## 2. AI Food Image Detection (optional, editable pre-fill)

Tutor-requested. **Accuracy is explicitly NOT a goal** — so the detected result
is always a pre-fill the user confirms/edits, never a final value. This keeps it
consistent with the estimate/editable approach and makes "it guessed wrong" a
non-issue.

### Optional, not forced
- The user **may** add a food photo to auto-detect name + calorie estimate, OR
  **skip the photo entirely** and type the meal details manually. The photo path
  is a convenience, never required. Manual entry must always work on its own.

### Interface — `lib/features/journal/ai/food_detection_service.dart`
```dart
class DetectedFood {
  final String name;
  final int estimatedCalories;
}
abstract class FoodDetectionService {
  Future<DetectedFood?> detectFromImage(String imagePath); // null if it can't detect
}
```
- `MockFoodDetectionService` — returns a fixed plausible result (e.g.
  name "Nasi lemak", ~600 kcal) regardless of input. Use by default
  (build/emulator, no API key).
- Real impl (`OpenAiFoodDetectionService` / `GeminiFoodDetectionService`) —
  DEFERRED to the real-AI phase. Requires a **vision-capable model**
  (GPT-4o-class or Gemini — both accept images), NOT a plain text call. Sends
  the image, parses back a food name + calorie estimate.

### Flow in the meal add form
1. User optionally taps "Detect from photo" → picks/takes a photo
   (`image_picker`, reuse from `_ENHANCEMENTS`).
2. Call `detectFromImage` → show a brief loading state.
3. On success, **pre-fill** the meal name + calories fields with the detected
   values. User reviews, adjusts portion, edits anything, then saves the meal.
4. On failure/null, don't block — let the user fill the fields manually.
- The detected calories still flow through the portion scaling in §1 and remain
  editable. Keep the "~X kcal (estimate)" framing.

### Notes
- Vision-model calls cost more than text — fine for a course demo; note it for
  the proposal's cost/tech section.
- Flag in the proposal that AI detection is a convenience feature and values are
  estimates the user confirms (honest framing).

---

## 3. Photo Thumbnails (square, show image content)

Currently photos display as a filename (e.g. "36.png"), which is useless to the
user. Render the actual image.

- In the entry create/edit screen and entry detail, show each attached photo as
  a **square thumbnail** displaying the image content (load from the local file
  path in `photoPaths`).
- Use a fitted/cropped square (e.g. `BoxFit.cover` in a fixed-size square) so
  varied aspect ratios look tidy in a row/grid.
- Include a small remove ("×") affordance on each thumbnail (respecting the
  5-photo / 32 MB rules from `_VALIDATION`).
- Handle a missing/corrupt file gracefully (placeholder box, not a crash).

---

## 4. Entry Tiles — Distinct & Clearly Tappable Within a Day

Problem (from screenshot): multiple entries under a day blend into the day
container, giving no signal they're individually clickable.

- Render **each entry as its own distinct card/tile** inside the day group:
  - Visual separation from the day container: its own background/surface,
    border or elevation, and spacing between tiles.
  - A clear tap affordance — e.g. a trailing chevron (›) — signalling "open".
  - Show the entry's snippet + quick stats (steps · mood) on the tile.
- The **day** remains the grouping header/container; **entries** are the
  clearly-separated, tappable items within it.
- Tap an entry tile → Entry Detail / edit (existing screen).
- Keep the day's "＋ Add entry" action visually distinct from the entry tiles
  (it's an action, not an entry), and available on today/past days per
  `_HOMEPAGE` rules.

---

## 5. Save Confirmation (prevent accidental save)

Decision (b): confirm after Save is pressed.

- On the entry create/edit screen, pressing **Save** first runs validation
  (per `_VALIDATION`). If valid, show a confirmation dialog:
  **"Save changes to this entry?"** → Confirm / Cancel.
- On **Confirm** → persist, then run the stay-on-screen + AI-suggestion flow
  from `_UX_AI` (save first, generate advice, show in place, don't navigate
  away).
- On **Cancel** → dismiss the dialog, stay in the editor with input intact.
- Rationale: guards against accidental saves; also makes the (potentially
  AI-triggering) save a conscious action.

---

## 6. Discard-Changes Guard on Back (only when dirty)

Symmetry with §5: protect the user from *losing* edits too.

- **Track a "dirty" flag** — true once the user modifies any field on the entry
  (title, body, mood, meals, photos, health fields), false on a pristine
  open or right after a successful save.
- When the user presses **back** (app bar back or system back):
  - If **dirty** → prompt: **"Discard changes?"** → Discard / Keep editing.
    - Discard → leave without saving.
    - Keep editing → stay in the editor.
  - If **NOT dirty** (nothing changed) → just leave, **no prompt**. Do not nag
    when there's nothing to lose (avoid over-confirming).
- Implement via a back-intercept (e.g. `PopScope`/`WillPopScope`) on the entry
  editor.

### Combined pattern (the point of 5 + 6)
- **Save → "Save changes?"** (confirm you want to keep them)
- **Back with unsaved edits → "Discard changes?"** (confirm you want to lose them)
- No way to accidentally commit OR accidentally lose edits; no nagging when the
  form is clean.

---

## Suggested Build Order for Claude Code

```
Phase 1 → Portion scaling: multiplier map; on portion change auto-fill a
          suggested (editable) calorie value; feed final value into caloriesEaten.
Phase 2 → FoodDetectionService interface + MockFoodDetectionService; "Detect from
          photo" optional flow in meal add form → pre-fill name+calories (editable);
          manual entry still fully works; real vision-model impl deferred.
Phase 3 → Photo thumbnails: square image-content thumbnails (BoxFit.cover) in
          entry create/edit + detail; remove affordance; corrupt-file placeholder.
Phase 4 → Entry tiles: render each entry as a distinct, separated, tappable card
          within the day group (border/elevation/spacing + chevron); keep
          "＋ Add entry" visually distinct.
Phase 5 → Save confirmation dialog on Save (then stay-on-screen + AI suggestion).
Phase 6 → Dirty-tracking + discard-changes guard on back (PopScope); no prompt
          when clean.
Phase 7 → Tests: portion scales & remains overridable; mock detection pre-fills
          editable fields and manual-only path works; thumbnail renders/placeholder;
          entry tile is a tap target opening detail; Save shows confirm then saves;
          back prompts discard only when dirty, leaves silently when clean.
```

Run + commit after each phase. Mock-first: food detection uses the mock service;
the real vision-model swap is a later phase.

---

## Cross-Cutting Notes

- **AI detection is optional and its output is an editable estimate** — never
  force the photo, never treat detected values as final. Manual entry always
  works standalone.
- **Vision model, not text**, for the real detection impl (accepts images).
  Mock it until the real-AI phase.
- **Don't over-confirm:** Save gets a confirm dialog (intentional), Back only
  prompts when the form is actually dirty. A clean form leaves silently.
- **Never lose input:** Cancel/Keep-editing preserve the form; discard is only
  on explicit user choice.
- Calories stay **estimates, editable, descriptive** — portion scaling and AI
  detection both feed a value the user can override, not a fixed target.

---

*Keep this beside the other five plans in the repo root. Update as decisions
firm up.*
