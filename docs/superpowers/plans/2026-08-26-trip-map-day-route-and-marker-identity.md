# Trip Map Day Route and Marker Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep distinct entry coordinates as distinct map markers and make Day N display the cumulative route from Day 1 through Day N, with the final mapped day matching All.

**Architecture:** Keep `buildTripMapModel` as the pure source of truth for Google Maps and the fallback UI. Strengthen group identity with normalized coordinates, then replace the previous-day-only model with an inclusive day range so marker visibility and adjacent-day connectors are derived by the same rule.

**Tech Stack:** Flutter, Dart, Riverpod UI consumers, `google_maps_flutter`, `flutter_test`.

## Global Constraints

- Work stays on the existing `trip-module` branch.
- Preserve the user's uncommitted `web/index.html` modification.
- Do not expose API keys, Supabase sessions, or signing credentials.
- Do not mutate Supabase production data.
- Emulator acceptance, if needed, uses only a Trip whose name contains `TEST`.
- Missing days are not bridged.
- The route remains journal order only, not road navigation.

---

## File Structure

- `lib/features/trip/map/trip_map_model.dart`: owns marker grouping, cumulative visibility, connector derivation, and map bounds.
- `lib/features/trip/map/trip_map_view.dart`: renders filters, disclaimer, previews, and fallback data from the model.
- `lib/features/trip/map/google_trip_map_surface.dart`: converts model groups/connectors into native Google markers, arrows, and polylines.
- `test/trip_map_model_test.dart`: pure regression coverage for identity, deletion safety, cumulative filtering, and missing-day rules.
- `test/trip_map_view_test.dart`: widget-level cumulative filter and fallback behavior.
- `test/google_trip_map_surface_test.dart`: native marker identity and connector rendering boundary.

### Task 1: Make Marker Identity Coordinate-Safe

**Files:**
- Modify: `lib/features/trip/map/trip_map_model.dart`
- Test: `test/trip_map_model_test.dart`
- Test: `test/google_trip_map_surface_test.dart`

**Interfaces:**
- Consumes: `GeoTag.placeId`, `GeoTag.latitude`, and `GeoTag.longitude`.
- Produces: `TripMapMarkerGroup.key` values that merge only equal normalized locations and become `MarkerId` values in `googleTripMapMarkers`.

- [ ] **Step 1: Write the failing model regression test**

Add a test with a shared Place ID but distinct coordinates. The production change this catches is returning to a Place-ID-only group key.

```dart
test('keeps different coordinates separate when Place IDs match', () {
  final model = buildTripMapModel(
    entries: [
      journalEntry(
        id: 'day-2-second',
        createdAt: tripStart.add(const Duration(days: 1, hours: 2)),
        location: const GeoTag(
          latitude: 3.1579,
          longitude: 101.7123,
          placeId: 'broad-place-id',
        ),
      ),
      journalEntry(
        id: 'day-3',
        createdAt: tripStart.add(const Duration(days: 2)),
        location: const GeoTag(
          latitude: 3.1390,
          longitude: 101.6869,
          placeId: 'broad-place-id',
        ),
      ),
    ],
    tripStartDate: tripStart,
    tripEndDate: tripEnd,
  );

  expect(model.groups, hasLength(2));
  expect(model.groups.map((group) => group.entries.single.id), [
    'day-2-second',
    'day-3',
  ]);
  expect(model.groups.map((group) => group.key).toSet(), hasLength(2));
});
```

Extend the existing same-Place-ID test so equal normalized coordinates still produce one group. Use literal expected entry IDs rather than deriving the expectation from `_groupKey`.

- [ ] **Step 2: Run the focused model test and verify RED**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test test\trip_map_model_test.dart --plain-name "keeps different coordinates separate when Place IDs match"
```

Expected: FAIL because the current `place:broad-place-id` key collapses both entries into one group.

- [ ] **Step 3: Implement the minimal composite group identity**

In `trip_map_model.dart`, centralize coordinate formatting and include it in Place-ID-backed keys:

```dart
String _groupKey(GeoTag location) {
  final coordinateKey = _coordinateKey(location);
  final placeId = location.placeId?.trim();
  if (placeId != null && placeId.isNotEmpty) {
    return 'place:$placeId:$coordinateKey';
  }
  return 'coord:$coordinateKey';
}

String _coordinateKey(GeoTag location) =>
    '${location.latitude.toStringAsFixed(6)},'
    '${_normalizedLongitude(location.longitude).toStringAsFixed(6)}';
```

Keep `_sameMappedLocation` consistent by comparing non-empty equal Place IDs only when `_coordinateKey(a) == _coordinateKey(b)`, and otherwise comparing coordinate keys. This prevents a connector from being suppressed merely because two distinct coordinates share one Place ID.

- [ ] **Step 4: Verify the focused model tests are GREEN**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test test\trip_map_model_test.dart
```

Expected: PASS, including existing same-location and ±180 longitude coverage.

- [ ] **Step 5: Add and verify the Google marker boundary regression**

In `test/google_trip_map_surface_test.dart`, build the same two-group model and assert that `googleTripMapMarkers` returns two distinct `MarkerId` values and both literal coordinates. This catches any future surface-layer ID truncation or reuse.

```dart
final markers = googleTripMapMarkers(model: model, onSelected: (_) {});
expect(markers, hasLength(2));
expect(markers.map((marker) => marker.markerId).toSet(), hasLength(2));
expect(markers.map((marker) => marker.position).toSet(), {
  const LatLng(3.1579, 101.7123),
  const LatLng(3.1390, 101.6869),
});
```

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\google_trip_map_surface_test.dart
```

Expected: PASS after the model fix.

- [ ] **Step 6: Commit the identity fix**

```powershell
git add -- lib/features/trip/map/trip_map_model.dart test/trip_map_model_test.dart test/google_trip_map_surface_test.dart
git commit -m "fix(map): keep distinct entry locations separate"
```

### Task 2: Replace Previous-Day Context With a Cumulative Day Route

**Files:**
- Modify: `lib/features/trip/map/trip_map_model.dart`
- Test: `test/trip_map_model_test.dart`

**Interfaces:**
- Consumes: `buildTripMapModel(..., selectedDay: int?)`.
- Produces: `TripMapModel.groups` and `TripMapModel.connectors` containing Day 1 through selected Day N inclusive; `selectedDay == null` continues to mean All.

- [ ] **Step 1: Replace the previous-context test with a failing cumulative-route test**

Use five explicitly timed entries: two on Day 1, two on Day 2, and one on Day 3. Assert literal IDs and connector IDs so an off-by-one range fails visibly.

```dart
test('Day N includes the cumulative route through that day', () {
  final entries = [
    journalEntry(id: 'day-1-first', createdAt: tripStart,
      location: const GeoTag(latitude: 1, longitude: 2)),
    journalEntry(id: 'day-1-last',
      createdAt: tripStart.add(const Duration(hours: 2)),
      location: const GeoTag(latitude: 2, longitude: 3)),
    journalEntry(id: 'day-2-first',
      createdAt: tripStart.add(const Duration(days: 1)),
      location: const GeoTag(latitude: 3, longitude: 4)),
    journalEntry(id: 'day-2-second',
      createdAt: tripStart.add(const Duration(days: 1, hours: 2)),
      location: const GeoTag(latitude: 4, longitude: 5)),
    journalEntry(id: 'day-3',
      createdAt: tripStart.add(const Duration(days: 2)),
      location: const GeoTag(latitude: 5, longitude: 6)),
  ];

  final day2 = buildTripMapModel(
    entries: entries,
    tripStartDate: tripStart,
    tripEndDate: tripEnd,
    selectedDay: 2,
  );
  expect(day2.groups.expand((group) => group.entries).map((entry) => entry.id),
    ['day-1-first', 'day-1-last', 'day-2-first', 'day-2-second']);
  expect(day2.connectors.map((connector) => connector.id),
    ['day-1-to-day-2']);

  final day3 = buildTripMapModel(
    entries: entries,
    tripStartDate: tripStart,
    tripEndDate: tripEnd,
    selectedDay: 3,
  );
  final all = buildTripMapModel(
    entries: entries,
    tripStartDate: tripStart,
    tripEndDate: tripEnd,
  );
  expect(day3.groups.map((group) => group.key),
    all.groups.map((group) => group.key));
  expect(day3.connectors.map((connector) => connector.id),
    ['day-1-to-day-2', 'day-2-to-day-3']);
});
```

- [ ] **Step 2: Add the failing deletion-safety regression**

Using the same fixture, remove only `day-2-second`, rebuild Day 3 and All, and assert `day-3` remains in both models and `day-2-to-day-3` still targets `(5, 6)`. The production change this catches is a shared group identity or selected range that drops the Day 3 marker when a Day 2 marker is removed.

```dart
final remaining = entries.where((entry) => entry.id != 'day-2-second').toList();
final model = buildTripMapModel(
  entries: remaining,
  tripStartDate: tripStart,
  tripEndDate: tripEnd,
  selectedDay: 3,
);
expect(model.groups.expand((group) => group.entries)
    .map((entry) => entry.id), contains('day-3'));
final connector = model.connectors.singleWhere(
  (candidate) => candidate.id == 'day-2-to-day-3',
);
expect((connector.toLatitude, connector.toLongitude), (5, 6));
```

- [ ] **Step 3: Run the new tests and verify RED**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\trip_map_model_test.dart --plain-name "Day N includes the cumulative route through that day"
```

Expected: FAIL because selected Day 2 currently includes only Day 2 plus one muted Day 1 stop, and selected Day 3 emits only the Day 2→3 connector.

- [ ] **Step 4: Implement cumulative visible entries and connectors**

In `buildTripMapModel`, replace previous-day context construction with an inclusive visible range:

```dart
final visible = selectedDay == null
    ? mapped
    : [
        for (final entry in mapped)
          if (_dayNumber(entry.createdAt, tripStartDate) >= 1 &&
              _dayNumber(entry.createdAt, tripStartDate) <= selectedDay)
            entry,
      ];
```

Delete the block that appends `isPreviousDayContext` and change `_connectorsFor` so selected Day N considers source days below N:

```dart
final fromDays = selectedDay == null
    ? availableDays.where((day) => day >= 1)
    : availableDays.where((day) => day >= 1 && day < selectedDay);
```

The existing lookup of `mappedByDay[fromDay + 1]` continues to reject missing-day bridges.

Remove `TripMapMarkerGroup.isPreviousDayContext`, `TripMapModel.previousDayHasNoMappedEntry`, their constructor parameters, and all model construction assignments because cumulative history no longer has a special previous-day marker state.

- [ ] **Step 5: Verify model GREEN and missing-day behavior**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\trip_map_model_test.dart
```

Expected: PASS. Update obsolete previous-context assertions to cumulative literal expectations; keep the existing missing-day tests and assert no `day-1-to-day-2` connector when Day 2 has no mapped entry.

- [ ] **Step 6: Commit the cumulative model**

```powershell
git add -- lib/features/trip/map/trip_map_model.dart test/trip_map_model_test.dart
git commit -m "feat(map): show cumulative routes by trip day"
```

### Task 3: Align Map UI and Native Surface With the Cumulative Model

**Files:**
- Modify: `lib/features/trip/map/trip_map_view.dart`
- Modify: `lib/features/trip/map/google_trip_map_surface.dart`
- Test: `test/trip_map_view_test.dart`
- Test: `test/google_trip_map_surface_test.dart`

**Interfaces:**
- Consumes: simplified `TripMapMarkerGroup` and `TripMapModel` from Task 2.
- Produces: normal markers for every cumulative group, no previous-day warning, and fallback lists whose Day N contents match the model.

- [ ] **Step 1: Write failing widget expectations for cumulative filtering**

Replace the previous-day-warning widget test with one that taps Day 2 and records the model passed to the real test map builder:

```dart
TripMapModel? rendered;
await tester.pumpWidget(view(
  entries: entries,
  mapBuilder: ({required model, required onSelected}) {
    rendered = model;
    return const SizedBox.expand();
  },
));
await tester.tap(find.byKey(const Key('trip-map-day-2')));
await tester.pump();
expect(rendered!.groups.expand((group) => group.entries)
    .map((entry) => entry.id), ['day-1', 'day-2-first', 'day-2-second']);
expect(rendered!.connectors.map((connector) => connector.id),
    ['day-1-to-day-2']);
expect(find.text('Previous day has no mapped entry'), findsNothing);
```

The production change this catches is restoring the previous-day-only UI contract.

- [ ] **Step 2: Run widget and surface tests and verify RED/compile failures**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\trip_map_view_test.dart test\google_trip_map_surface_test.dart
```

Expected: FAIL until the warning/context rendering and constructor fixtures are updated for the simplified model.

- [ ] **Step 3: Remove obsolete previous-day presentation**

In `trip_map_view.dart`, remove the `Previous day has no mapped entry` conditional. In the fallback list, always use the regular location icon and render subtitles as:

```dart
'Day ${group.dayNumber} · '
'${group.entries.length} ${group.entries.length == 1 ? 'entry' : 'entries'}'
```

In `google_trip_map_surface.dart`, remove previous-context alpha, blue icon, and info-window branches. Every marker becomes:

```dart
alpha: 1,
icon: BitmapDescriptor.defaultMarker,
infoWindow: InfoWindow(title: 'D${group.dayNumber}'),
```

Update direct `TripMapModel` and `TripMapMarkerGroup` test fixtures to the simplified constructors. Replace the old muted-context surface test with a test asserting that a Day 2 cumulative model produces regular D1 and D2 markers.

Update widget selectors that intentionally address Place-ID-backed markers to
use the new composite literal keys, for example
`fake-map-place:one:1.000000,2.000000`. Coordinate-only selectors retain the
existing `fake-map-coord:<latitude>,<longitude>` form.

- [ ] **Step 4: Verify focused UI and surface tests are GREEN**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\trip_map_view_test.dart test\google_trip_map_surface_test.dart
```

Expected: PASS with no previous-day warning or muted marker assertions.

- [ ] **Step 5: Run all map-focused tests**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test test\trip_map_model_test.dart test\trip_map_view_test.dart test\google_trip_map_surface_test.dart test\trip_view_map_tab_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit the UI alignment**

```powershell
git add -- lib/features/trip/map/trip_map_view.dart lib/features/trip/map/google_trip_map_surface.dart test/trip_map_view_test.dart test/google_trip_map_surface_test.dart
git commit -m "fix(map): align day filters with cumulative routes"
```

### Task 4: Full Verification

**Files:**
- Verify only: all tracked Flutter sources and tests.

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: evidence that analysis and the full test suite pass without modifying user data.

- [ ] **Step 1: Confirm only intended files changed**

Run:

```powershell
git status --short
git diff main...HEAD --stat
```

Expected: map implementation/tests and the two planning documents are tracked changes/commits; `web/index.html` remains the user's separate unstaged modification.

- [ ] **Step 2: Run Flutter analysis**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
$env:GRADLE_USER_HOME='D:\FlutterCache\gradle'
D:\Download\flutter-sdk\bin\flutter.bat analyze --no-pub
```

Expected: exit code 0 and no issues.

- [ ] **Step 3: Run the complete Flutter test suite**

Run:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test
```

Expected: exit code 0 with zero failures; platform-conditional skips are acceptable when explicitly reported by the test runner.

- [ ] **Step 4: Review final diff and status**

Run:

```powershell
git diff main...HEAD --check
git status --short --branch
```

Expected: no whitespace errors; `web/index.html` remains unstaged and untouched by this work.

- [ ] **Step 5: Commit any test-only expectation adjustments from full verification**

Only if full-suite compatibility required an intended map-related test adjustment:

```powershell
git add -- test
git commit -m "test(map): update cumulative route expectations"
```

Do not stage `web/index.html`.
