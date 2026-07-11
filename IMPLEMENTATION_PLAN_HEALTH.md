# Implementation Plan — Health Platform Integration (Health Connect + HealthKit)

> Ninth companion file. Fills in the **real** implementation of the
> `HealthDataSource` that `IMPLEMENTATION_PLAN_ENHANCEMENTS.md` stubbed.
> Read `CLAUDE.md` first for project context.
>
> **Purpose:** read **steps** and **calories burned** from the phone's health
> platform, so users don't have to type them by hand.
>
> **Key mental model — do NOT integrate with individual apps/watches.**
> Fitbit, Garmin, Samsung Health, Apple Watch, etc. all sync INTO the phone's
> central health platform. The app reads from the **platform**, never from a
> specific device or vendor app. Two platforms total:
>   * **Android → Health Connect**
>   * **iOS → Apple HealthKit**
> The Flutter `health` package wraps BOTH behind one Dart API, so this is
> written once and works on both.

---

## Ground Rules (non-negotiable)

1. **Manual fallback is MANDATORY.** Steps and calories-burned must ALWAYS
   remain manually editable. Health data is a *convenience that pre-fills*,
   never a hard dependency. A user with no wearable, a denied permission, an
   unsupported device, or an emulator must still be able to use the entire app
   by typing values in. **Never block journaling on health data.**
   - This is not theoretical: some vendors (e.g. Huawei) do not reliably sync
     into Health Connect. The app must degrade gracefully when data is absent.
2. **Never overwrite user input.** If the user has manually typed a steps or
   calories-burned value, do NOT silently replace it with platform data.
   Pre-fill only when the field is empty/untouched, or offer an explicit
   "sync from health app" action.
3. **`caloriesBurned` is NOT `caloriesEaten`.** Burned comes from the platform;
   eaten is summed from the user's meals. They are separate fields and are
   displayed as two separate numbers. **No net calculation.** (Confirmed
   decision — see `_ENHANCEMENTS`.)
4. **Cross-platform code, Android-only testing requirement.** Implement both
   Health Connect and HealthKit (the `health` package handles both). Only
   Android testing is required for this project (that's the available device);
   iOS support should be correct in code but need not be verified on-device.

---

## 1. Package & Dependency

- Add the **`health`** package (pub.dev) via `flutter pub add health` — do NOT
  hardcode a version; let the tool resolve the current one.
- It provides a unified Dart API over Apple HealthKit (iOS) and Health Connect
  (Android).

---

## 2. The Interface (already defined — implement against it)

From `_ENHANCEMENTS`, `lib/features/health/health_data_source.dart`:
```dart
abstract class HealthDataSource {
  Future<int?> getStepsForDate(DateTime date);
  Future<int?> getCaloriesBurnedForDate(DateTime date); // null if unavailable
  Future<bool> requestPermissions();
  Future<bool> hasPermissions();
}
```
- `MockHealthDataSource` — EXISTS. Returns plausible fixed values. **Keep it.**
  It stays the default for emulator/day-to-day development.
- `PlatformHealthDataSource` — **BUILD THIS NOW.** Real implementation using the
  `health` package. Same interface, so it drops in via the existing
  provider/locator with a one-line swap.

**Null is a first-class result.** Both getters return `int?`. Return `null`
(not 0, not an exception) when: permission denied, platform unavailable, no data
for that date, or running on an emulator. The UI treats null as "no data → keep
manual entry."

---

## 3. `PlatformHealthDataSource` — Implementation

### Data types to read
- **Steps** — the platform's step-count type.
- **Calories burned** — the platform's energy-burned type.
  - ⚠️ **Do NOT compute or display a net.** Just read what the platform gives
    and surface it as "Calories Burned". (We deliberately avoid net because the
    burned figure may or may not include BMR — see `_ENHANCEMENTS` rationale.)

### Behaviour
- Query per **calendar day** (midnight → midnight of the given date), matching
  how `HealthLog` is keyed to a journal entry's day.
- Aggregate/sum the returned samples for that day into a single int.
- Wrap every platform call in try/catch — **never let a health exception crash
  or block the app.** On any failure, return `null`.
- `hasPermissions()` / `requestPermissions()` delegate to the package's
  permission APIs.

### Permissions flow
- Request **read** access only (the app does not write health data).
- Ask for permission **contextually** — when the user first uses a health
  feature (e.g. opens the health section of an entry, or taps "sync from health
  app") — NOT on a cold app launch. Explain why before prompting.
- If **denied**: do nothing intrusive. Show a small, dismissible note like
  *"Connect a health app to auto-fill steps and calories"* and leave manual
  entry fully working. Do not nag or re-prompt repeatedly.
- Re-check permission state on use (`hasPermissions()`); the user can revoke it
  in system settings at any time.

---

## 4. Platform Configuration

### Android (Health Connect)
- Health Connect is built into newer Android versions; on older ones it's a
  separate Play Store app. Handle the **"Health Connect not available"** case →
  return `null`, fall back to manual.
- Declare the required Health Connect **read permissions** in the Android
  manifest (steps, energy burned) per the `health` package's setup docs.
- Add any required Health Connect permissions-rationale activity/intent
  declarations the package specifies.
- **Follow the `health` package's current README/setup instructions** for the
  exact manifest entries and minSdk requirements — do not guess these from
  memory; they change between versions.

### iOS (HealthKit)
- Enable the **HealthKit capability** in the iOS project.
- Add the health-data usage description strings to `Info.plist` (required, or
  the app is rejected/crashes on request).
- Same rule: follow the package's current iOS setup docs for exact keys.
- Code must be correct, but **on-device iOS verification is not required** for
  this project (no Mac/iPhone available).

### Privacy / PDPA (also needed for the proposal)
- Health data is **sensitive personal data**. Note in the proposal's security /
  non-functional requirements section:
  - What is read (steps, energy burned), why, and that it is read-only.
  - That explicit user consent is required and the app works fully without it.
  - Where the data is stored (in the user's own `health_logs` row, protected by
    RLS so only they can access it).

---

## 5. Wiring Into the Journal Entry Flow

Where the pre-fill actually happens (create/edit entry screen, health section):

1. When the user opens the health section for an entry dated **today or a past
   day within the trip**:
   - If permission is granted → call `getStepsForDate(entryDate)` and
     `getCaloriesBurnedForDate(entryDate)`.
   - **Pre-fill** the steps and calories-burned fields with the returned values
     **only if those fields are empty / untouched** (rule #2 above).
   - Show a subtle indicator that a value came from the health app (e.g. a small
     "from Health Connect" hint), so the user knows it's auto-filled and can
     override.
2. If either returns `null` → leave the field empty and manually editable. Show
   the "connect a health app" note if permission is the reason. **No error, no
   block.**
3. Provide an explicit **"Sync from health app"** button in the health section so
   the user can re-pull values on demand (useful if they walked more after first
   opening the entry). This is also the natural place to trigger the permission
   request the first time.
4. Whatever ends up in the field — auto-filled or hand-typed — is what gets
   saved to `HealthLog.steps` / `HealthLog.caloriesBurned`.

### Validation still applies (from `_VALIDATION`)
- Steps: non-negative; soft cap **100,000** (gentle "that seems too high" if a
  manual value exceeds it). Platform-sourced values should be sane, but validate
  anyway.
- Calories burned: non-negative; **nullable** (may legitimately be absent).
- Dashboard shows **Eaten** and **Burned** as two separate numbers; when burned
  is null show a placeholder (`— (no health data)`), never `0`.

---

## 6. Swapping Mock → Real

- Keep `MockHealthDataSource` as the **default** for emulator/dev work.
- Swap to `PlatformHealthDataSource` in the provider/locator — **one line**,
  same as the repository swap. Consider selecting by build config or a debug
  toggle so the emulator keeps using the mock while a real device uses the
  platform.
- Do not delete the mock; it's needed for tests and emulator runs.

---

## 7. Testing

### Unit / widget (works anywhere)
- `PlatformHealthDataSource` returns `null` (not 0, not a throw) when:
  permission denied, platform unavailable, no data, exception thrown.
- Pre-fill logic: fills empty fields; **does NOT overwrite** a user-entered
  value.
- UI: null steps/calories → field stays empty + manually editable; dashboard
  shows the "no health data" placeholder, not 0.
- Steps validation: negative rejected, >100,000 warned.

### Real-device (Android — REQUIRED)
> ⚠️ **Health Connect / HealthKit do NOT work on emulators.** The mock will make
> everything *look* fine in the emulator. Verify on a physical device.

On a real Android phone:
1. Confirm Health Connect is present (built-in or installed from Play Store).
2. Walk around so the phone's own step counter records real data. **The phone
   itself tracks steps — a wearable is NOT required.**
3. Run the app with `PlatformHealthDataSource` active; grant permission when
   prompted.
4. Verify steps pre-fill into a journal entry for today, and that the value can
   be overridden manually.
5. Verify **denying** permission leaves the app fully usable with manual entry.
6. Verify a past-date entry pulls that date's data (or null, gracefully).

### Wearable note (expectation-setting, not a bug)
- A paired band/watch is **optional**. Vendor apps that sync into Health Connect
  (Samsung, Fitbit, Garmin, etc.) will surface their data automatically.
- **Huawei devices/Huawei Health often do NOT sync into Health Connect.** If band
  data doesn't appear, that is an ecosystem limitation, **not an app bug** — do
  not chase it. The phone's own step data is sufficient for testing, and the
  manual fallback covers users in this situation. (This is a concrete
  justification for the manual-fallback requirement — worth citing in the
  writeup.)

---

## Suggested Build Order for Claude Code

```
Phase 1 → flutter pub add health; PlatformHealthDataSource skeleton implementing
          the existing HealthDataSource interface; permission methods.
Phase 2 → Android config: Health Connect manifest permissions + any required
          declarations, per the health package's CURRENT setup docs.
          (Handle "Health Connect unavailable" → null.)
Phase 3 → iOS config: HealthKit capability + Info.plist usage strings, per the
          package's current docs. (Code correct; on-device iOS test not required.)
Phase 4 → Implement getStepsForDate / getCaloriesBurnedForDate: per-calendar-day
          query, aggregate to int, try/catch → null on ANY failure.
Phase 5 → Entry-screen wiring: contextual permission request, pre-fill empty
          fields only, "from health app" hint, explicit "Sync from health app"
          button, graceful denied/null path with manual entry intact.
Phase 6 → Provider/locator swap (mock default for emulator; platform on device).
Phase 7 → Tests (unit/widget per §7) + a real-device Android checklist run.
```

Run + commit after each phase. **Phases 4–6 must be verified on a physical
Android device** — the emulator cannot validate them.

---

## Cross-Cutting Notes

- **Two platforms, not many apps.** Health Connect (Android) + HealthKit (iOS)
  cover every wearable/app that syncs into them. Never write vendor-specific
  integrations.
- **A watch is not required** — phones count steps natively. Testing needs a
  physical *phone*, not a wearable.
- **`null` means "no data," and that's a normal, expected state** — not an error.
  Handle it everywhere; never render it as `0`.
- **Manual entry must always work.** If health integration is flaky on demo day,
  the app must still fully function by hand. Do not let the demo depend on it.
- **Follow the `health` package's current setup docs** for manifest/Info.plist
  specifics — these change between versions; do not rely on remembered config.

---

*Keep this beside the other plans in the repo root. Update as decisions firm up.*
