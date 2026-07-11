# Implementation Plan — Validation & Warning Messages

> Fourth companion file, spanning the three build plans:
> `IMPLEMENTATION_PLAN.md` (Wellness Journal), `IMPLEMENTATION_PLAN_HOMEPAGE.md`
> (Homepage & Trip Timeline), and `IMPLEMENTATION_PLAN_ENHANCEMENTS.md`.
> Read `CLAUDE.md` first for project context.
>
> **Purpose:** consolidate every input validation and user-facing warning into
> one reference, so validation is consistent instead of scattered.
>
> **Guiding principle — proportionate validation.** Enforce the rules below and
> prevent genuinely broken data, but do NOT add validation beyond this list.
> Over-validation (nagging, rejecting reasonable input, unnecessary required
> fields) is a usability harm. If a case isn't covered here, prefer permissive
> behaviour and flag it rather than inventing a new rule.

---

## Confirmed Validation Rules (agreed — implement exactly these)

These were explicitly decided. Do not tighten, loosen, or add to them without
flagging.

### Trip

| Field / Rule | Validation | On failure |
|---|---|---|
| Title | **Required**, max **100** chars | Inline error, block save |
| Start / End dates | End date **>= start date** | Inline error, block save |
| Date overlap | New/edited trip must **not overlap** an existing trip of the same user (inclusive rule; exclude the trip being edited) | Inline error naming the clashing trip, block save |
| Notes / Reminders | Optional; treat as text (see journal cap note below) | — |
| Cover photo | Optional | — |

### Journal Entry

| Field / Rule | Validation | On failure |
|---|---|---|
| Content | Must have **title OR body** (at least one non-empty; not both required) | Inline error, block save |
| Title | Max **100** chars | Inline error / prevent over-typing |
| Body | Max **5000** chars | Inline error / prevent over-typing |
| Entry date | Must fall **within the trip's [startDate, endDate]** | Block save / reject |
| Future date | **No future entries** — entry date cannot be after today (decision #4) | Action hidden on future days; validation is the backstop |

> **"Journal is 50k" cap:** the overall journal text budget per entry is 50,000
> characters. Body is capped at 5,000; if the entry aggregates multiple text
> areas (body + any additional text), the combined journal text must not exceed
> **50,000** chars. Enforce the 5,000 body cap at the field level and the 50,000
> cap as the hard ceiling for the entry's total text.

### Meal

| Field / Rule | Validation | On failure |
|---|---|---|
| Name | **Required** | Inline error, block adding/saving the meal |
| Calories | May be **0**; if left blank, **default to 0** automatically (do not force the user to type it) | Auto-fill 0, no error |
| Calories value | Must be a **non-negative number** (>= 0) | Inline error if a negative/invalid value is entered |

### Steps (manual entry)

| Field / Rule | Validation | On failure |
|---|---|---|
| Steps | **Trust the user**; soft cap at **100,000** | If > 100,000, reject with a gentle "That seems too high — please check." |
| Steps value | Non-negative integer | Inline error on negative/invalid |

### Photos (per journal entry)

| Field / Rule | Validation | On failure |
|---|---|---|
| Count | At most **5** photos per entry | Block adding a 6th, show "You can add up to 5 photos per entry." |
| File size | Max **32 MB** per photo | Reject the file, show "This image is too large (max 32 MB)." |

### Calories display (dashboard)

- Show **Calories Eaten** and **Calories Burned** as **two separate numbers**.
  **No net (eaten − burned) calculation.** (Confirmed in enhancements plan.)
- If `caloriesBurned` is null (no health data), show a placeholder
  ("— (no health data)"), never 0 or a crash.

---

## Warning / Confirmation Messages

User-facing messages, grouped by type. Keep copy neutral and clear. Adapt exact
wording to the team's tone, but preserve the intent.

### Destructive-action confirmations (require explicit confirm)

- **Delete trip:** "Delete this trip and its [N] journal entries? This cannot be
  undone." → cascade-delete on confirm (decision #3). Show the real entry count.
- **Delete journal entry:** "Delete this journal entry? This cannot be undone."
- **Delete a meal / photo from an entry:** lightweight — allow undo or a simple
  confirm; do not over-prompt for small removals.
- **Deactivate account** (User Management module, if in your scope): confirm
  identity / intent before proceeding.

### Blocking validation errors (prevent save, shown inline)

- Trip title empty → "Please enter a trip title."
- Trip title > 100 → "Trip title must be 100 characters or fewer."
- End before start → "End date must be on or after the start date."
- Overlapping trip → "You already have a trip during these dates
  ([existing trip title], [date range]). Please choose different dates."
- Entry with no title and no body → "Please add a title or write something in
  your entry."
- Entry title > 100 → "Title must be 100 characters or fewer."
- Entry body > 5000 → "Entry body must be 5,000 characters or fewer."
- Entry total text > 50,000 → "This entry is too long. Please shorten it."
- Entry date outside trip range → "This date is outside your trip dates."
- Meal with no name → "Please enter a meal name."
- Negative calories/steps → "Please enter a valid number."

### Soft warnings (allow proceed, just caution)

- Steps > 100,000 → "That step count seems unusually high — please check."
- Photo count at limit → "You can add up to 5 photos per entry."
- Photo too large → "This image is too large (max 32 MB)."

### Graceful-degradation notices (informational, never blocking)

- Health permission denied / unavailable → do NOT block. Show a small note like
  "Connect a health app to auto-fill steps and calories" and keep steps /
  calories-burned manually editable. The user can complete everything by hand.
- No trips yet (homepage) → friendly empty state + "Create your first trip."
- Trip has no entries yet → timeline shows empty day slots, not an error.
- Offline / save failure (once Supabase lands) → "Couldn't save — check your
  connection and try again." Preserve the user's input; don't lose their entry.

### Character-limit UX

- Prefer **live character counters** near the limit (e.g. "84 / 100") and gently
  prevent over-typing, rather than letting the user type 200 chars then rejecting
  on save. Better feedback, less frustration.

---

## Where Validation Lives (architecture)

Keep validation layered so it's testable and consistent:

- **Model-level:** basic invariants (non-negative calories/steps, meal name
  present, date normalisation) — validated in the model or a small validator
  helper so both mock and Supabase paths get the same rules.
- **Controller-level (Riverpod):** cross-record rules that need other data —
  trip overlap check (needs the user's other trips), entry-date-within-trip
  (needs the trip). These can't live purely in the widget.
- **UI-level:** immediate feedback — required-field checks, character counters,
  inline error text, disabling the save button until valid.

Do NOT put the overlap or entry-date-range logic only in the UI — it must be in
the controller so it holds regardless of how the save is triggered.

---

## Test Checklist (add to existing test suites)

- Trip: empty title rejected; 101-char title rejected; 100 accepted; end-before-
  start rejected; overlap cases (exact, partial, envelope, touching-endpoints =
  overlap); editing a trip to its own dates is NOT a self-overlap.
- Entry: no-title-no-body rejected; title-only accepted; body-only accepted;
  101-char title rejected; 5001-char body rejected; >50k total rejected; date
  outside trip range rejected; future date rejected.
- Meal: no-name rejected; blank calories → defaults to 0; negative calories
  rejected; 0 calories accepted.
- Steps: negative rejected; 100,001 warned/rejected; normal value accepted.
- Photos: 6th photo blocked; 33 MB file rejected; 5 photos + valid sizes
  accepted.
- Calories display: two separate totals; null burned shows placeholder; no net
  field exists anywhere.
- Delete confirmations fire with correct entry counts.

---

## Cross-Cutting Notes

- **Proportionate, not maximal.** The rules above are the complete intended set.
  Resist adding more (extra required fields, stricter formats, arbitrary limits)
  — if a new case appears, flag it for a human decision instead of inventing a
  rule.
- **Never lose user input on a validation failure** — keep what they typed and
  point them at the problem; don't clear the form.
- **Graceful degradation over hard blocks** for anything device/permission
  related (health data, camera, photos) — the app must remain fully usable by
  hand.

---

*Keep this beside the other three plans in the repo root. Update as decisions
firm up.*
