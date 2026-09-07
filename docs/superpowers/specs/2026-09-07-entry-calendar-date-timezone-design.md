# Entry Calendar Date Timezone Fix

## Problem

TripJournal currently derives an entry's trip day from `JournalEntry.createdAt` in several places. Supabase returns that timestamp in UTC. The Entries timeline reads its year, month, and day directly, while the Map converts it to the device's local timezone first. Around the UTC date boundary, the same entry can therefore appear under different trip days.

For example, `2026-09-06 23:02 UTC` is `2026-09-07 07:02` in Malaysia. The current Entries timeline assigns it to September 6, while the Map assigns it to September 7.

Supabase already stores `journal_entries.entry_date` as a date-only value. The app writes this field but currently ignores it when reading an entry.

## Confirmed Behaviour

- The trip day is a calendar date selected for the journal entry, not a timezone-dependent instant.
- `entry_date` is the authoritative value for that calendar date.
- `created_at`, `updated_at`, and `creation_order_at` remain timestamps and must not be used to decide the trip day.
- For a trip starting September 6, an entry with `entry_date = 2026-09-07` is Day 2 regardless of the device timezone or the UTC representation of its timestamps.
- Entries, Map, date filtering, trip-range validation, trip statistics, wellness statistics, photos, PDF output, and visible entry dates must agree on the same calendar day.

## Model Design

Add an explicit date-only field to `JournalEntry` for the entry's logical calendar date. It will be normalized to a timezone-neutral `DateTime(year, month, day)` value within the app.

Supabase mapping will read it from `entry_date`. Local/mock JSON will persist it explicitly. Legacy JSON or test data without the new field will fall back to the local calendar date represented by `createdAt`, preserving compatibility.

`createdAt` remains available for timestamp-related compatibility. `creationOrderAt` remains the immutable ordering key for entries within the same trip day.

## Data Flow

1. Creating an entry derives its selected calendar date from the chosen trip day and stores it on the model.
2. Saving to Supabase writes that value directly to `entry_date` instead of deriving it from a timestamp.
3. Reading from Supabase parses `entry_date` without timezone conversion.
4. All trip-day calculations consume the explicit calendar date.
5. Entries within a day continue to sort by `creationOrderAt`, followed by entry ID for deterministic ties.

## Compatibility and Error Handling

- Existing Supabase rows are supported because `entry_date` already exists and is populated.
- Existing local/mock JSON without an explicit calendar-date field falls back to `createdAt`.
- A missing or malformed Supabase `entry_date` also falls back to the local calendar date of `createdAt`, so one legacy row cannot prevent the trip from loading.
- No database migration is required for this fix.
- No real cloud data needs to be modified.

## Test Design

Add regression coverage for the UTC+8 boundary demonstrated by the reported bug:

- A Supabase row whose UTC timestamp is September 6 but whose `entry_date` is September 7 maps to a September 7 calendar date.
- Entries and Map both assign that row to Day 2 for a trip starting September 6.
- Calendar-day filtering, validation, statistics, wellness summaries, photo grouping, and displayed/exported dates use the same field.
- Legacy model/JSON data without an explicit entry date retains its previous local-calendar behaviour.
- Existing within-day creation-order tests continue to pass.

## Scope

This change fixes calendar-date interpretation only. It does not change route drawing, location data, immutable creation ordering, trip dates, or any Supabase records.
