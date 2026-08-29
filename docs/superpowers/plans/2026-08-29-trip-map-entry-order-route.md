# Trip Map Entry-Order Route Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the trip map connect every located Entry in day-first, immutable-creation-order-second sequence, including same-day stops and routes across days with no mapped stops.

**Architecture:** Add a database-backed immutable `creationOrderAt` value to `JournalEntry`, with a legacy fallback and a Supabase migration that backfills and protects the column. Flatten the cumulatively visible mapped Entries into one ordered list, derive uniquely identified route segments between consecutive Entries, and render the same segments in Google Map and fallback surfaces.

**Tech Stack:** Flutter/Dart, Riverpod application state, `google_maps_flutter`, Supabase/PostgreSQL migrations, `flutter_test`.

## Global Constraints

- Sort first by trip day, then by immutable original Entry creation order, then by Entry ID only as a deterministic final tie-breaker.
- Editing an Entry must never change its creation order.
- Skip Entries and days without a Location without breaking the route; Day 1 may connect directly to Day 3.
- Selecting Day N remains cumulative from Day 1 through Day N; All shows the entire route.
- Preserve marker grouping and normalized coordinate identity behaviour.
- Do not create cloud test data or a separate test Trip.
- Do not alter or stage the user's uncommitted `web/index.html` modification.
- Do not print API keys, Supabase sessions, project credentials, or signing passwords.
- Use `D:\Download\flutter-sdk`, `D:\FlutterCache\pub-cache`, and `D:\FlutterCache\gradle`; do not download large tooling or caches to C:.
- Work on the existing `trip-module` branch and do not force-push.

---

## File Structure

- Modify `lib/models/journal_entry.dart`: own the immutable creation-order value and legacy JSON fallback.
- Modify `lib/features/journal/screens/create_edit_entry_screen.dart`: stamp new Entries once and preserve the value on edit.
- Modify `lib/data/journal_supabase_mapper.dart`: read the migrated Supabase column.
- Create `supabase/migrations/202608290001_journal_entry_creation_order.sql`: add, backfill, index, and protect the database column.
- Create `test/journal_creation_order_migration_test.dart`: enforce the migration contract without requiring the removed local Docker stack.
- Modify `lib/features/trip/map/trip_map_model.dart`: define general route segments and build the flattened route.
- Modify `lib/features/trip/map/google_trip_map_surface.dart`: draw every segment and arrow.
- Modify `lib/features/trip/map/trip_map_view.dart`: describe the same segments in fallback mode.
- Modify `test/models_test.dart`, `test/create_edit_entry_location_test.dart`, `test/supabase_journal_repository_test.dart`, `test/trip_map_model_test.dart`, `test/google_trip_map_surface_test.dart`, and `test/trip_map_view_test.dart`: cover persistence, ordering, route generation, and rendering.

---

### Task 1: Immutable Entry Creation Order in the Dart Model

**Files:**
- Modify: `lib/models/journal_entry.dart`
- Modify: `lib/features/journal/screens/create_edit_entry_screen.dart`
- Test: `test/models_test.dart`
- Test: `test/create_edit_entry_location_test.dart`

**Interfaces:**
- Produces: `JournalEntry.creationOrderAt` as a non-null `DateTime`.
- Constructor input: optional named `DateTime? creationOrderAt`; omission falls back to `updatedAt` for legacy callers.
- JSON key: `creationOrderAt`; older JSON without it falls back to parsed `updatedAt`.
- `copyWith` preserves `creationOrderAt` unless explicitly overridden.

- [ ] **Step 1: Add failing model serialization and immutability tests**

Extend the `JournalEntry` group in `test/models_test.dart`:

```dart
test('round-trips immutable creation order', () {
  final creationOrder = DateTime.utc(2026, 8, 29, 1, 2, 3);
  final ordered = entry.copyWith(creationOrderAt: creationOrder);

  final restored = JournalEntry.fromJson(ordered.toJson());

  expect(restored.creationOrderAt, creationOrder);
  expect(
    restored.copyWith(updatedAt: creationOrder.add(const Duration(days: 1)))
      .creationOrderAt,
    creationOrder,
  );
});

test('legacy JSON falls back to its saved updatedAt for creation order', () {
  final legacy = entry.toJson()..remove('creationOrderAt');

  final restored = JournalEntry.fromJson(legacy);

  expect(restored.creationOrderAt, restored.updatedAt);
});
```

- [ ] **Step 2: Run the focused model tests and confirm RED**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test test\models_test.dart
```

Expected: compilation fails because `creationOrderAt` does not exist.

- [ ] **Step 3: Implement the model field and backward-compatible JSON**

In `lib/models/journal_entry.dart`, add the field and initialize it without forcing every existing fixture to change:

```dart
final DateTime creationOrderAt;

const JournalEntry({
  // existing arguments
  DateTime? creationOrderAt,
  required this.updatedAt,
  // existing arguments
}) : creationOrderAt = creationOrderAt ?? updatedAt;
```

Parse `updatedAt` once in `fromJson`, use `creationOrderAt` when present, add it to `toJson`, and add `DateTime? creationOrderAt` to `copyWith` with `creationOrderAt ?? this.creationOrderAt`.

- [ ] **Step 4: Add a failing create/edit screen test**

In `test/create_edit_entry_location_test.dart`, use the existing repository/provider harness to save a new Entry, capture its `creationOrderAt`, reopen it, edit a harmless field, save again, and assert:

```dart
expect(updated.creationOrderAt, originallyCreated.creationOrderAt);
expect(updated.updatedAt.isBefore(originallyCreated.updatedAt), isFalse);
```

The test must not call Supabase or create external data.

- [ ] **Step 5: Run the screen test and confirm RED**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\create_edit_entry_location_test.dart
```

Expected: the new Entry receives the constructor fallback rather than an explicit initial creation-order timestamp, or the edit does not preserve the expected captured value.

- [ ] **Step 6: Stamp only new Entries in the save flow**

In `CreateEditEntryScreen._save`, derive the value beside `createdAt`:

```dart
final creationOrderAt = existing?.creationOrderAt ?? now;
```

Pass it to the new `JournalEntry`. Do not derive it from the selected journal day, and do not replace it during edits.

- [ ] **Step 7: Run focused tests and confirm GREEN**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\models_test.dart test\create_edit_entry_location_test.dart
```

Expected: both files pass.

- [ ] **Step 8: Commit the Dart creation-order model**

```powershell
git add -- lib/models/journal_entry.dart lib/features/journal/screens/create_edit_entry_screen.dart test/models_test.dart test/create_edit_entry_location_test.dart
git commit -m "feat(journal): preserve entry creation order"
```

---

### Task 2: Supabase Creation-Order Persistence and Protection

**Files:**
- Create: `supabase/migrations/202608290001_journal_entry_creation_order.sql`
- Create: `test/journal_creation_order_migration_test.dart`
- Modify: `lib/data/journal_supabase_mapper.dart`
- Modify: `test/supabase_journal_repository_test.dart`

**Interfaces:**
- Database column: `public.journal_entries.creation_order_at timestamptz not null default now()`.
- Database trigger: preserve the old `creation_order_at` on every update.
- Mapper read: `creation_order_at`, with `updated_at` fallback so the app can read legacy fixture rows.
- Existing `save_journal_entry_bundle` inserts receive the server default and updates cannot change the protected value.

- [ ] **Step 1: Add failing mapper tests**

Add `creation_order_at` to `_entryRow` in `test/supabase_journal_repository_test.dart`:

```dart
'creation_order_at': '2026-08-29T01:02:03.000Z',
```

Assert a fetched Entry maps it exactly. Add a second mapper assertion using a row without the key and expect `creationOrderAt == updatedAt`.

- [ ] **Step 2: Run the repository tests and confirm RED**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\supabase_journal_repository_test.dart
```

Expected: `creationOrderAt` is still the constructor fallback instead of the Supabase value.

- [ ] **Step 3: Map the Supabase value**

In `journalEntryFromSupabaseRow`, parse the optional column:

```dart
creationOrderAt: DateTime.parse(
  (row['creation_order_at'] ?? row['updated_at']) as String,
),
```

Do not add `creation_order_at` to editable fields. The database owns insertion and immutability.

- [ ] **Step 4: Add the failing migration contract test**

Create `test/journal_creation_order_migration_test.dart` that reads the migration and asserts the required clauses:

```dart
final sql = File(
  'supabase/migrations/202608290001_journal_entry_creation_order.sql',
).readAsStringSync().toLowerCase();

expect(sql, contains('add column creation_order_at timestamptz'));
expect(sql, contains('set creation_order_at = updated_at'));
expect(sql, contains('alter column creation_order_at set not null'));
expect(sql, contains('alter column creation_order_at set default now()'));
expect(sql, contains('new.creation_order_at := old.creation_order_at'));
expect(sql, contains('before update on public.journal_entries'));
```

- [ ] **Step 5: Run the contract test and confirm RED**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\journal_creation_order_migration_test.dart
```

Expected: failure because the migration file does not exist.

- [ ] **Step 6: Create the migration**

Create the migration with these operations in order:

```sql
alter table public.journal_entries
  add column creation_order_at timestamptz;

update public.journal_entries
set creation_order_at = updated_at
where creation_order_at is null;

alter table public.journal_entries
  alter column creation_order_at set default now(),
  alter column creation_order_at set not null;

create index journal_entries_trip_day_creation_order_idx
  on public.journal_entries (trip_id, entry_date, creation_order_at, id);

create or replace function public.preserve_journal_entry_creation_order()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.creation_order_at := old.creation_order_at;
  return new;
end;
$$;

create trigger journal_entries_preserve_creation_order
before update on public.journal_entries
for each row execute function public.preserve_journal_entry_creation_order();
```

Add comments explaining that `updated_at` is only a one-time best-effort legacy backfill and that all later updates preserve the frozen value.

- [ ] **Step 7: Run persistence tests and confirm GREEN**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\supabase_journal_repository_test.dart test\journal_creation_order_migration_test.dart
```

Expected: both files pass. Do not attempt local Supabase database tests because Docker was intentionally removed.

- [ ] **Step 8: Commit persistence changes**

```powershell
git add -- lib/data/journal_supabase_mapper.dart test/supabase_journal_repository_test.dart test/journal_creation_order_migration_test.dart supabase/migrations/202608290001_journal_entry_creation_order.sql
git commit -m "feat(journal): persist immutable creation order"
```

---

### Task 3: Build a Full Entry-Ordered Route

**Files:**
- Modify: `lib/features/trip/map/trip_map_model.dart`
- Modify: `test/trip_map_model_test.dart`

**Interfaces:**
- Replace: `TripMapDayConnector` with `TripMapRouteSegment`.
- Replace: `TripMapModel.connectors` with `TripMapModel.routeSegments`.
- Segment fields: `fromEntryId`, `toEntryId`, `fromDay`, `toDay`, endpoint coordinates, and endpoint labels.
- Segment ID: `entry-$fromEntryId-to-$toEntryId`.

- [ ] **Step 1: Update the test helper to accept creation order**

In `test/trip_map_model_test.dart`, add an optional argument:

```dart
DateTime? creationOrderAt,
```

and pass it to `JournalEntry`. Existing tests continue using their fallback.

- [ ] **Step 2: Write the failing two-level ordering test**

Create Entries in deliberately shuffled input order. Give `nice` and `UR` the same Day 2 `createdAt` but increasing `creationOrderAt`. Include two Day 1 Entries and one Day 3 Entry. Assert:

```dart
expect(model.routeSegments.map((segment) => segment.id), [
  'entry-day-1-a-to-day-1-b',
  'entry-day-1-b-to-nice',
  'entry-nice-to-ur',
  'entry-ur-to-day-3-a',
]);
```

Also rebuild with `UR.copyWith(updatedAt: later)` and expect the same IDs.

- [ ] **Step 3: Add failing route edge-case tests**

Add focused tests for:

```dart
// Day 2 has no mapped Entry: route still contains Day 1 -> Day 3.
expect(segment.fromDay, 1);
expect(segment.toDay, 3);

// Day 2 cumulative selection excludes Day 3 but includes every Day 1/2 segment.
expect(day2.routeSegments.map((segment) => segment.toDay), everyElement(lessThanOrEqualTo(2)));

// Equal consecutive coordinates omit only their zero-length pair;
// the later equal-location Entry still connects to the next different stop.
expect(model.routeSegments.map((segment) => segment.id), [
  'entry-same-location-later-to-next-different',
]);

// Deleting a middle Entry produces predecessor -> successor and keeps Day 3.
expect(afterDelete.routeSegments.single.id, 'entry-before-to-after');
```

- [ ] **Step 4: Run the map model tests and confirm RED**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\trip_map_model_test.dart
```

Expected: compilation fails because `routeSegments` and `TripMapRouteSegment` do not exist.

- [ ] **Step 5: Implement the general route segment type**

Define:

```dart
class TripMapRouteSegment {
  const TripMapRouteSegment({
    required this.fromEntryId,
    required this.toEntryId,
    required this.fromDay,
    required this.toDay,
    required this.fromLatitude,
    required this.fromLongitude,
    required this.toLatitude,
    required this.toLongitude,
    required this.fromLabel,
    required this.toLabel,
  });

  final String fromEntryId;
  final String toEntryId;
  final int fromDay;
  final int toDay;
  // coordinate and label fields

  String get id => 'entry-$fromEntryId-to-$toEntryId';
}
```

Expose an unmodifiable `routeSegments` list from `TripMapModel`.

- [ ] **Step 6: Implement day-first, creation-order-second sorting**

Replace `_compareEntries` for map ordering with a comparator that receives the trip start date:

```dart
int _compareRouteEntries(
  JournalEntry a,
  JournalEntry b,
  DateTime tripStartDate,
) {
  final byDay = _dayNumber(a.createdAt, tripStartDate)
      .compareTo(_dayNumber(b.createdAt, tripStartDate));
  if (byDay != 0) return byDay;
  final byCreationOrder = a.creationOrderAt.compareTo(b.creationOrderAt);
  if (byCreationOrder != 0) return byCreationOrder;
  return a.id.compareTo(b.id);
}
```

Use the same comparator for group ordering so marker previews agree with route order.

- [ ] **Step 7: Generate pairwise segments from visible mapped Entries**

Sort the trip-range Entries, apply the cumulative selected-Day limit, filter to `location != null`, then examine each adjacent pair:

```dart
for (var index = 0; index + 1 < orderedMapped.length; index++) {
  final from = orderedMapped[index];
  final to = orderedMapped[index + 1];
  if (_sameMappedLocation(from.location!, to.location!)) continue;
  segments.add(TripMapRouteSegment(
    fromEntryId: from.id,
    toEntryId: to.id,
    fromDay: _dayNumber(from.createdAt, tripStartDate),
    toDay: _dayNumber(to.createdAt, tripStartDate),
    // copy coordinates and labels
  ));
}
```

Remove the adjacent-calendar-day lookup. Update bounds to include route segment endpoints.

- [ ] **Step 8: Run the map model tests and confirm GREEN**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\trip_map_model_test.dart
```

Expected: all map model tests pass with updated segment expectations.

- [ ] **Step 9: Commit the route model**

```powershell
git add -- lib/features/trip/map/trip_map_model.dart test/trip_map_model_test.dart
git commit -m "fix(map): route entries by day and creation order"
```

---

### Task 4: Render All Route Segments and Arrows

**Files:**
- Modify: `lib/features/trip/map/google_trip_map_surface.dart`
- Modify: `lib/features/trip/map/trip_map_view.dart`
- Modify: `test/google_trip_map_surface_test.dart`
- Modify: `test/trip_map_view_test.dart`

**Interfaces:**
- Consumes: `TripMapModel.routeSegments` and `TripMapRouteSegment` from Task 3.
- Produces: one uniquely keyed polyline and arrow per segment; the fallback lists the same segment order.

- [ ] **Step 1: Write failing Google Map rendering tests**

Update the connector test to use three same-day/different-day Entries and assert two unique lines and arrows:

```dart
expect(
  polylines.map((line) => line.polylineId.value).toSet(),
  {
    'entry-day-1-to-nice',
    'entry-nice-to-ur',
  },
);
expect(
  arrows.map((marker) => marker.markerId.value).toSet(),
  {
    'entry-day-1-to-nice-arrow',
    'entry-nice-to-ur-arrow',
  },
);
```

Retain the geodesic and antimeridian assertions using the renamed segment type.

- [ ] **Step 2: Write a failing fallback route test**

Replace the adjacent-day-only assertion in `test/trip_map_view_test.dart` with Day 2 `nice` and `UR`. Expect two cards in order and exact titles:

```dart
expect(find.text('Day 1 → Day 2'), findsOneWidget);
expect(find.text('Day 2 route'), findsOneWidget);
expect(find.text('Trailhead → Nice place'), findsOneWidget);
expect(find.text('Nice place → UR place'), findsOneWidget);
```

- [ ] **Step 3: Run both surface tests and confirm RED**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\google_trip_map_surface_test.dart test\trip_map_view_test.dart
```

Expected: old code still reads `connectors` and accepts `TripMapDayConnector`.

- [ ] **Step 4: Render general segments in Google Map**

Rename local loop variables from connector to segment, consume `model.routeSegments`, and update `_googleTripMapArrowMarker` and `_arrowPosition` to accept `TripMapRouteSegment`. Preserve colors, arrow placement, bearing calculation, geodesic lines, and z-indexes.

- [ ] **Step 5: Render general segments in fallback mode**

For each segment, use:

```dart
final routeTitle = segment.fromDay == segment.toDay
    ? 'Day ${segment.fromDay} route'
    : 'Day ${segment.fromDay} → Day ${segment.toDay}';
```

Keep the subtitle as `${segment.fromLabel} → ${segment.toLabel}` and key each card with `trip-map-fallback-route-${segment.id}`.

- [ ] **Step 6: Run surface and map tests and confirm GREEN**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\trip_map_model_test.dart test\google_trip_map_surface_test.dart test\trip_map_view_test.dart
```

Expected: all files pass.

- [ ] **Step 7: Commit the rendering changes**

```powershell
git add -- lib/features/trip/map/google_trip_map_surface.dart lib/features/trip/map/trip_map_view.dart test/google_trip_map_surface_test.dart test/trip_map_view_test.dart
git commit -m "feat(map): draw complete entry-ordered routes"
```

---

### Task 5: Regression Verification and Cloud Migration

**Files:**
- Verify only: all files changed in Tasks 1-4
- Preserve: `web/index.html`

**Interfaces:**
- Consumes: completed immutable ordering, migration, route model, and surfaces.
- Produces: verified application code and an applied schema migration; no test data.

- [ ] **Step 1: Format only changed Dart files**

Run `dart format` with the explicit changed Dart file list. Do not format or modify `web/index.html`.

- [ ] **Step 2: Run focused tests**

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test test\models_test.dart test\create_edit_entry_location_test.dart test\supabase_journal_repository_test.dart test\journal_creation_order_migration_test.dart test\trip_map_model_test.dart test\google_trip_map_surface_test.dart test\trip_map_view_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 3: Run static analysis**

```powershell
D:\Download\flutter-sdk\bin\flutter.bat analyze --no-pub
```

Expected: `No issues found!`

- [ ] **Step 4: Run the complete Flutter suite**

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test
```

Expected: zero failures; only existing documented platform-conditioned skips are acceptable.

- [ ] **Step 5: Review the final diff and protected local change**

Run:

```powershell
git status --short
git diff --check -- . ':(exclude)web/index.html'
git diff main...HEAD --stat
```

Expected: `web/index.html` remains modified but unstaged; no whitespace errors in task-owned files; no secrets or unrelated files appear.

- [ ] **Step 6: Apply only the pending migration to linked cloud Supabase**

Use the existing linked project metadata and an already available authenticated Supabase CLI/runtime. If no CLI is available, stop and report that deployment prerequisite rather than downloading a large toolchain to C:. Run a dry-run/list command first, verify that `202608290001_journal_entry_creation_order.sql` is the only intended pending migration, then push it. Do not print tokens or session details, and do not insert or update journal test data.

- [ ] **Step 7: Build and run for user acceptance**

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
$env:GRADLE_USER_HOME='D:\FlutterCache\gradle'
D:\Download\flutter-sdk\bin\flutter.bat run -d emulator-5554 `
  --dart-define=BACKEND_MODE=supabase `
  --dart-define-from-file=.local\maps_defines.json
```

The user verifies their coursework data manually. Codex does not create a test Trip or modify unrelated Entries.

- [ ] **Step 8: Commit any verification-only adjustments**

If formatting or verification required task-owned corrections, stage only those explicit files and commit:

```powershell
git commit -m "test(map): cover entry-ordered routes"
```

If there are no additional changes, do not create an empty commit.

