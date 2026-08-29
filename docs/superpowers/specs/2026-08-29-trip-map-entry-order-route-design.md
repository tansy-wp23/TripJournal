# Trip Map Entry-Order Route Design

## Problem

The trip map currently creates only one connector between adjacent calendar
days: the last mapped Entry from one day to the first mapped Entry from the
next day. It does not connect multiple mapped Entries within the same day.

Backfilled Entries have a second ordering defect. `deriveEntryTimestamp`
assigns every Entry written for a past day the same noon timestamp. The map
then breaks ties with the Entry ID, which is deterministic but does not
represent creation order. Consequently, two Day 2 Entries created as `nice`
and then `UR` can be routed in the opposite order.

## Required Behaviour

The map route has a two-level order:

1. Sort Entries by trip day from earliest to latest.
2. Within each day, sort Entries by their immutable original creation order.

The route connects every mapped Entry in that flattened order. For example:

`Day 1 A -> Day 1 B -> Day 2 nice -> Day 2 UR -> Day 3 A`

Entries and days without a Location are skipped without breaking the route.
If Day 2 has no mapped Entry, Day 1's final mapped Entry connects directly to
Day 3's first mapped Entry. Editing an Entry must never change its route order.

Day filters retain their cumulative behaviour. Selecting Day N displays the
ordered route from Day 1 through Day N; All displays the entire trip route.

## Immutable Creation Order

Add a nullable-then-backfilled `creation_order_at timestamptz` column to
`journal_entries`, and finish the migration by making it non-null with a
`now()` default.

- Existing rows are backfilled from `updated_at`, the closest creation-order
  evidence available for legacy data. This restores the correct order for
  newly created, unedited Entries such as `nice` and `UR`.
- Historical Entries that were edited before the migration cannot have their
  original creation instant reconstructed with certainty. Once backfilled,
  their chosen order becomes stable.
- New Entries set `creation_order_at` at initial creation.
- Entry updates never change `creation_order_at`.
- The database bundle-save function enforces this immutability rather than
  relying only on client behaviour.

`JournalEntry` exposes the creation-order value. JSON and mock persistence
remain backward compatible with older records that lack it by using the best
available legacy fallback. Supabase reads always return the migrated value.

## Route Model

Replace the day-boundary-specific connector representation with a general
route segment. Each segment records:

- source and destination Entry IDs;
- source and destination day numbers;
- source and destination coordinates and labels.

The segment ID is derived from both Entry IDs, so multiple same-day segments
cannot collide in Google Map polyline or arrow marker IDs.

To build the route:

1. Keep only Entries inside the inclusive Trip date range.
2. Derive each Entry's trip day.
3. Sort by day, then immutable creation order, then Entry ID as a final stable
   tie-breaker.
4. Apply the cumulative Day filter.
5. Keep mapped Entries and connect each consecutive pair.
6. Omit a zero-length segment when two consecutive Entries resolve to the
   same normalized location, then continue routing to the next different
   location.

Marker grouping and coordinate identity remain unchanged. Entries at the same
normalized coordinates can share a Marker, while different coordinates remain
distinct even when their broad Place IDs match.

## User Interface

The Google Map draws a polyline and direction arrow for every route segment.
The fallback view lists the same ordered segments using Entry/location labels;
it no longer describes every segment as only a day-to-day boundary.

The existing route disclaimer remains accurate: lines show journal order, not
roads or navigation.

## Deletion and Editing

After an Entry is edited, the route is rebuilt with the same immutable creation
order. A location change moves only that Entry's marker and its adjacent route
segments.

After an Entry is deleted, the preceding and following mapped Entries become
adjacent and receive a replacement segment. Markers and segments belonging to
other Entries or days remain present.

## Database Rollout

The migration and bundle-save changes are committed with the application code.
They are verified locally through mapper, repository, and SQL-shape tests before
the migration is applied to the real cloud Supabase project. No separate test
Trip or cloud test data is created. Manual acceptance uses the user's existing
coursework data only when the user chooses to exercise the flow.

## Verification

Automated tests use in-memory fixtures only and cover:

- day-first and creation-order-second sorting;
- `nice -> UR` ordering when both Entries share the same journal timestamp;
- stable ordering after an Entry edit;
- multiple route segments within one day;
- direct Day 1 to Day 3 routing when Day 2 has no mapped Entry;
- cumulative Day filters and All;
- repeated locations and zero-length segment suppression;
- deleting a middle Entry without removing unrelated markers;
- legacy JSON fallback and Supabase field mapping;
- bundle-save immutability and migration backfill shape.

Before manual acceptance, run Flutter static analysis, focused map and
persistence tests, and the complete Flutter test suite. Preserve the user's
uncommitted `web/index.html` change throughout.
