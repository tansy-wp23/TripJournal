# Map Location Supabase Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist Trips, journal bundles, photos and entry locations consistently in Supabase so data survives restart and works across devices.

**Architecture:** One explicit backend mode constructs a complete mock stack or complete Supabase stack; partial mixing is impossible. Supabase RPCs atomically write journal entry/health/meal/location data, while storage adapters upload before database mutation and compensate on failure; AI advice uses a narrow optimistic update.

**Tech Stack:** Supabase Auth/Postgres/RLS/Storage/Edge Functions, Flutter Supabase client, existing repository interfaces.

## Global Constraints

- Map UI plan must pass in mock mode before production persistence is enabled.
- Deploy schema and Edge Function before enabling Supabase mode.
- Existing rows with null location remain valid; no PostGIS and no backfill.
- Journal calendar grouping reads `entry_date`, not the UTC date portion of `created_at`.
- Journal/meal photo URLs must remain compatible with current network rendering and PDF export.
- Database ownership is enforced by RLS and verified with two-user SQL tests.

---

### Task 1: Explicit all-mock or all-Supabase backend graph

**Files:**
- Create: `lib/data/backend_mode.dart`
- Create: `lib/data/backend_services.dart`
- Modify: `lib/data/user_management_repository_locator.dart`
- Modify: `lib/data/trip_repository_locator.dart`
- Modify: `lib/data/repository_locator.dart`
- Modify: `lib/main.dart`
- Create: `test/backend_services_test.dart`

**Interfaces:**
- Produces: `enum BackendMode { mock, supabase }`.
- Produces: `BackendServices.mock()` and `BackendServices.supabase(SupabaseClient client)` containing Auth, Profile, CurrentUser, Trip, TripCover, Journal and Photo services.

- [ ] **Step 1: Write graph consistency tests**

Assert mock mode exposes only mock implementations. Use fake Supabase client dependencies or type checks to assert Supabase mode exposes no mock Trip/Journal/current-user service. Assert invalid/missing `BACKEND_MODE` defaults to `mock` in tests and fails visibly in release configuration.

- [ ] **Step 2: Implement the service graph**

Construct every repository in one factory and expose it through Riverpod providers or lazy locator getters. Parse `BACKEND_MODE=mock|supabase` once at startup. Remove independent top-level choices that could combine mock Trip IDs with Supabase Journal writes.

- [ ] **Step 3: Verify and commit**

Run backend graph, auth locator, Trip controller and Journal controller tests.

```powershell
git add lib/data/backend_mode.dart lib/data/backend_services.dart lib/data/user_management_repository_locator.dart lib/data/trip_repository_locator.dart lib/data/repository_locator.dart lib/main.dart test/backend_services_test.dart
git commit -m "refactor: unify application backend selection"
```

### Task 2: Location schema, atomic RPC and RLS

**Files:**
- Create: `supabase/migrations/202608160002_journal_location_persistence.sql`
- Modify: `tripjournal_schema.sql`
- Create: `supabase/tests/journal_location_persistence_test.sql`
- Modify: `supabase/tests/purge_claim_safety_test.sql`

**Interfaces:**
- Produces nullable columns: `location_latitude`, `location_longitude`, `location_place_name`, `location_formatted_address`, `location_place_id`.
- Produces RPC `upsert_journal_entry_bundle(...)` and `delete_journal_entry_bundle(p_entry_id uuid)`.
- Produces RPC `set_journal_ai_advice(p_entry_id uuid, p_health_log_id uuid, p_advice text, p_expected_updated_at timestamptz)`.

- [ ] **Step 1: Write SQL regression tests first**

Test paired-null and coordinate range constraints, old null rows, one-user CRUD, second-user denial, atomic health/meal writes, rollback on an invalid child, the current seven-argument `restore_trip` signature, and stale `expected_updated_at` rejection.

- [ ] **Step 2: Verify tests fail against the current schema**

Run a local Supabase reset/database test using Docker data rooted on D:. Expected: missing journal tables/RPCs or location columns.

- [ ] **Step 3: Implement migration and complete schema**

Add checks:

```sql
check (location_latitude is null or location_latitude between -90 and 90),
check (location_longitude is null or location_longitude between -180 and 180),
check ((location_latitude is null) = (location_longitude is null))
```

Create an index on `journal_entries (trip_id, entry_date)` filtered with `where location_latitude is not null`. RPCs derive ownership from `auth.uid()` and perform bundle mutation in one transaction.

- [ ] **Step 4: Run SQL tests and commit**

```powershell
supabase db reset
supabase test db
git add supabase/migrations/202608160002_journal_location_persistence.sql tripjournal_schema.sql supabase/tests/journal_location_persistence_test.sql supabase/tests/purge_claim_safety_test.sql
git commit -m "feat: add journal location persistence schema"
```

### Task 3: Journal Supabase mapper

**Files:**
- Create: `lib/data/journal_supabase_mapper.dart`
- Create: `test/journal_supabase_mapper_test.dart`

**Interfaces:**
- Produces: `JournalEntry journalEntryFromSupabase(Map<String, dynamic> row)`.
- Produces: `Map<String, dynamic> journalEntryBundleRpcParams(JournalEntry entry, {required String userId})`.

- [ ] **Step 1: Write mapper tests**

Cover null/full location, meals including current `photoPath`, `photo_urls`, mood fallback, and a row whose `created_at` is previous-day UTC while `entry_date` is the intended UTC+08 calendar day.

- [ ] **Step 2: Implement calendar-safe mapping**

Parse `created_at` to local time for the clock, parse `entry_date` for year/month/day, then construct one local `DateTime` combining them. Map all location columns and preserve current meal-photo fields.

- [ ] **Step 3: Verify and commit**

```powershell
D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test/journal_supabase_mapper_test.dart
git add lib/data/journal_supabase_mapper.dart test/journal_supabase_mapper_test.dart
git commit -m "feat: map Supabase journal bundles"
```

### Task 4: Journal and photo storage implementations

**Files:**
- Modify: `lib/data/supabase_journal_repository.dart`
- Modify: `lib/data/supabase_photo_storage.dart`
- Modify: `lib/data/photo_storage.dart`
- Create: `test/supabase_journal_repository_test.dart`
- Create: `test/supabase_photo_storage_test.dart`

**Interfaces:**
- Consumes: mapper/RPCs from Tasks 2–3.
- Produces: complete `JournalRepository` CRUD.
- Produces: `SupabasePhotoStorage` returning canonical Storage URLs/paths compatible with current renderers.

- [ ] **Step 1: Write fake-client repository tests**

Test authenticated load/add/update/delete, unauthenticated rejection, full location mapping, atomic RPC invocation, server error propagation, and `setJournalAiAdvice` narrow update. Test upload success, unsupported source fallback, upload rollback after database failure, and best-effort deletion.

- [ ] **Step 2: Implement repository CRUD**

`getEntries` selects entries with nested health logs/meals ordered by `entry_date, created_at`. Add/update call `upsert_journal_entry_bundle`; delete calls the delete RPC. Require `auth.currentUser` before mutation and never accept a user ID from UI state as ownership authority.

- [ ] **Step 3: Implement Storage behavior**

Upload journal and meal photos to user-scoped object paths. Persist canonical public/signed URL descriptors used by the existing `PhotoThumbnail`, `PhotoViewerScreen` and PDF loader. If DB write fails after an upload, delete only objects uploaded by that attempt. After a successful mutation, delete replaced objects best-effort.

- [ ] **Step 4: Verify photo compatibility**

Run Supabase repository/storage tests and all existing photo thumbnail/viewer, meal-photo, cleanup and PDF tests.

- [ ] **Step 5: Commit**

```powershell
git add lib/data/supabase_journal_repository.dart lib/data/supabase_photo_storage.dart lib/data/photo_storage.dart test/supabase_journal_repository_test.dart test/supabase_photo_storage_test.dart
git commit -m "feat: persist journal bundles and photos"
```

### Task 5: Concurrent save and AI advice protection

**Files:**
- Modify: `lib/features/journal/controller/journal_controller.dart`
- Modify: `lib/features/journal/screens/create_edit_entry_screen.dart`
- Modify: `lib/data/journal_repository.dart`
- Modify: `lib/data/mock_journal_repository.dart`
- Modify: `lib/data/supabase_journal_repository.dart`
- Modify: `test/journal_controller_advice_test.dart`
- Modify: `test/create_edit_entry_save_flow_test.dart`

**Interfaces:**
- Produces: `JournalRepository.setAiAdvice({required String entryId, required String healthLogId, required String advice, required DateTime expectedUpdatedAt})`.
- Consumes: editor `_saving` guard from UI plan Task 7.

- [ ] **Step 1: Write delayed-advice and double-save regressions**

Use completers to hold advice and repository saves. Save edit A, begin advice, save edit B, release advice, then assert B's title/body/location/meals remain while advice is added. Double-tap Save and assert one stable entry/health ID and one add/update call.

- [ ] **Step 2: Add the narrow repository method**

Mock implementation updates only `healthLog.aiAdvice`. Supabase implementation calls `set_journal_ai_advice`; a stale timestamp returns a typed conflict and triggers a refetch instead of overwriting the entry bundle.

- [ ] **Step 3: Change controller advice flow**

Replace full `updateEntry(staleEntry.copyWith(...))` with `setAiAdvice(...)`, then reload the entry. Keep generation failure user-visible without reverting current edits.

- [ ] **Step 4: Verify and commit**

Run controller advice, editor save-flow, location and meal recompute tests.

```powershell
git add lib/features/journal/controller/journal_controller.dart lib/features/journal/screens/create_edit_entry_screen.dart lib/data/journal_repository.dart lib/data/mock_journal_repository.dart lib/data/supabase_journal_repository.dart test/journal_controller_advice_test.dart test/create_edit_entry_save_flow_test.dart
git commit -m "fix: protect journal saves from stale advice"
```

### Task 6: Production integration, cloud checks and old branch cleanup

**Files:**
- Modify: `.env.example`
- Modify: `README.md`
- Modify: `docs/MAP_LOCATION_SETUP.md`
- Test: complete Flutter, Web, Edge and SQL suites

**Interfaces:**
- Produces: documented deployment order: schema → Storage/RLS → Places secret/function → platform rendering keys → `BACKEND_MODE=supabase`.

- [ ] **Step 1: Document environment and deployment order**

List variable names without values, Google API restrictions, Supabase secret command, local D:-drive cache policy, rollback to `BACKEND_MODE=mock`, and Android/iOS/Web acceptance checklist.

- [ ] **Step 2: Run automated verification**

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
$flutter='D:\Download\flutter-sdk\bin\flutter.bat'
& $flutter pub get
& $flutter analyze --no-pub
Get-ChildItem test -Filter '*_test.dart' | ForEach-Object { & $flutter test --no-pub $_.FullName; if ($LASTEXITCODE -ne 0) { throw "Test failed: $($_.Name)" } }
& $flutter build web --release --no-pub
deno test supabase/functions/places-proxy/places_proxy_test.ts --allow-env
supabase db reset
supabase test db
```

Expected: all automated checks pass; logs contain neither exact place queries/coordinates nor server keys.

- [ ] **Step 3: Perform device/cloud acceptance**

On signed-in Android, iOS and Edge sessions: create a Trip, add an Entry with a searched location and photos, reload on a second session, verify the marker/preview/photos, change and remove location, confirm Day filters, deny wrong package/bundle/referrer keys, and confirm fallback when the key is absent.

- [ ] **Step 4: Commit rollout documentation**

```powershell
git add .env.example README.md docs/MAP_LOCATION_SETUP.md
git commit -m "docs: add map location rollout guide"
```

- [ ] **Step 5: Integrate the replacement branch**

Push `map-location-integration`, review its diff against `main`, and merge only after automated and device acceptance are recorded. Confirm `main` contains the replacement commits before removing the obsolete source.

- [ ] **Step 6: Remove the obsolete branch and worktree without an archive**

Resolve and verify exact paths first:

```powershell
git -C D:\Download\TripJournal worktree list
git -C D:\Download\TripJournal branch --merged main
```

Only after `map-location-integration` is merged and the old path is confirmed as `D:\Download\TripJournal\.worktrees\map-location-module`:

```powershell
git -C D:\Download\TripJournal worktree remove D:\Download\TripJournal\.worktrees\map-location-module
git -C D:\Download\TripJournal branch -d map-location-module
```

Expected: current main and `map-location-integration` history remain intact; no archival branch or tag is created.
