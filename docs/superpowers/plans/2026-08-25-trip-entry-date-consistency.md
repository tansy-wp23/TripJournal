# Trip Entry Date Consistency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep every Trip consumer within the Trip date range, block edits that would strand Entries, refresh Home counts, and repair the single approved Day 15 Supabase Entry to Day 1.

**Architecture:** Add one pure date-range helper and make Trip View derive a single in-range Entry list for all downstream consumers. Keep a second range check inside the Map model as defense in depth, and enforce the invariant before Trip date edits reach storage. Repair the existing row only after an exact authenticated precondition query returns one match.

**Tech Stack:** Flutter/Dart, Riverpod ChangeNotifier providers, `google_maps_flutter`, Supabase/PostgREST, Flutter widget and unit tests.

## Global Constraints

- Trip start and end dates are inclusive local calendar dates.
- Never auto-extend a Trip or silently move Entries.
- Preserve all Entry fields except the approved `created_at` date correction.
- Do not touch iOS/Web Maps work or `web/index.html`.
- Keep Flutter, Gradle, and dependency caches on `D:`.
- Do not print Supabase sessions, API keys, precise coordinates, or signing secrets.

---

### Task 1: Pure Trip Entry Range and Map Defense

**Files:**
- Create: `lib/features/trip/trip_entry_date_range.dart`
- Create: `test/trip_entry_date_range_test.dart`
- Modify: `lib/features/trip/map/trip_map_model.dart`
- Modify: `test/trip_map_model_test.dart`

**Interfaces:**
- Produces: `bool isEntryWithinTrip(Trip trip, JournalEntry entry)` and `List<JournalEntry> entriesWithinTrip(Trip trip, Iterable<JournalEntry> entries)`.
- Changes: `buildTripMapModel` receives required `DateTime tripEndDate` in addition to `tripStartDate`.

- [ ] **Step 1: Write failing pure-function tests**

Add literal fixtures for an August 11–18 Trip. Assert that August 11 and 18 are included, while August 10 and 25 are excluded, without changing input order.

```dart
expect(entriesWithinTrip(trip, [before, day1, day8, after]), [day1, day8]);
```

- [ ] **Step 2: Write the failing Map regression test**

Pass mapped Day 1, Day 2, and August 25 Entries to an eight-day Trip model and assert:

```dart
expect(model.availableDays, [1, 2]);
expect(model.mappedEntryCount, 2);
expect(model.groups.expand((group) => group.entries), isNot(contains(day15)));
```

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\trip_entry_date_range_test.dart test\trip_map_model_test.dart
```

Expected: FAIL because the helper and `tripEndDate` boundary do not exist.

- [ ] **Step 3: Implement the minimal local-date filter**

Normalize dates with `toLocal()` and compare date-only values inclusively. Filter Map input before computing counts, chips, marker groups, connectors, and bounds.

- [ ] **Step 4: Update direct Map model test call sites and run focused tests**

Update the pure model test fixtures with explicit end dates. `TripMapView` is
updated in Task 2, when its Trip end date is available. Expected: PASS, with
existing Day 1/Day 2 connector tests unchanged.

- [ ] **Step 5: Commit the pure boundary**

```powershell
git add lib/features/trip/trip_entry_date_range.dart lib/features/trip/map/trip_map_model.dart test/trip_entry_date_range_test.dart test/trip_map_model_test.dart
git commit -m "fix: constrain trip map entries to trip dates"
```

### Task 2: Use One In-Range Entry List Throughout Trip View

**Files:**
- Modify: `lib/features/trip/trip_view_screen.dart`
- Modify: `lib/features/trip/map/trip_map_view.dart`
- Modify: `test/trip_view_map_tab_test.dart`
- Modify: `test/trip_summary_edit_test.dart`

**Interfaces:**
- Consumes: `entriesWithinTrip(Trip, Iterable<JournalEntry>)` from Task 1.
- Produces: one `tripEntries` list used by statistics, day groups, filtered groups, photos, PDF, Summary, Wellness, and Map.

- [ ] **Step 1: Add a failing widget regression test**

Seed one in-range Entry and one August 25 Entry for the eight-day Trip. Assert the screen reports one journaled day, Map does not expose `Day 15`, and generated Summary receives only the in-range Entry.

- [ ] **Step 2: Run the focused widget tests and verify RED**

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\trip_view_map_tab_test.dart test\trip_summary_edit_test.dart
```

Expected: FAIL because Trip View currently passes `journalController.entries` directly.

- [ ] **Step 3: Derive and use `tripEntries` once**

Inside `TripViewScreen.build`, derive:

```dart
final tripEntries = entriesWithinTrip(trip, journalController.entries);
final filteredTripEntries = filterJournalEntries(tripEntries, journalController.filter);
```

Replace direct downstream uses of `journalController.entries` and `filteredEntries` with these values. Pass both start and end dates to `TripMapView`.

- [ ] **Step 4: Run focused tests and commit**

Expected: PASS.

```powershell
git add lib/features/trip/trip_view_screen.dart lib/features/trip/map/trip_map_view.dart test/trip_view_map_tab_test.dart test/trip_summary_edit_test.dart
git commit -m "fix: keep trip views within trip dates"
```

### Task 3: Block Trip Date Edits That Exclude Existing Entries

**Files:**
- Modify: `lib/features/trip/controller/trip_controller.dart`
- Modify: `test/trip_controller_validation_test.dart`

**Interfaces:**
- Consumes: `isEntryWithinTrip(Trip, JournalEntry)` from Task 1 and `JournalRepository.getEntries(String tripId)`.
- Produces: `editTrip` error `Trip dates must include all existing journal entries.` before cover upload or repository update.

- [ ] **Step 1: Add failing controller tests**

Use the existing fake repositories to assert that shortening a Trip around an August 25 Entry returns the exact error and performs zero Trip updates/cover uploads. Add a control test proving a date edit that still includes all Entries succeeds.

- [ ] **Step 2: Run the controller test and verify RED**

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\trip_controller_validation_test.dart
```

- [ ] **Step 3: Add the pre-persistence guard**

Only when normalized start or end dates differ from the currently loaded Trip, load that Trip's Entries and reject if any falls outside the proposed range. Repository read failures return the existing error treatment and do not persist the Trip.

- [ ] **Step 4: Run tests and commit**

```powershell
git add lib/features/trip/controller/trip_controller.dart test/trip_controller_validation_test.dart
git commit -m "fix: protect entries when editing trip dates"
```

### Task 4: Refresh Home Counts After Returning From Trip View

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Modify: `test/home_screen_nudge_test.dart`

**Interfaces:**
- Changes: `_openTripView` always calls `_loadDashboardData()` after the route returns while mounted.

- [ ] **Step 1: Add a failing widget test**

Open a Trip showing zero Entries, mutate the fake Journal repository while Trip View is open, navigate back, and assert Home shows the new literal count without requiring deletion or restart.

- [ ] **Step 2: Verify RED**

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\home_screen_nudge_test.dart
```

- [ ] **Step 3: Reload after every normal return and verify GREEN**

Keep the existing trash-return behavior, but remove the `movedToTrash == true` condition around dashboard reload. Guard the async continuation with `mounted`.

- [ ] **Step 4: Commit**

```powershell
git add lib/features/home/home_screen.dart test/home_screen_nudge_test.dart
git commit -m "fix: refresh trip counts after viewing a trip"
```

### Task 5: Repair the Approved Supabase Entry and Android Verification

**Files:**
- Modify only remote data for the authenticated user's `Happy Family Trip` and `First day went to KLCC` Entry.
- Build artifact: `build/app/outputs/flutter-apk/app-debug.apk`

**Interfaces:**
- Consumes: the current emulator's authenticated Supabase session without printing it.
- Produces: exactly one Entry whose local date is August 11, 2026, with all non-date fields unchanged.

- [ ] **Step 1: Verify repair preconditions read-only**

Query by authenticated owner, Trip title, Entry title, Trip range August 11–18, and Entry date August 25. Abort unless exactly one row matches. Capture only IDs and a hash of the non-date payload in memory; do not print private fields or coordinates.

- [ ] **Step 2: Correct only the calendar date**

Update `created_at` from August 25 to August 11 while preserving the original local time-of-day and every other column. Re-query and verify one matching row now falls on Day 1 and none remain outside the Trip range.

- [ ] **Step 3: Run complete automated verification**

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
$env:GRADLE_USER_HOME='D:\FlutterCache\gradle'
D:\Download\flutter-sdk\bin\flutter.bat analyze --no-pub
D:\Download\flutter-sdk\bin\flutter.bat test --no-pub
D:\Download\flutter-sdk\bin\flutter.bat build apk --debug --no-pub --dart-define=BACKEND_MODE=supabase --dart-define-from-file=.local/maps_defines.json
```

- [ ] **Step 4: Install without clearing App data and verify manually**

Use `adb install -r`, open `Happy Family Trip`, and confirm:

- Entries reports three of eight days only if three distinct in-range dates remain; otherwise the literal in-range count.
- Map exposes only `All`, `Day 1`, and `Day 2` for the repaired current data.
- No day chip exceeds Day 8.
- Day 1 marker preview shows the corrected Entry.
- Full App restart preserves the correction.

- [ ] **Step 5: Final repository safety check**

Confirm `web/index.html` remains untouched by this fix, `.local` remains ignored, and no secrets or precise coordinates entered tracked files. Report local commit state without pushing unless explicitly requested.
