# Trip Management MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Complete Trip Management with Supabase CRUD, public cover-photo storage, and a recoverable 30-day trash while preserving the existing Flutter UI and mock-first workflow.

**Architecture:** Keep Trip, TripRepository, Riverpod controllers, and the existing screens as the stable boundaries. Add injectable current-user and cover-storage adapters, keep mock adapters selected by default, and place permanent cleanup in a scheduled Supabase Edge Function.

**Tech Stack:** Flutter, Dart 3.12+, Riverpod, supabase_flutter 2.16, uuid 4.6, PostgreSQL/RLS, Supabase Storage, Supabase Edge Functions, Deno.

## Global Constraints

- Mock repositories remain selected until the Authentication module provides a real Supabase session.
- Do not modify files under lib/features/auth or the user-management repositories.
- Use the existing Trip model; do not create a second trip entity.
- Bucket name: trip-covers. Maximum cover size: 32 MB.
- Trash retention: exactly 30 x 24 hours from deleted_at.
- The app does not expose permanent deletion.
- Current shell prerequisite: place Flutter, Deno, and Supabase CLI on PATH before executing verification commands.

---

### Task 1: Add UUID and Trash Domain Foundations

**Files:**
- Modify: pubspec.yaml
- Modify: pubspec.lock
- Modify: lib/models/trip.dart
- Modify: lib/features/trip/mock_user.dart
- Modify: test/trip_model_test.dart

**Interfaces:**
- Produces: Trip.deletedAt, Trip.trashExpiresAt, Trip.isRecoverableAt(DateTime), Trip.remainingRecoveryDaysAt(DateTime)
- Produces: valid UUID mock user ID and uuid package for new trip IDs

- [ ] **Step 1: Add failing Trip trash-boundary tests**

Add tests that construct a Trip with deletedAt and assert:

    final deletedAt = DateTime.utc(2026, 8, 5, 2, 15);
    final trip = tripFixture(deletedAt: deletedAt);

    expect(trip.trashExpiresAt, DateTime.utc(2026, 9, 4, 2, 15));
    expect(trip.isRecoverableAt(DateTime.utc(2026, 9, 4, 2, 14, 59)), isTrue);
    expect(trip.isRecoverableAt(DateTime.utc(2026, 9, 4, 2, 15)), isFalse);
    expect(
      trip.remainingRecoveryDaysAt(DateTime.utc(2026, 8, 5, 14, 15)),
      30,
    );

Also verify copyWith(clearDeletedAt: true) returns a Trip with deletedAt == null.

- [ ] **Step 2: Run the focused tests and confirm failure**

Run:

    flutter test test/trip_model_test.dart

Expected: compilation fails because the trash fields and helpers do not exist.

- [ ] **Step 3: Add the domain fields and dependency**

Add:

    dependencies:
      uuid: ^4.6.0

Extend Trip with:

    final DateTime? deletedAt;

    DateTime? get trashExpiresAt =>
        deletedAt?.toUtc().add(const Duration(days: 30));

    bool isRecoverableAt(DateTime now) {
      final expiry = trashExpiresAt;
      return expiry != null && now.toUtc().isBefore(expiry);
    }

    int remainingRecoveryDaysAt(DateTime now) {
      final expiry = trashExpiresAt;
      if (expiry == null) return 0;
      final seconds = expiry.difference(now.toUtc()).inSeconds;
      if (seconds <= 0) return 0;
      return (seconds / Duration.secondsPerDay).ceil();
    }

Update the constructor, fromJson, toJson, and copyWith. copyWith must accept:

    DateTime? deletedAt,
    bool clearDeletedAt = false,

and assign null when clearDeletedAt is true.

Change kMockUserId to:

    const kMockUserId = '00000000-0000-0000-0000-000000000001';

Run flutter pub get so pubspec.lock records uuid 4.6.x.

- [ ] **Step 4: Run focused and related tests**

Run:

    flutter test test/trip_model_test.dart test/mock_trip_repository_test.dart

Expected: all tests pass after fixtures using literal user-001 are updated to kMockUserId.

- [ ] **Step 5: Commit**

    git add pubspec.yaml pubspec.lock lib/models/trip.dart lib/features/trip/mock_user.dart test/trip_model_test.dart test/mock_trip_repository_test.dart
    git commit -m "feat(trip): add UUID and trash lifecycle fields"

---

### Task 2: Add the Current-User Boundary

**Files:**
- Create: lib/data/current_user_id_provider.dart
- Create: lib/data/mock_current_user_id_provider.dart
- Create: lib/data/supabase_current_user_id_provider.dart
- Create: test/current_user_id_provider_test.dart
- Modify: lib/data/trip_repository_locator.dart

**Interfaces:**
- Produces: CurrentUserIdProvider.requireUserId() -> String
- Produces: UnauthenticatedTripUserException
- Keeps: MockCurrentUserIdProvider selected in the locator

- [ ] **Step 1: Write failing provider tests**

Cover:

    expect(MockCurrentUserIdProvider().requireUserId(), kMockUserId);

Create a SupabaseClient with no active session and verify:

    expect(
      () => SupabaseCurrentUserIdProvider(client).requireUserId(),
      throwsA(isA<UnauthenticatedTripUserException>()),
    );

- [ ] **Step 2: Run and confirm failure**

    flutter test test/current_user_id_provider_test.dart

Expected: compilation fails because the provider classes do not exist.

- [ ] **Step 3: Implement the providers**

Define:

    abstract interface class CurrentUserIdProvider {
      String requireUserId();
    }

    final class UnauthenticatedTripUserException implements Exception {
      const UnauthenticatedTripUserException();

      @override
      String toString() => 'Please sign in to manage trips.';
    }

Mock implementation returns kMockUserId. Supabase implementation receives SupabaseClient in its constructor and returns client.auth.currentUser?.id, throwing the typed exception when null.

Add to trip_repository_locator.dart:

    final CurrentUserIdProvider currentUserIdProvider =
        MockCurrentUserIdProvider();

Do not activate SupabaseCurrentUserIdProvider yet.

- [ ] **Step 4: Run tests**

    flutter test test/current_user_id_provider_test.dart

Expected: all provider tests pass.

- [ ] **Step 5: Commit**

    git add lib/data/current_user_id_provider.dart lib/data/mock_current_user_id_provider.dart lib/data/supabase_current_user_id_provider.dart lib/data/trip_repository_locator.dart test/current_user_id_provider_test.dart
    git commit -m "feat(trip): add current user adapter"

---

### Task 3: Implement Trip Mapping and Supabase Persistence

**Files:**
- Create: lib/data/trip_supabase_mapper.dart
- Create: test/trip_supabase_mapper_test.dart
- Create: test/supabase_trip_repository_test.dart
- Modify: lib/data/trip_repository.dart
- Modify: lib/data/mock_trip_repository.dart
- Modify: lib/data/supabase_trip_repository.dart
- Modify: test/mock_trip_repository_test.dart

**Interfaces:**
- Produces: tripFromSupabaseRow(Map<String, dynamic>) -> Trip
- Produces: tripToSupabaseRow(Trip) -> Map<String, dynamic>
- Adds: TripRepository.getDeletedTrips, moveToTrash, restoreTrip
- Removes: client-side TripRepository.deleteTrip

- [ ] **Step 1: Write failing mapper tests**

Use a row containing snake_case keys and assert every Trip property, including deletedAt. Verify outbound dates:

    expect(row['start_date'], '2026-08-05');
    expect(row['end_date'], '2026-08-07');
    expect(row['deleted_at'], isNull);
    expect(row, isNot(contains('createdAt')));

- [ ] **Step 2: Run mapper tests and confirm failure**

    flutter test test/trip_supabase_mapper_test.dart

Expected: compilation fails because mapper functions do not exist.

- [ ] **Step 3: Implement the mapper**

Map these fields exactly:

    id <-> id
    userId <-> user_id
    title <-> title
    coverPhotoPath <-> cover_photo_url
    startDate <-> start_date
    endDate <-> end_date
    notes <-> notes
    createdAt <-> created_at
    updatedAt <-> updated_at
    deletedAt <-> deleted_at

Use a private date-only formatter that pads month and day to two digits.

- [ ] **Step 4: Extend the repository contract and mock**

Replace deleteTrip with:

    Future<List<Trip>> getDeletedTrips(String userId);
    Future<void> moveToTrash(String id);
    Future<void> restoreTrip(Trip trip);

MockTripRepository receives an optional DateTime Function() clock. getTrips returns only deletedAt == null. getDeletedTrips returns recoverable deleted trips for the user, ordered by deletedAt descending. moveToTrash stamps clock().toUtc(). restoreTrip replaces the row and clears deletedAt.

Update tests to prove active queries hide trashed trips, trash queries show them, restore returns them to active queries, and the exact 30-day boundary is excluded.

- [ ] **Step 5: Run mock repository tests**

    flutter test test/mock_trip_repository_test.dart

Expected: all mock lifecycle tests pass.

- [ ] **Step 6: Write failing Supabase repository tests**

Use package:http/testing.dart MockClient with an injected SupabaseClient. Assert:

- GET requests include user_id and deleted_at filters.
- Insert and update bodies use snake_case fields.
- moveToTrash calls /rest/v1/rpc/move_trip_to_trash with p_trip_id.
- restoreTrip calls /rest/v1/rpc/restore_trip with the full editable trip payload.
- API errors propagate to the controller so it can retain the previously loaded list.

- [ ] **Step 7: Implement SupabaseTripRepository**

Use:

    client.from('trips').select().eq('user_id', userId).isFilter('deleted_at', null)

For deleted rows use:

    client.from('trips').select().eq('user_id', userId).not('deleted_at', 'is', null)

Map rows through tripFromSupabaseRow and filter expired trash items with an injected clock. Use maybeSingle for getTrip. Use insert and update with tripToSupabaseRow. Use RPC calls for moveToTrash and restoreTrip.

- [ ] **Step 8: Run repository tests**

    flutter test test/trip_supabase_mapper_test.dart test/mock_trip_repository_test.dart test/supabase_trip_repository_test.dart

Expected: all tests pass.

- [ ] **Step 9: Commit**

    git add lib/data/trip_repository.dart lib/data/mock_trip_repository.dart lib/data/supabase_trip_repository.dart lib/data/trip_supabase_mapper.dart test/trip_supabase_mapper_test.dart test/mock_trip_repository_test.dart test/supabase_trip_repository_test.dart
    git commit -m "feat(trip): implement Supabase trip persistence"

---

### Task 4: Add the Database Migration and Storage Policies

**Files:**
- Create: supabase/migrations/202608050001_trip_management_mvp.sql
- Modify: tripjournal_schema.sql

**Interfaces:**
- Produces RPC: move_trip_to_trash(p_trip_id uuid)
- Produces RPC: restore_trip(p_trip_id uuid, p_title text, p_cover_photo_url text, p_start_date date, p_end_date date, p_notes text)
- Produces bucket: trip-covers

- [ ] **Step 1: Add the migration**

The migration must:

    alter table public.trips
      add column if not exists deleted_at timestamptz;

    create index if not exists trips_user_deleted_at_idx
      on public.trips (user_id, deleted_at);

    drop policy if exists "trips_delete_own" on public.trips;

Create move_trip_to_trash as SECURITY INVOKER. It updates only an active trip where user_id = auth.uid(), sets deleted_at and updated_at to now(), and raises trip_not_found when no row is updated.

Create restore_trip as SECURITY INVOKER. Before updating it must:

1. Load the deleted trip owned by auth.uid().
2. Raise trip_restore_expired if deleted_at + interval '30 days' <= now().
3. Raise trip_restore_overlap when another active trip for the user intersects the proposed inclusive date range.
4. Update title, cover URL, dates, notes, updated_at, and deleted_at = null in one statement.

Grant execute on both functions to authenticated.

Create the bucket idempotently:

    insert into storage.buckets (
      id, name, public, file_size_limit, allowed_mime_types
    ) values (
      'trip-covers',
      'trip-covers',
      true,
      33554432,
      array['image/jpeg', 'image/png', 'image/webp']
    )
    on conflict (id) do update set
      public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

Drop any policy with the same name before creation. Add INSERT, SELECT, UPDATE, and DELETE storage.objects policies for authenticated users where bucket_id = 'trip-covers' and the first folder equals auth.uid()::text.

- [ ] **Step 2: Update the canonical schema**

Mirror deleted_at, the index, RPCs, bucket configuration, and removal of the client hard-delete policy in tripjournal_schema.sql so a new Supabase project matches the migration result.

- [ ] **Step 3: Perform static SQL checks**

Run:

    rg -n "deleted_at|move_trip_to_trash|restore_trip|trip-covers" supabase/migrations/202608050001_trip_management_mvp.sql tripjournal_schema.sql

Expected: both files contain the same schema contract and no client trip DELETE policy remains.

- [ ] **Step 4: Apply to a non-production Supabase project**

After Supabase CLI is available:

    supabase db reset

Expected: migration completes without SQL errors and the disposable database exposes both RPCs and the trip-covers bucket.

- [ ] **Step 5: Commit**

    git add supabase/migrations/202608050001_trip_management_mvp.sql tripjournal_schema.sql
    git commit -m "feat(trip): add trash and cover storage schema"

---

### Task 5: Implement Cover Storage and Rendering

**Files:**
- Create: lib/data/trip_cover_storage.dart
- Create: lib/data/mock_trip_cover_storage.dart
- Create: lib/data/supabase_trip_cover_storage.dart
- Create: test/trip_cover_storage_test.dart
- Modify: lib/data/trip_repository_locator.dart
- Modify: lib/features/trip/widgets/trip_cover_photo.dart
- Modify: test/trip_cover_photo_test.dart

**Interfaces:**
- Produces: uploadCover(userId, tripId, localPath) -> public URL
- Produces: deleteCoverUrl(String?) -> void
- Keeps: MockTripCoverStorage selected by default

- [ ] **Step 1: Write failing path and adapter tests**

Verify a generated object path matches:

    00000000-0000-0000-0000-000000000001/
    550e8400-e29b-41d4-a716-446655440000/
    cover-7d9f2f8f-4a77-4f08-b64f-21cfa2f609a1.jpg

Verify uppercase extensions normalize to lowercase, unsupported extensions use .jpg, public URLs parse back to the object path, and non-trip-covers URLs are ignored by deleteCoverUrl.

- [ ] **Step 2: Run and confirm failure**

    flutter test test/trip_cover_storage_test.dart

Expected: compilation fails because storage adapters do not exist.

- [ ] **Step 3: Implement the storage interface**

Define:

    abstract interface class TripCoverStorage {
      Future<String> uploadCover({
        required String userId,
        required String tripId,
        required String localPath,
      });

      Future<void> deleteCoverUrl(String? publicUrl);
    }

MockTripCoverStorage returns localPath and performs no deletion.

SupabaseTripCoverStorage receives SupabaseClient and Uuid. Upload with FileOptions(cacheControl: '3600', upsert: false), then return getPublicUrl(objectPath). Deletion must parse only URLs with /storage/v1/object/public/trip-covers/.

- [ ] **Step 4: Add the mock adapter to the locator**

Add:

    final TripCoverStorage tripCoverStorage = MockTripCoverStorage();

Keep SupabaseTripCoverStorage available but do not assign it to the locator until Auth integration.

- [ ] **Step 5: Extend cover rendering**

TripCoverPhoto chooses:

    http/https URL -> Image.network
    existing local file -> Image.file
    null, missing file, or image error -> placeholder

Both Image.network and Image.file must use BoxFit.cover and the existing errorBuilder placeholder.

- [ ] **Step 6: Run focused tests**

    flutter test test/trip_cover_storage_test.dart test/trip_cover_photo_test.dart

Expected: path, mock adapter, public URL, local file fallback, network widget, and placeholder tests pass.

- [ ] **Step 7: Commit**

    git add lib/data/trip_cover_storage.dart lib/data/mock_trip_cover_storage.dart lib/data/supabase_trip_cover_storage.dart lib/data/trip_repository_locator.dart lib/features/trip/widgets/trip_cover_photo.dart test/trip_cover_storage_test.dart test/trip_cover_photo_test.dart
    git commit -m "feat(trip): add cover photo storage"

---

### Task 6: Integrate Identity, UUIDs, Cover Rollback, and Soft Delete

**Files:**
- Modify: lib/features/trip/controller/trip_controller.dart
- Modify: lib/features/trip/trip_form_screen.dart
- Modify: lib/features/trip/trip_view_screen.dart
- Modify: lib/features/trip/widgets/delete_trip_confirmation_dialog.dart
- Modify: lib/features/home/home_screen.dart
- Modify: test/trip_controller_validation_test.dart
- Modify: test/trip_form_cover_photo_test.dart
- Modify: test/delete_confirmation_dialogs_test.dart
- Create: test/trip_controller_cover_storage_test.dart

**Interfaces:**
- TripController receives TripCoverStorage
- createTrip and editTrip upload local covers before persistence
- moveToTrash replaces deleteTrip
- cleanupWarning is non-blocking and clearable

- [ ] **Step 1: Write failing controller orchestration tests**

Use a recording fake TripCoverStorage and throwing fake TripRepository to prove:

- Create uploads a local cover and persists the returned public URL.
- Create database failure deletes the new upload.
- Edit success deletes the previous remote cover after persistence.
- Edit failure deletes only the new upload and retains the previous URL.
- Removing a cover persists null and then deletes the previous remote cover.
- Old-cover cleanup failure sets cleanupWarning without changing the successful save result.
- moveToTrash does not call JournalRepository.deleteEntry.

- [ ] **Step 2: Run and confirm failure**

    flutter test test/trip_controller_cover_storage_test.dart

Expected: tests fail because TripController has no storage orchestration or soft-delete method.

- [ ] **Step 3: Implement controller orchestration**

Inject tripCoverStorage through tripControllerProvider. Treat http and https cover values as already uploaded; treat other non-null values as local.

For create and edit:

1. Validate before uploading.
2. Upload only when the cover is local.
3. Persist a copy carrying the returned public URL.
4. Roll back the new URL on repository failure.
5. Delete the previous URL only after a successful update.

Replace deleteTrip with:

    Future<String?> moveToTrash(String id)

It calls TripRepository.moveToTrash, refreshes active trips, and never deletes journal data.

- [ ] **Step 4: Update form identity and IDs**

For a new trip:

    final tripId = const Uuid().v4();
    final userId = currentUserIdProvider.requireUserId();

Catch UnauthenticatedTripUserException and display its message in the form. Existing trips retain their original ID and userId.

- [ ] **Step 5: Replace permanent-delete UI copy and calls**

The dialog text becomes:

    Move "Kyoto Trip" to Recently Deleted?
    You can restore it for 30 days.

Use button label Move to Trash. Remove entry-count language because journal data is retained.

Update both TripFormScreen and TripViewScreen to call moveToTrash. After success, return to Home and refresh the dashboard.

- [ ] **Step 6: Run focused regression tests**

    flutter test test/trip_controller_validation_test.dart test/trip_controller_cover_storage_test.dart test/trip_form_cover_photo_test.dart test/delete_confirmation_dialogs_test.dart test/trip_view_screen_test.dart

Expected: all focused tests pass and no test expects permanent deletion.

- [ ] **Step 7: Commit**

    git add lib/features/trip/controller/trip_controller.dart lib/features/trip/trip_form_screen.dart lib/features/trip/trip_view_screen.dart lib/features/trip/widgets/delete_trip_confirmation_dialog.dart lib/features/home/home_screen.dart test/trip_controller_validation_test.dart test/trip_controller_cover_storage_test.dart test/trip_form_cover_photo_test.dart test/delete_confirmation_dialogs_test.dart
    git commit -m "feat(trip): persist covers and move trips to trash"

---

### Task 7: Build Recently Deleted and Conflict-Safe Restore

**Files:**
- Create: lib/features/trip/controller/trip_trash_controller.dart
- Create: lib/features/trip/screens/trip_trash_screen.dart
- Create: test/trip_trash_controller_test.dart
- Create: test/trip_trash_screen_test.dart
- Create: test/trip_form_restore_test.dart
- Modify: lib/features/trip/trip_form_screen.dart
- Modify: lib/features/home/home_screen.dart

**Interfaces:**
- Produces: TripRestoreStatus { restored, conflict, expired, failed }
- Produces: TripRestoreResult with status, conflict, and message
- Produces: TripTrashController.load, restore, restoreWithChanges

- [ ] **Step 1: Write failing controller tests**

Inject a fixed clock and cover:

- Deleted trips load newest first.
- Restore before expiry succeeds and removes the item from trash.
- Restore at the exact expiry instant returns expired.
- An overlapping active trip returns conflict and names that Trip.
- restoreWithChanges rejects an invalid range.
- restoreWithChanges succeeds after dates no longer overlap.
- Repository failure returns failed while retaining the trash item.

- [ ] **Step 2: Run and confirm failure**

    flutter test test/trip_trash_controller_test.dart

Expected: compilation fails because trash controller and restore results do not exist.

- [ ] **Step 3: Implement TripTrashController**

Use ChangeNotifier and a Riverpod ChangeNotifierProvider. Dependencies are TripRepository and CurrentUserIdProvider, with an injectable DateTime Function() clock.

restore must:

1. Recheck isRecoverableAt(clock()).
2. Load active trips for the same user.
3. Call findOverlappingTrip.
4. Return conflict without writing when overlap exists.
5. Call repository.restoreTrip when valid.
6. Reload the trash list after success.

restoreWithChanges repeats validation and sends the edited Trip to the repository RPC so date changes and deleted_at clearing are atomic.

- [ ] **Step 4: Write failing widget tests**

TripTrashScreen must cover:

- AppBar title Recently Deleted.
- Empty state No recently deleted trips.
- Deletion date, expiration date, and remaining-day text.
- Restore confirmation.
- Success returns true to Home.
- Conflict opens TripFormScreen in restore mode.
- Expired item has no enabled Restore action.

HomeScreen test must open the profile menu and find Recently Deleted.

- [ ] **Step 5: Implement the screen and navigation**

Add Recently Deleted to the existing Home profile menu above Settings. Home awaits the screen result; when true, it reloads dashboard data.

TripTrashScreen lists recoverable trips. On successful direct restore, pop with true. On conflict, open:

    TripFormScreen(
      existingTrip: trip,
      restoreOnSave: true,
    )

Restore mode changes the title to Restore trip, hides the delete action, validates overlap, calls TripTrashController.restoreWithChanges, and pops success back through Trash to Home.

- [ ] **Step 6: Run focused tests**

    flutter test test/trip_trash_controller_test.dart test/trip_trash_screen_test.dart test/trip_form_restore_test.dart test/home_screen_nudge_test.dart

Expected: trash loading, expiry, direct restore, conflict edit, and Home refresh tests pass.

- [ ] **Step 7: Commit**

    git add lib/features/trip/controller/trip_trash_controller.dart lib/features/trip/screens/trip_trash_screen.dart lib/features/trip/trip_form_screen.dart lib/features/home/home_screen.dart test/trip_trash_controller_test.dart test/trip_trash_screen_test.dart test/trip_form_restore_test.dart
    git commit -m "feat(trip): add recently deleted recovery"

---

### Task 8: Implement Scheduled Permanent Purge

**Files:**
- Create: supabase/functions/purge-deleted-trips/purge.ts
- Create: supabase/functions/purge-deleted-trips/index.ts
- Create: supabase/functions/purge-deleted-trips/purge_test.ts

**Interfaces:**
- HTTP header: x-cron-secret
- Environment: PURGE_CRON_SECRET, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
- Schedule: 15 2 * * * in UTC

- [ ] **Step 1: Write failing Deno tests for the pure purge service**

Use an injected PurgeGateway and cover:

- Wrong or missing x-cron-secret returns 401.
- A valid secret processes only expired trips.
- Cover URLs from trip-covers and journal photo URLs from journal-photos are parsed and removed.
- Missing Storage objects are treated as success.
- Any real Storage error keeps that trip row.
- A failure for one trip does not block another trip.
- Database deletion occurs only after all required Storage deletions succeed.

- [ ] **Step 2: Run and confirm failure**

    deno test supabase/functions/purge-deleted-trips/purge_test.ts

Expected: tests fail because the purge service does not exist.

- [ ] **Step 3: Implement purge.ts**

Define a PurgeGateway with:

    listExpiredTrips(cutoffIso)
    listJournalPhotoUrls(tripId)
    removeObjects(bucket, paths)
    permanentlyDeleteTrip(tripId)

Implement parsePublicStorageUrl for:

    /storage/v1/object/public/{bucket}/{objectPath}

Process trips independently. Skip null URLs. Treat not-found object responses as successful cleanup. Return a summary containing processed, deleted, and failed counts.

- [ ] **Step 4: Implement index.ts**

The HTTP handler:

1. Accepts POST only.
2. Compares x-cron-secret with PURGE_CRON_SECRET.
3. Creates a Supabase service-role client inside the function.
4. Computes cutoff as current UTC time minus 30 days.
5. Invokes the purge service.
6. Returns JSON summary with status 200.
7. Returns 401 for authorization failure and 500 only for request-wide initialization failure.

Never return secrets or service-role credentials in response bodies or logs.

- [ ] **Step 5: Run Edge Function tests**

    deno test supabase/functions/purge-deleted-trips/purge_test.ts

Expected: all authorization, cleanup ordering, retry, and independent processing tests pass.

- [ ] **Step 6: Deploy and schedule in a non-production project**

    $purgeSecretBytes = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Fill($purgeSecretBytes)
    $purgeSecret = [Convert]::ToBase64String($purgeSecretBytes)
    supabase functions deploy purge-deleted-trips --no-verify-jwt
    supabase secrets set "PURGE_CRON_SECRET=$purgeSecret"

In Supabase Dashboard, create Cron HTTP job:

    Name: purge-deleted-trips-daily
    Schedule: 15 2 * * *
    Method: POST
    URL: copy the deployed purge-deleted-trips function URL from the Supabase Dashboard
    Header name: x-cron-secret
    Header value: use the purgeSecret value generated in the deployment session

Invoke once with an invalid secret and once with the configured secret. Confirm 401 then 200, and inspect Cron history after the scheduled run.

- [ ] **Step 7: Commit**

    git add supabase/functions/purge-deleted-trips
    git commit -m "feat(trip): purge expired trash safely"

---

### Task 9: Final Integration and Verification

**Files:**
- Modify only files required by analyzer or test failures from Tasks 1-8

**Interfaces:**
- Confirms mock adapters remain active
- Confirms production activation is a locator-only change after Auth integration

- [ ] **Step 1: Format changed source and tests**

    dart format lib test
    deno fmt supabase/functions/purge-deleted-trips

- [ ] **Step 2: Run static analysis**

    flutter analyze

Expected: No issues found.

- [ ] **Step 3: Run the complete Flutter test suite**

    flutter test

Expected: all tests pass with zero failures.

- [ ] **Step 4: Run the Edge Function suite**

    deno test supabase/functions/purge-deleted-trips/purge_test.ts

Expected: all tests pass.

- [ ] **Step 5: Verify module boundaries**

Run:

    git diff origin/main -- lib/features/auth lib/data/user_management_repository_locator.dart

Expected: no Trip Management commit changes Authentication-owned files.

Run:

    rg -n "MockTripRepository|MockCurrentUserIdProvider|MockTripCoverStorage" lib/data/trip_repository_locator.dart

Expected: all three mock adapters remain selected.

- [ ] **Step 6: Perform manual mock-mode acceptance**

Verify:

1. Home loads seeded trips.
2. Create and edit accept a local cover.
3. Delete moves a trip to Recently Deleted without losing journal data.
4. Restore succeeds when dates do not overlap.
5. Restore conflict opens the date-edit flow.
6. The exact expiration boundary disables restore.
7. Settings and Log out behavior remain unchanged.

- [ ] **Step 7: Perform production activation check after Auth is ready**

Change only trip_repository_locator.dart to construct:

    SupabaseCurrentUserIdProvider(Supabase.instance.client)
    SupabaseTripRepository(Supabase.instance.client)
    SupabaseTripCoverStorage(Supabase.instance.client)

Run one authenticated create, edit, trash, and restore cycle against a non-production project. Revert the locator to mock adapters until the team approves production activation.

- [ ] **Step 8: Confirm verification leaves no uncommitted implementation changes**

    git status --short

Expected: no implementation files are modified. If a check required a code fix, return to the task that owns that file, repeat its focused tests, and commit the fix with that task instead of creating a generic verification commit.
