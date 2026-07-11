# Implementation Plan — Feature Enhancements

> Third companion file, after `IMPLEMENTATION_PLAN.md` (Wellness Journal
> module) and `IMPLEMENTATION_PLAN_HOMEPAGE.md` (Homepage & Trip Timeline).
> Read `CLAUDE.md` first for project context.
>
> **Purpose:** layer five confirmed enhancements onto the already-built journal
> + homepage work:
> 1. Health-platform integration (steps + calories burned from phone/watch)
> 2. Dual-calorie display (eaten vs burned) on the dashboard — **no net calc**
> 3. In-place meal editing
> 4. Real device photo upload (camera + gallery)
> 5. Entry timestamping mapped to a trip day
> 6. Overlap prevention (no two trips on the same dates)
>
> **Mock-first still applies** where it can. Health data and photos are
> device-dependent, so they need a real device to test — but they still sit
> behind interfaces so the app runs on mocks in an emulator.

---

## Confirmed Decisions (do NOT re-decide)

- **Calories display = Option A: show BOTH numbers separately** — "Calories
  Eaten" (from logged meals) and "Calories Burned" (from health platform).
  **DO NOT compute a net (eaten − burned).** Two honest numbers, per day and as
  trip totals. Rationale: the health platform's "burned" figure may or may not
  include BMR; a net calc built on active-energy-only would be misleading. Net
  is explicitly out of scope for now.
- **Dashboard calorie stat is descriptive, not a goal/target.** No "you should
  eat less," no deficit framing, no targets. Report the numbers neutrally. The
  AI food-advice feature (existing) handles guidance; the dashboard only
  reports. This keeps the app clear of disordered-eating-adjacent design.
- **Overlaps = disallowed.** A user cannot have two trips whose date ranges
  overlap. Enforced at trip creation/edit. This makes "active trip" provably
  unique and removes the ambiguity entirely.

---

## 1. Health Platform Integration (steps + calories burned)

Read from the phone's health platform, NOT the watch directly. The watch
(Apple Watch / Wear OS / Fitbit / Garmin / Samsung) syncs to the platform;
the app reads from the platform.

- **Package:** `health` (pub.dev) — wraps Apple HealthKit (iOS) and Health
  Connect (Android) behind one Dart API.
- **Data to read:** step count and active/total energy burned, per calendar
  day.

### Source interface — `lib/features/health/health_data_source.dart`
```dart
abstract class HealthDataSource {
  Future<int?> getStepsForDate(DateTime date);
  Future<int?> getCaloriesBurnedForDate(DateTime date); // null if unavailable
  Future<bool> requestPermissions();
  Future<bool> hasPermissions();
}
```

### Implementations
- `MockHealthDataSource` — returns plausible fixed values (build/emulator).
  Use this by default so the app runs without a device.
- `PlatformHealthDataSource` — real implementation via the `health` package.
  Swap in via the provider/locator, same pattern as the repositories.

### Behaviour rules (important)
- **Permissions:** call `requestPermissions()` before reading. Both platforms
  require explicit runtime consent for health data.
- **Graceful denial / no device:** if permission is denied OR no data is
  available, the source returns `null` and the UI **falls back to manual
  entry**. Steps and calories-burned must ALWAYS remain manually editable —
  auto-fill is a convenience, never a hard dependency. A user with no wearable
  and no granted permission must still be able to use the full app.
- **Config:** declare the health-data usage strings in the iOS `Info.plist`
  and Android manifest / Health Connect permissions. Note this is sensitive
  data under PDPA — flag it in the proposal's security/NFR section.
- **Testing:** HealthKit / Health Connect do not fully work on emulators;
  `PlatformHealthDataSource` needs a physical device to verify. Keep
  `MockHealthDataSource` wired for day-to-day development.

### How it feeds `HealthLog`
- `HealthLog.steps` — pre-fill from `getStepsForDate` when creating/editing an
  entry for a given day; user can override manually.
- Add a **new** field `caloriesBurned` (int?) to `HealthLog` (see §2). Pre-fill
  from `getCaloriesBurnedForDate`; user can override; may be null.
- Existing `calories` field is **calories EATEN** (sum of meals) — do not
  overwrite it with burned data. See §2 for the rename to avoid confusion.

---

## 2. Dual-Calorie Model + Dashboard Display (Option A)

The word "calories" is currently ambiguous. Split it cleanly.

### `HealthLog` field changes — `lib/models/health_log.dart`
| Field | Meaning | Source |
|---|---|---|
| `caloriesEaten` (rename of existing `calories`) | sum of logged meals' calories | user's meals |
| `caloriesBurned` (NEW, int?) | energy burned that day | health platform, nullable |
| `steps` | step count | health platform or manual |
| `meals` | list of meals | user |
| `aiAdvice` | AI food advice | mock/real AI |

- **Rename `calories` → `caloriesEaten`** across models, mock repo seed data,
  UI, and tests so it's unambiguous. `caloriesEaten` stays auto-summed from
  meals (existing behaviour).
- `caloriesBurned` is new, nullable (may be absent if no health data).
- Update `fromJson`/`toJson`/`copyWith` accordingly.

### `TripStats` update — `lib/features/trip/trip_summary_stats.dart`
Add to the existing stats object:
- `totalCaloriesEaten` — sum across the trip's entries.
- `totalCaloriesBurned` — sum across entries where `caloriesBurned != null`.
- Keep them as **two separate fields.** Do NOT add a net field.

### Dashboard / wellness strip display
- Show **both** as distinct stats: e.g. "Eaten: 12,400 kcal" and
  "Burned: 11,800 kcal" — per active-trip total on the homepage strip, and
  optionally per-day on the entry/timeline.
- Neutral, descriptive labels only. No net, no target, no judgement copy.
- If `caloriesBurned` is null for some/all days (no health data), show a graceful
  placeholder (e.g. "Burned: — (no health data)") rather than 0 or a crash.

---

## 3. In-Place Meal Editing

Currently meals can only be added/removed. Add editing so a user can change a
meal's name/calories/type without deleting and re-adding it.

- `Meal` already has fields (name, calories, mealType) — ensure it has a stable
  `id` (add one if missing) so edits target the right meal.
- In the Health Log sub-form (create/edit entry screen):
  - Each meal row gets an **edit** affordance (tap row or an edit icon) →
    opens the meal in an editable state (inline fields or a small dialog) →
    save updates that meal in place.
  - Keep add and remove as they are.
- On save, recompute `caloriesEaten` (the auto-sum) so the total stays correct
  after an edit.
- Controller method: `updateMeal(entryId, meal)` (or update the entry's meal
  list and persist the entry via the existing repository).

---

## 4. Real Device Photo Upload (camera + gallery)

Replace any mock/placeholder photo behaviour with real device image selection.

- **Package:** `image_picker` (pub.dev) — supports both taking a new photo
  (camera) and picking from the gallery.
- In the create/edit entry screen's photo section:
  - Offer both options (camera / gallery) when adding a photo.
  - Store the returned file path in `JournalEntry.photoPaths` (already exists).
- **Permissions:** camera and photo-library access require runtime permission
  and Info.plist / manifest usage strings. Handle denial gracefully (let the
  user proceed without a photo).
- **Testing:** camera needs a real device; gallery works in most emulators.
- For now these are **local file paths**. When Supabase lands (later phase),
  photos will be uploaded to storage and paths become URLs — keep the field a
  simple string so that swap is clean.

---

## 5. Entry Timestamping → Trip Day Mapping

Every entry carries a timestamp; the timestamp determines which trip day it
belongs to. This is what lets multiple same-day entries (decision #2) order
themselves.

- `JournalEntry.createdAt` already exists — treat it as the entry's timestamp.
  Ensure `updatedAt` is also maintained on edits.
- **Day derivation rule:**
  - Writing an entry for **today** → timestamp = `DateTime.now()`; day derived
    from it.
  - Back-filling a **past** day (allowed) → user selects the day; stamp it at a
    sensible default time (e.g. 12:00 noon that day) or let the user set the
    time. Day = the selected calendar day.
  - **Future days remain blocked** (decision #4) — no entry can be timestamped
    to a future day.
- On the timeline, group entries under a day by comparing the entry timestamp's
  calendar date to `trip.dayList`; within a day, order entries by timestamp.
- Validation: an entry's date must fall within the trip's [startDate, endDate].
  Reject entries outside the trip range.

---

## 6. Overlap Prevention (no two trips on the same dates)

Enforce that a user cannot create/edit a trip whose date range overlaps an
existing trip of theirs. This guarantees a unique active trip.

### Overlap rule
Two trips overlap if `A.startDate <= B.endDate AND B.startDate <= A.endDate`
(inclusive). Apply per `userId`, excluding the trip being edited (so editing a
trip doesn't clash with itself).

### Where to enforce — `TripController` / trip form
- On create and on edit, before saving: fetch the user's other trips and check
  the new/updated date range against each with the rule above.
- If it overlaps, **reject** with a clear inline error:
  *"You already have a trip during these dates ([existing trip title],
  [its date range]). Please choose different dates."*
- Only save when there's no overlap.

### Effect on "active trip"
- Because overlaps are impossible, at most one trip can contain today →
  `activeTrip` is unambiguous. The homepage active-trip card logic
  (from the homepage plan) now has a guaranteed-unique input; no tie-breaker
  needed.

### Test
- Overlap detection: exact same dates, partial overlap (start inside another),
  envelope (one contains another), and adjacent-but-not-overlapping
  (A ends the day B starts — decide: touching endpoints DO overlap under the
  inclusive rule; document this). Editing a trip to its own dates must NOT
  count as an overlap with itself.

---

## Suggested Build Order for Claude Code

```
Phase 1 → Model changes: rename calories→caloriesEaten, add caloriesBurned to
          HealthLog; ensure Meal has a stable id. Update fromJson/toJson/
          copyWith + mock seed data + existing tests to match.
Phase 2 → lib/features/health/ : HealthDataSource interface + MockHealthDataSource
          + PlatformHealthDataSource (health package). Wire via provider; default
          to mock. Add permission config for iOS/Android.
Phase 3 → Pre-fill steps + caloriesBurned into HealthLog on entry create/edit,
          with manual override + null/denied fallback.
Phase 4 → TripStats: add totalCaloriesEaten + totalCaloriesBurned (no net).
          Dashboard/wellness strip shows both, with graceful "no health data"
          placeholder.
Phase 5 → In-place meal editing in the Health Log sub-form; recompute
          caloriesEaten on save.
Phase 6 → Real photo upload via image_picker (camera + gallery) + permissions.
Phase 7 → Entry timestamping + day-derivation rule + trip-range validation.
Phase 8 → Overlap prevention in TripController/trip form + inline error.
Phase 9 → Tests: dual-calorie stats, meal edit sum recompute, day mapping,
          overlap detection edge cases.
```

Run the app + commit after each phase. Device-dependent phases (2, 3, 6) run on
mocks in the emulator; verify the real `Platform*` implementations on a physical
device before final integration.

---

## Cross-Cutting Notes

- **Interfaces preserved:** health data and photos sit behind interfaces /
  simple string paths so the Supabase + real-device swaps stay clean later.
- **Manual fallback is mandatory** for steps and calories-burned — never let a
  missing wearable or denied permission block journaling.
- **PDPA / privacy:** health data, camera, and photo access are all sensitive
  permissions — list them in the proposal's security and non-functional
  requirements, with the justification strings shown to the user.
- **Calories stay two numbers.** If anyone later asks for a net figure, that's a
  new decision requiring on-device verification that "burned" includes BMR —
  do not add it silently.

---

*Keep this beside the other two plans in the repo root. Update as decisions
firm up.*
