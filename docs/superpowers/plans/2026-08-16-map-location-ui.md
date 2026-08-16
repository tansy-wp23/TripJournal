# Trip Map and Entry Location UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an `Entries | Map` experience and optional searchable/pinnable entry locations while preserving every current Trip, photo, wellness, notes, summary, search and filter behavior.

**Architecture:** Pure Dart functions derive marker groups, day counts and bounds from the existing `JournalController` entry list. Flutter widgets receive injectable map builders and `PlaceSearchService`; Google rendering and Supabase Places calls stay behind adapters, and missing keys fall back to a navigable located-entry list.

**Tech Stack:** Flutter, Riverpod, `google_maps_flutter`, Supabase Functions client, existing `JournalEntry`/`GeoTag` models.

## Global Constraints

- Plan 1 must be green before this plan begins.
- Search and Mood/Date filters affect Entries only; Map has its own Day filter.
- No GPS, current-location or background-location permission is requested.
- A location remains optional and Trip destination is never converted into a marker.
- Do not commit real Google or Supabase keys.
- Preserve the current trip-photo carousel/slideshow, meal photos, PDF export, responsive fixes, Admin and User Management code.

---

### Task 1: Compatible location model and removable copy semantics

**Files:**
- Modify: `lib/models/geo_tag.dart`
- Modify: `lib/models/journal_entry.dart`
- Modify: `test/models_test.dart`

**Interfaces:**
- Produces: `GeoTag(latitude, longitude, placeName, formattedAddress, placeId)`.
- Produces: `JournalEntry.copyWith({GeoTag? location, bool clearLocation = false})`.

- [ ] **Step 1: Write failing round-trip and removal tests**

Test old three-field JSON, full five-field JSON, and `clearLocation: true`.

```dart
final full = GeoTag(
  latitude: 3.139,
  longitude: 101.6869,
  placeName: 'Merdeka Square',
  formattedAddress: 'Jalan Raja, Kuala Lumpur',
  placeId: 'place-123',
);
expect(GeoTag.fromJson(full.toJson()).placeId, 'place-123');
expect(entry.copyWith(clearLocation: true).location, isNull);
```

- [ ] **Step 2: Verify tests fail**

Run `flutter test --no-pub test/models_test.dart`. Expected: missing fields and `clearLocation` parameter.

- [ ] **Step 3: Extend the models**

Add nullable `formattedAddress` and `placeId` to `GeoTag`, JSON and `copyWith`. In `JournalEntry.copyWith`, assert that a caller cannot provide a location and clear it simultaneously:

```dart
JournalEntry copyWith({
  GeoTag? location,
  bool clearLocation = false,
  // existing parameters remain
}) {
  assert(!(clearLocation && location != null));
  return JournalEntry(
    // existing fields remain
    location: clearLocation ? null : (location ?? this.location),
  );
}
```

- [ ] **Step 4: Run tests and commit**

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test/models_test.dart
git add lib/models/geo_tag.dart lib/models/journal_entry.dart test/models_test.dart
git commit -m "feat: extend journal entry locations"
```

### Task 2: Pure Trip Map view model

**Files:**
- Create: `lib/features/trip/map/trip_map_model.dart`
- Create: `test/trip_map_model_test.dart`

**Interfaces:**
- Produces: `TripMapBounds`, `TripMapMarkerGroup`, `TripMapModel`.
- Produces: `TripMapModel buildTripMapModel({required List<JournalEntry> entries, required DateTime tripStartDate, int? selectedDay})`.

- [ ] **Step 1: Write failing pure-Dart cases**

Cover zero, one and multiple coordinates; identical `placeId`; no-ID coordinates rounded to six decimals; mapped/unmapped counts; Day selection; and bounds. Include an entry at `2026-08-16 00:15` local to assert it remains on its calendar day.

- [ ] **Step 2: Verify the file fails to compile**

Run `flutter test --no-pub test/trip_map_model_test.dart`. Expected: missing map model types.

- [ ] **Step 3: Implement deterministic grouping**

Use keys `place:<trimmedPlaceId>` or `coord:<lat6>,<lng6>`. Derive the day with date-only local values and sort entries/groups chronologically. Return bounds only when at least two distinct groups exist.

- [ ] **Step 4: Run and commit**

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test/trip_map_model_test.dart
git add lib/features/trip/map/trip_map_model.dart test/trip_map_model_test.dart
git commit -m "feat: derive trip map markers"
```

### Task 3: Map-agnostic Trip Map UI and fallback

**Files:**
- Create: `lib/features/trip/map/trip_map_view.dart`
- Create: `test/trip_map_view_test.dart`

**Interfaces:**
- Consumes: `buildTripMapModel` from Task 2.
- Produces: `TripMapBuilder` and `TripMapView` with `onOpenEntry` and `onAddLocation` callbacks.
- Produces: `TripMapUnavailableSurface`.

- [ ] **Step 1: Write widget tests with a fake surface**

The fake surface renders one button per marker group and invokes `onSelected`. Test empty state, `N mapped · M without location`, All/Day chips, duplicate-entry previews, preview navigation and fallback list navigation.

- [ ] **Step 2: Verify the tests fail for missing widgets**

Run `flutter test --no-pub test/trip_map_view_test.dart`.

- [ ] **Step 3: Implement the UI**

Build a `Column` containing counts, horizontal `ChoiceChip`s, expanded map surface and a constrained preview list. Each preview shows date, `displayTitle`, location label, mood and the first existing photo through `PhotoThumbnail`. Empty state includes `Add location to an entry`. Fallback lists every visible group and remains navigable.

- [ ] **Step 4: Run and commit**

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test/trip_map_view_test.dart
git add lib/features/trip/map/trip_map_view.dart test/trip_map_view_test.dart
git commit -m "feat: add trip map view and fallback"
```

### Task 4: Google map surface and platform configuration

**Files:**
- Create: `lib/features/trip/map/google_trip_map_surface.dart`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `web/index.html`
- Modify: `.env.example`
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `test/settings_screen_test.dart`
- Create: `docs/MAP_LOCATION_SETUP.md`
- Test: `test/map_location_deployment_contract_test.dart`

**Interfaces:**
- Produces: `GoogleTripMapSurface(model, onSelected)` implementing `TripMapBuilder` behavior.
- Produces: compile-time/environment flags that select Google surface only when a platform-restricted rendering key is configured.

- [ ] **Step 1: Write deployment contract tests**

Assert `.env.example` contains names only (`GOOGLE_MAPS_ANDROID_KEY`, `GOOGLE_MAPS_IOS_KEY`, `GOOGLE_MAPS_WEB_KEY`), no value matching `AIza`; manifests contain placeholders rather than real keys; setup docs specify package/SHA, bundle ID and referrer restrictions. Add a Settings widget test that scrolls to About, taps `Legal notices`, and finds Flutter's `LicensePage` even when map configuration is absent.

- [ ] **Step 2: Add `google_maps_flutter` and resolve on D:**

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat pub add google_maps_flutter
```

- [ ] **Step 3: Implement markers and camera behavior**

Create markers labeled `D${group.dayNumber}`. A tap invokes `onSelected(group)`. For one group use zoom 12; for multiple groups call `CameraUpdate.newLatLngBounds` after the map is ready. Catch controller/platform errors and render `TripMapUnavailableSurface` with a Retry button.

- [ ] **Step 4: Add restricted-key setup without secrets**

Document Android package + SHA restriction, iOS bundle restriction and Web referrer restriction. Inject native placeholders through local non-versioned configuration and use fallback when absent. Do not add current-location flags.

Add `ListTile(title: Text('Legal notices'))` under Settings → About and call `showLicensePage(context: context, applicationName: 'TripJournal')` from its tap callback.

- [ ] **Step 5: Verify and commit**

Run deployment contract test, `flutter analyze --no-pub`, and `flutter build web --release --no-pub`.

```powershell
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml ios/Runner/AppDelegate.swift web/index.html .env.example docs/MAP_LOCATION_SETUP.md lib/features/trip/map/google_trip_map_surface.dart lib/features/settings/settings_screen.dart test/map_location_deployment_contract_test.dart test/settings_screen_test.dart
git commit -m "feat: configure Google trip map surface"
```

### Task 5: Entries and Map tabs in the current Trip screen

**Files:**
- Modify: `lib/features/trip/trip_view_screen.dart`
- Modify: `test/trip_view_screen_test.dart`
- Create: `test/trip_view_map_tab_test.dart`

**Interfaces:**
- Consumes: `TripMapView` and Google/fallback builder.
- Preserves: existing `JournalFilter`, `_searchVisible`, timeline scroll storage, photo carousel and Trip actions.

- [ ] **Step 1: Write coexistence and state-retention tests**

Assert both tabs exist; Search/Filter app-bar actions disappear only on Map; entering a query and Mood filter, switching Map then Entries, preserves both; Map still receives all trip entries; photo carousel remains visible in Entries.

- [ ] **Step 2: Verify tests fail**

Run both Trip View test files.

- [ ] **Step 3: Add tab state without rebuilding controllers**

Use `DefaultTabController(length: 2)` or a locally owned `TabController`. Put the current Entries body in an `IndexedStack` child with a `PageStorageKey`, and Map in the second child. Read entries once from `journalControllerProvider`; pass unfiltered entries to Map. Gate Search/Filter actions on selected index.

- [ ] **Step 4: Verify and commit**

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test/trip_view_screen_test.dart
D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test/trip_view_map_tab_test.dart
git add lib/features/trip/trip_view_screen.dart test/trip_view_screen_test.dart test/trip_view_map_tab_test.dart
git commit -m "feat: add Entries and Map trip tabs"
```

### Task 6: Places service and authenticated Edge Function contract

**Files:**
- Create: `lib/features/location/place_search_service.dart`
- Create: `lib/features/location/place_search_locator.dart`
- Create: `supabase/functions/places-proxy/index.ts`
- Modify: `supabase/config.toml`
- Create: `test/place_search_service_test.dart`
- Create: `supabase/functions/places-proxy/places_proxy_test.ts`

**Interfaces:**
- Produces: `PlaceSuggestion`, `PlaceSearchException`, `PlaceSearchService`.
- Produces: `SupabasePlaceSearchService({required PlaceFunctionInvoker invoke})`.
- Edge actions: `search`, `resolve`, `reverse`.

- [ ] **Step 1: Write Dart response-validation tests**

Cover trimmed blank query, valid suggestions, malformed payload, timeout/provider error mapping, coordinate range rejection and full `GeoTag` resolution.

- [ ] **Step 2: Implement the Dart boundary**

Use the exact interface approved in the design. Production locator invokes `Supabase.instance.client.functions.invoke('places-proxy', body: {'action': action, ...body})` and converts non-2xx responses to `PlaceSearchException` without including the original query or coordinates.

- [ ] **Step 3: Write Deno function tests**

Test unauthenticated 401, OPTIONS 204 with `Access-Control-Allow-Origin/Headers/Methods`, query length 2..120, coordinate ranges, maximum five suggestions, 429 rate limit and sanitized provider failure.

- [ ] **Step 4: Implement the proxy**

Validate JWT with Supabase Auth, apply an in-memory per-user short-window limiter, use an `AbortController` timeout, call Google Places/Geocoding with `GOOGLE_PLACES_SERVER_KEY`, and never log request bodies. Return CORS headers on every response.

- [ ] **Step 5: Verify and commit**

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test/place_search_service_test.dart
deno test supabase/functions/places-proxy/places_proxy_test.ts --allow-env
git add lib/features/location supabase/functions/places-proxy supabase/config.toml test/place_search_service_test.dart
git commit -m "feat: proxy authenticated place search"
```

### Task 7: Place Picker and Entry editor integration

**Files:**
- Create: `lib/features/location/place_picker_screen.dart`
- Create: `lib/features/location/google_place_picker_map.dart`
- Modify: `lib/features/journal/screens/create_edit_entry_screen.dart`
- Create: `test/place_picker_screen_test.dart`
- Create: `test/create_edit_entry_location_test.dart`

**Interfaces:**
- Produces: `PlacePickerScreen(service, mapBuilder, initialLocation)` returning `GeoTag?` through Navigator.
- Consumes: `PlaceSearchService` and `JournalEntry.copyWith(clearLocation:)`.

- [ ] **Step 1: Write picker tests**

Use a fake service/map builder. Test search, result resolution, draggable pin, reverse failure retaining coordinate label, confirm, cancel, retry and keeping the prior selection after a provider error.

- [ ] **Step 2: Implement the picker**

Search only on submit and ignore blank input. While reverse geocoding, immediately set a six-decimal coordinate label so Confirm remains meaningful. Render errors with Retry without clearing `_selected`.

- [ ] **Step 3: Write editor tests**

Test Add, Change, Remove and Save. Add a gated repository test that double-taps Save and asserts one repository call and one stable entry UUID.

- [ ] **Step 4: Integrate editor state and save guard**

Add `GeoTag? _location` and `bool _saving`. Disable Save before confirmation/persistence begins, generate the draft ID once, and pass `_location` into the persisted `JournalEntry`. Location section displays name/address and Change/Remove actions. Removing uses `clearLocation: true` when editing.

- [ ] **Step 5: Verify current photo and responsive behavior**

Run location tests plus all `create_edit_entry_*`, photo, meal-photo and responsive tests. Expected: existing photo flows remain unchanged.

- [ ] **Step 6: Commit**

```powershell
git add lib/features/location lib/features/journal/screens/create_edit_entry_screen.dart test/place_picker_screen_test.dart test/create_edit_entry_location_test.dart
git commit -m "feat: add optional entry location picker"
```
