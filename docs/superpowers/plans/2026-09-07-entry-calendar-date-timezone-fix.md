# Entry Calendar Date Timezone Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every TripJournal feature assign an entry to the date stored in Supabase `entry_date`, independent of UTC or the device timezone.

**Architecture:** Add a logical, date-only value to `JournalEntry` and expose it through `calendarDate`. Supabase and local JSON populate that value, while legacy callers fall back to the local calendar date of `createdAt`. Every calendar-day consumer uses `calendarDate`; timestamp ordering continues to use `creationOrderAt`.

**Tech Stack:** Flutter, Dart, Riverpod, Supabase/PostgREST, flutter_test

## Global Constraints

- Do not modify or rewrite existing Supabase rows.
- Do not change `createdAt`, `updatedAt`, or `creationOrderAt` timestamp semantics.
- Preserve local/mock JSON compatibility when the new field is absent.
- Preserve route order and cumulative Map Day filtering.
- Do not modify the user's uncommitted `web/index.html` change.
- Use only a trip whose name contains `TEST` for emulator verification.

---

### Task 1: Establish the logical calendar-date model contract

**Files:**
- Modify: `lib/models/journal_entry.dart`
- Modify: `lib/data/journal_supabase_mapper.dart`
- Test: `test/supabase_journal_repository_test.dart`
- Test: `test/journal_entry_model_test.dart`

**Interfaces:**
- Produces: `JournalEntry.entryDate`, an optional persisted date for backward compatibility.
- Produces: `JournalEntry.calendarDate`, a normalized `DateTime(year, month, day)` used by all calendar-day consumers.
- Consumes: Supabase `journal_entries.entry_date` in `journalEntryFromSupabaseRow`.

- [ ] **Step 1: Write failing mapper and model tests**

Add a Supabase row with `created_at: 2026-09-06T23:02:38Z` and `entry_date: 2026-09-07`; assert that `calendarDate` is `DateTime(2026, 9, 7)` while `createdAt` remains the original UTC timestamp. Add JSON round-trip coverage and a legacy JSON test without `entryDate`.

- [ ] **Step 2: Run the focused tests and confirm RED**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\supabase_journal_repository_test.dart test\journal_entry_model_test.dart
```

Expected: failure because `JournalEntry.calendarDate` and explicit entry-date persistence do not exist.

- [ ] **Step 3: Implement the minimal model and mapper support**

Add the optional constructor/copy field and normalized getter:

```dart
final DateTime? entryDate;

DateTime get calendarDate {
  final value = entryDate ?? createdAt.toLocal();
  return DateTime(value.year, value.month, value.day);
}
```

Parse valid `yyyy-MM-dd` Supabase values without timezone conversion, fall back safely to `createdAt.toLocal()`, persist the logical date in local JSON, and write `formatDateOnly(entry.calendarDate)` to Supabase.

- [ ] **Step 4: Run the focused tests and confirm GREEN**

- [ ] **Step 5: Commit the model contract**

```powershell
git add lib/models/journal_entry.dart lib/data/journal_supabase_mapper.dart test/supabase_journal_repository_test.dart test/journal_entry_model_test.dart
git commit -m "fix: model entry calendar dates explicitly"
```

### Task 2: Use the logical date for creation, validation, grouping, and Map routes

**Files:**
- Modify: `lib/features/journal/screens/create_edit_entry_screen.dart`
- Modify: `lib/features/journal/controller/journal_controller.dart`
- Modify: `lib/features/trip/trip_day_groups.dart`
- Modify: `lib/features/trip/trip_entry_date_range.dart`
- Modify: `lib/features/trip/map/trip_map_model.dart`
- Test: `test/create_edit_entry_screen_test.dart`
- Test: `test/trip_day_groups_test.dart`
- Test: `test/trip_entry_date_range_test.dart`
- Test: `test/trip_map_model_test.dart`

**Interfaces:**
- Consumes: `JournalEntry.calendarDate` from Task 1.
- Preserves: `_compareRouteEntries` ordering by calendar day, then `creationOrderAt`, then ID.

- [ ] **Step 1: Add the reported UTC+8 regression tests**

Construct an entry with `createdAt = DateTime.utc(2026, 9, 6, 23, 2, 38)` and `entryDate = DateTime(2026, 9, 7)` for a trip beginning September 6. Assert that both `buildDayGroups` and `buildTripMapModel` assign it to Day 2. Add range validation coverage using the same logical date.

- [ ] **Step 2: Run the focused tests and confirm RED**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\trip_day_groups_test.dart test\trip_entry_date_range_test.dart test\trip_map_model_test.dart
```

- [ ] **Step 3: Change calendar-day consumers to `calendarDate`**

Use `entry.calendarDate` for timeline keys, trip-range checks, Map availability/filtering/group labels, and route day numbers. Keep `creationOrderAt` for within-day order. New entries receive a normalized `entryDate` derived from the selected `initialDate`; edits preserve the existing value. Controller date validation receives `entry.calendarDate`.

- [ ] **Step 4: Run the focused tests and confirm GREEN**

- [ ] **Step 5: Commit grouping and Map consistency**

```powershell
git add lib/features/journal lib/features/trip test/create_edit_entry_screen_test.dart test/trip_day_groups_test.dart test/trip_entry_date_range_test.dart test/trip_map_model_test.dart
git commit -m "fix: align entry and map trip days"
```

### Task 3: Align every remaining date consumer

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Modify: `lib/features/journal/journal_filter.dart`
- Modify: `lib/features/journal/pdf/journal_pdf_export.dart`
- Modify: `lib/features/journal/screens/entry_detail_screen.dart`
- Modify: `lib/features/journal/screens/journal_list_screen.dart`
- Modify: `lib/features/trip/ai/gemini_trip_summary_service.dart`
- Modify: `lib/features/trip/map/trip_map_view.dart`
- Modify: `lib/features/trip/trip_summary_stats.dart`
- Modify: `lib/features/trip/trip_wellness_stats.dart`
- Test: `test/journal_filter_test.dart`
- Test: `test/trip_summary_stats_test.dart`
- Test: `test/trip_wellness_stats_test.dart`
- Test: relevant screen and PDF tests already covering these views

**Interfaces:**
- Consumes: `JournalEntry.calendarDate` from Task 1.
- Preserves: timestamp fields for audit and immutable ordering only.

- [ ] **Step 1: Add focused tests with conflicting timestamp and logical date**

Assert that date filtering, distinct days logged, wellness steps-per-day, today's-entry lookup where testable, and visible/exported dates follow `calendarDate` rather than the UTC date in `createdAt`.

- [ ] **Step 2: Run the focused tests and confirm RED**

- [ ] **Step 3: Replace only calendar-date uses**

Use `calendarDate` for user-facing journal dates, filtering, daily statistics, home “today” matching, Map accessibility/preview dates, PDF dates, and the date sent in the trip-summary prompt. Do not replace timestamp uses unrelated to journal calendar dates.

- [ ] **Step 4: Run affected test files and confirm GREEN**

- [ ] **Step 5: Search for missed calendar-day derivations**

Run:

```powershell
rg -n "entry\.createdAt\.(year|month|day)|_dateOnly\(entry\.createdAt\)|formatDate\(entry\.createdAt\)" lib
```

Expected: no journal calendar-date consumers remain; any surviving match must be documented as a genuine timestamp use.

- [ ] **Step 6: Commit remaining consumer alignment**

```powershell
git add lib test
git commit -m "fix: use entry calendar dates across the app"
```

### Task 4: Full regression and Android verification

**Files:**
- No source changes expected.

**Interfaces:**
- Verifies: all Tasks 1–3 together.

- [ ] **Step 1: Run formatter on changed Dart files**

- [ ] **Step 2: Run static analysis**

```powershell
D:\Download\flutter-sdk\bin\flutter.bat analyze --no-pub
```

Expected: no issues.

- [ ] **Step 3: Run the complete Flutter test suite**

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test --no-pub
```

Expected: all applicable tests pass.

- [ ] **Step 4: Review the final diff and repository status**

Confirm the diff contains no database data edits, no unrelated refactor, and no changes to `web/index.html`.

- [ ] **Step 5: Build and launch the Supabase-configured Android app**

```powershell
D:\Download\flutter-sdk\bin\flutter.bat run -d emulator-5554 --dart-define=BACKEND_MODE=supabase --dart-define-from-file=.local\maps_defines.json
```

- [ ] **Step 6: Verify the boundary case using a TEST trip**

Confirm that an entry whose logical date is Day 2 appears under Day 2 in both Entries and Map, while routes, filters, counts, and existing entries remain intact.
