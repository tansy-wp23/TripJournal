# Map & Location Integration Design

## Goal

Integrate the previously developed Trip Map and Entry Location experience into
the latest `main` without merging the obsolete map branch wholesale. The final
feature lets a traveler attach an optional place to a journal entry, browse the
trip through `Entries | Map`, and reopen the same entry, place and photos on
another device.

The integration must preserve the newer User Management, trip-photo carousel,
meal-photo, PDF, responsive-layout and Admin work already present on `main`.

## Delivery sequence

### Phase 0: restore a trustworthy baseline

The freshly updated `main` passes `flutter analyze` but currently has ten
failing widget tests in code-entry, login/admin-entry, responsive-login and
suspended-account flows. Diagnose these failures before map work. Fix test
isolation or real asynchronous UI defects without weakening assertions or
changing intended authentication behavior.

Map implementation starts only after the complete Flutter suite is green.

### Phase 1: map experience on current application state

Add `Entries | Map` inside `TripViewScreen`. Existing summary, wellness, notes,
photo carousel, search, filters and timeline stay under Entries. Search and
mood/date filters do not affect the map and their state survives tab changes.

The Map tab uses the already loaded entries from `JournalController`. It shows
only entries with explicit coordinates, supports `All / Day 1 / Day 2...`,
groups identical Google Place IDs or normalized coordinates, labels markers by
trip day, and opens existing Entry Detail from marker previews. It never
invents coordinates from Trip destination and never draws a route.

Empty and failed-map states retain a list of located entries so journal content
is still reachable. Google Maps is enabled only when platform keys are
configured; the fallback remains usable without a key.

### Phase 2: entry location capture

Extend `GeoTag` compatibly with `formattedAddress` and `placeId`. Old JSON with
only coordinates and `placeName` continues to load.

Create/Edit Entry gains optional Add, Change and Remove Location actions. The
picker supports Places text search and a draggable center pin. Search selection
saves name, formatted address, Place ID and coordinates. Reverse-geocoding
failure still permits saving coordinates with a coordinate display label.

The app does not request current-location, GPS or background-location
permission. A location is recorded only after explicit user confirmation.

## Service and data architecture

### Places boundary

Flutter depends on an injectable `PlaceSearchService`; widgets never call
Google or Supabase directly. Production requests go through an authenticated
Supabase `places-proxy` Edge Function. The function validates input, limits
results, enforces a timeout and basic per-user rate limiting, supports browser
CORS, and does not log full queries or coordinates.

Map rendering uses separate restricted Android, iOS and Web client keys.
Places and reverse-geocoding use a server-only restricted key stored in
Supabase secrets. No real key is committed.

### Repository unification

The latest `main` has real Supabase Auth/Profile but still defaults Trip and
Journal to mocks; `SupabaseJournalRepository` and `SupabasePhotoStorage` are
not implemented. Production activation therefore includes one explicit
backend configuration that selects Auth, current user, Trip, Journal, trip
covers and journal/meal photos as a consistent set. A mode must never combine
mock Trip IDs with Supabase Journal writes.

Complete Supabase Trip and Journal persistence using the existing public
interfaces. Journal bundle writes cover Entry, HealthLog, Meals, photo URLs and
location atomically. AI advice uses a narrow update so a delayed generation
cannot overwrite a newer entry edit. Rapid Save taps produce one entry.

Adapt location photo work to the current `PhotoStorage` abstraction instead of
introducing the obsolete branch's second photo-storage interface. Removed or
deleted objects are cleaned best-effort after the database mutation; newly
uploaded objects are rolled back if the database write fails. Existing network
photo rendering and PDF behavior remain the source of truth.

### Database compatibility

Add nullable location columns to `journal_entries` with coordinate range and
paired-null constraints. No PostGIS is needed. Existing rows remain valid and
are not backfilled.

The repository reads `entry_date` as the journal calendar day so UTC timestamps
cannot move an entry to the previous day after reload. RLS continues to enforce
trip ownership. The migration and complete schema stay synchronized, and SQL
regression tests cover RPC signatures and ownership.

## Failure behavior and privacy

- Missing map keys show the located-entry fallback rather than breaking Trip.
- Places timeout, invalid response and provider errors are user-visible and
  retryable; they do not erase the current selection.
- Failed location or photo persistence leaves the editor open with its input.
- Entries without a location remain fully usable and count as unmapped.
- Lock-screen notifications, logs and analytics receive no precise coordinates
  or place-search history.
- Legal Notices remains reachable from Settings.

## Verification and rollout

Unit tests cover GeoTag compatibility, marker grouping, day filtering, bounds,
timezone boundaries, Places parsing and Supabase mapping. Widget tests cover
tab state, map filters, preview navigation, picker flows, location removal,
fallbacks and coexistence with the current trip-photo UI. Repository tests
cover authenticated CRUD, atomic child writes, photo rollback and RLS.

Before integration: run `flutter analyze`, the full Flutter suite, Web release
build, Edge Function type checks and Supabase database tests. Android/iOS real
maps, Places search, key restrictions and cross-device reload require device
acceptance after cloud configuration.

Deploy schema and Edge Function before enabling the production backend. The
mock mode remains available for tests and offline demonstration, but backend
selection is explicit rather than inferred from partial initialization.

## Branch migration and cleanup

Implementation occurs on `map-location-integration`, created from the latest
`main`. Code is selectively ported; the old commits are not merged. After the
new branch is integrated and verified, remove the old
`map-location-module` worktree and branch. Do not create an archival branch or
tag.
