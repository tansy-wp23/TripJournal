# Trip Management MVP Design

**Date:** 2026-08-04

**Branch:** `TripManagement`

**Owner:** Nicholas Loo
**Status:** Approved for implementation planning

## 1. Purpose

Deliver a production-ready Trip Management MVP without rewriting the existing
Flutter UI or coupling the module to the unfinished Authentication module. The
MVP will add Supabase trip persistence, public cover-photo storage, a replaceable
current-user boundary, and a recoverable 30-day trash lifecycle.

All source code, tests, documentation, UI copy added by this work, and commit
messages must be written in English. Team communication may remain in Chinese.

## 2. Existing Foundations

The implementation must preserve and extend the existing architecture:

- `Trip` remains the single trip domain model.
- `TripRepository` remains the data-access contract used by controllers.
- `TripController`, `HomeScreen`, `TripFormScreen`, and `TripViewScreen` remain
  the primary trip workflow.
- Riverpod remains the only state-management solution.
- Repository locators remain the composition point for mock versus production
  implementations.
- Mock mode remains the default until the Authentication owner provides a real
  Supabase session.

The implementation must not modify the teammate-owned Authentication flow or
make `Supabase.instance.client.auth.currentUser` a direct dependency of trip UI
widgets.

## 3. Architecture

The module will use adapter-first incremental integration:

```text
Trip UI
  -> TripController / TripTrashController
  -> TripRepository
  -> MockTripRepository or SupabaseTripRepository

Current-user lookup
  -> CurrentUserIdProvider
  -> MockCurrentUserIdProvider or SupabaseCurrentUserIdProvider

Cover-photo operations
  -> TripCoverStorage
  -> MockTripCoverStorage or SupabaseTripCoverStorage
```

Mock implementations remain selected by default. Activating production mode
after Authentication integration requires changing only the composition in the
trip locator, not screens, models, or controllers.

## 4. Component Responsibilities

### 4.1 Current user

`CurrentUserIdProvider` exposes one operation:

```dart
abstract interface class CurrentUserIdProvider {
  String requireUserId();
}
```

- `MockCurrentUserIdProvider` returns
  `00000000-0000-0000-0000-000000000001`.
- `SupabaseCurrentUserIdProvider` reads the injected `SupabaseClient` session
  and throws a typed unauthenticated exception when no user exists.
- Existing mock seed data uses the same valid UUID.

### 4.2 Trip persistence

`SupabaseTripRepository` receives an injected `SupabaseClient` and implements
the existing CRUD contract plus trash operations. Database mapping is isolated
in a trip mapper and uses these exact columns:

```text
id, user_id, title, cover_photo_url, start_date, end_date,
notes, created_at, updated_at, deleted_at
```

`start_date` and `end_date` are serialized as `YYYY-MM-DD`. New trip IDs are
UUID v4 values generated on the client so navigation can use the ID immediately
after a successful create.

Normal queries always require `deleted_at IS NULL`. Trash queries require a
non-null `deleted_at`, order newest deletions first, and exclude already expired
items from restoration.

### 4.3 Cover storage

`SupabaseTripCoverStorage` uses a public bucket named `trip-covers`. Public read
access applies only to object retrieval; authenticated write policies restrict
insert, update, and delete operations to the user's own first-level folder.

Each upload uses a unique path:

```text
{userId}/{tripId}/cover-{uploadId}.{extension}
```

The database stores the resulting public URL. A new cover is uploaded before
the trip row is written. If the database write fails, the new object is removed.
After a successful update, the previous cover object is removed. A cleanup
failure after a successful database update is non-blocking and is reported for
retry without rolling back valid trip data.

`TripCoverPhoto` renders HTTP and HTTPS values with `Image.network`, existing
device paths with `Image.file`, and invalid or unavailable values with the
current placeholder.

## 5. Trip Save Flows

### 5.1 Create

```text
Validate title, notes, dates, and overlap
  -> Generate UUID v4
  -> Resolve current user ID
  -> Upload a selected local cover, if present
  -> Replace the local path with the public URL
  -> Insert the trip row
  -> Roll back the uploaded cover if insert fails
  -> Refresh the active trip list
  -> Open TripViewScreen
```

### 5.2 Edit

```text
Validate changed fields and overlap, excluding the current trip
  -> Upload a newly selected local cover, if present
  -> Update the trip row
  -> Remove the new upload if update fails
  -> Remove the previous cover after update succeeds
  -> Refresh the active trip list
```

Removing a cover updates `cover_photo_url` to null. The old object is deleted
only after the database update succeeds.

## 6. Thirty-Day Trash

### 6.1 Data model and security

The `trips` table and `Trip` model gain nullable `deleted_at` / `deletedAt`.
Deletion becomes an update that sets `deleted_at` to the database timestamp.
The client-side hard-delete policy for trips is removed so an authenticated app
client cannot bypass the recovery window. The service role used by the purge
function remains able to perform permanent deletion.

Moving a trip to trash keeps all related journal entries, meals, health logs,
trip covers, and journal photos unchanged.

### 6.2 User experience

The Home Screen profile menu gains `Recently Deleted`. It opens a dedicated
`TripTrashScreen` managed by `TripTrashController`.

Each trash item displays:

- Trip title and cover.
- Deletion date.
- Exact expiration date (`deletedAt + 30 days`).
- Whole days remaining.
- A Restore action.

The app does not offer manual permanent deletion. A trip becomes ineligible for
restoration at exactly `deletedAt + 30 days`, even if the scheduled purge has
not processed it yet.

### 6.3 Restore

Restore first validates the deleted trip against active trips owned by the same
user.

- With no overlap, one repository update clears `deleted_at` and returns the
  trip to Home.
- With an overlap, restore is blocked and the conflicting trip is named. The
  existing form opens in restore mode with the deleted trip prefilled.
- Restore mode requires the user to select a valid non-overlapping date range.
  Saving updates the editable trip fields and clears `deleted_at` in the same
  database update.

Expired trips cannot enter restore mode.

### 6.4 Permanent purge

A Supabase Cron HTTP job runs daily at `02:15 UTC` and invokes the
`purge-deleted-trips` Edge Function. The function authenticates the request with
an environment secret distinct from the Supabase service-role key, then uses
the service role internally.

For every trip with `deleted_at <= now() - interval '30 days'`, the function:

1. Reads the trip cover URL and journal photo URLs.
2. Deletes the trip cover from `trip-covers`.
3. Deletes referenced journal photos from the team's `journal-photos` bucket
   when URLs are present.
4. Deletes the trip row.
5. Relies on existing foreign-key cascades to delete journal entries, health
   logs, and meals.

If any required Storage deletion fails, the trip row is retained and the
failure is logged. The next daily run retries it. A missing Storage object is
treated as already deleted and does not block the database purge.

The Edge Function processes expired trips independently so one failure does not
prevent other eligible trips from being purged.

## 7. Database and Storage Changes

One migration will:

- Add `trips.deleted_at timestamptz null`.
- Add an index supporting user and deletion-state queries.
- Remove the authenticated client hard-delete policy for trips.
- Create the public `trip-covers` bucket if it does not exist.
- Add authenticated insert, select-metadata, update, and delete policies scoped
  to `trip-covers/{auth.uid()}/...`.

The Cron job is configured after the Edge Function is deployed. Its request
contains `x-cron-secret`, which must match the function's `PURGE_CRON_SECRET`
environment variable. Neither that secret nor the service-role key is stored in
Git or in the Flutter `.env` file.

## 8. Error Handling

- Missing authenticated user: return `Please sign in to manage trips.`
- Trip query failure: retain current screen data and expose a retryable error.
- Cover upload failure: do not write the trip row.
- Database failure after upload: remove the newly uploaded object.
- Old-cover cleanup failure after a valid save: keep the saved trip and expose a
  non-blocking warning.
- Invalid network or local image: render the placeholder.
- Invalid title, notes, date order, or overlap: reuse existing validation copy.
- Restore conflict: block restoration and route to restore-mode editing.
- Expired restore request: refresh Trash and explain that the recovery period
  has ended.
- Purge Storage failure: keep the database row and retry on the next Cron run.

## 9. Testing Strategy

Implementation follows test-driven development. Automated coverage includes:

- UUID generation and valid mock user UUID usage.
- Trip row mapping in both directions.
- Date-only serialization and nullable `deleted_at` mapping.
- Mock and Supabase current-user providers.
- Active versus deleted repository queries.
- Create, edit, move-to-trash, restore, and restore-with-new-dates behavior.
- Cover object naming, public URL handling, upload rollback, and old-cover
  cleanup.
- Local, network, missing, and broken cover rendering.
- Trash countdown and exact 30-day expiration boundary.
- Restore overlap handling.
- Edge Function authorization, successful purge, missing-object handling,
  partial Storage failure, and independent per-trip retries.
- Regression coverage for existing Trip, Home, and Journal flows.

The final local verification commands are:

```powershell
flutter analyze
flutter test
```

Server-side verification includes applying the migration to a non-production
Supabase project, deploying the Edge Function, invoking it with authorized and
unauthorized requests, and confirming the Cron job history after a scheduled
run.

## 10. Definition of Done

- Existing Trip UI remains operational in default mock mode.
- Supabase trip CRUD and public cover storage are implemented behind interfaces.
- Mock mode remains the selected locator configuration.
- Authentication-owned files are not modified.
- A single composition change activates the real user, repository, and storage
  adapters after Authentication integration.
- Trip deletion moves data to Recently Deleted for exactly 30 days.
- Valid trips can be restored; date conflicts require correction before restore.
- Expired trips and their database and Storage data are purged by the scheduled
  server-side workflow.
- All new code and UI copy are English.
- Static analysis and the complete automated test suite pass.
- Real-session end-to-end verification is documented as the final activation
  gate owned jointly with the Authentication module.

## 11. Out of Scope

- Rewriting the existing Trip screens or introducing a second Trip model.
- Implementing or modifying the teammate-owned Authentication UI and session
  flow.
- Making Supabase mode the default before real Authentication is integrated.
- Manual permanent deletion during the 30-day recovery window.
- A general-purpose trash system for entities other than trips.
- Redesigning the teammate-owned Journal UI or repository.
