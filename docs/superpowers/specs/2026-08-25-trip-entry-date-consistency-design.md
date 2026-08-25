# Trip and Entry Date Consistency Design

## Problem

An eight-day trip from August 11 through August 18 can currently show
`Day 15` on its map when an attached journal entry is dated August 25. The
Entries timeline only creates Day 1 through Day 8, while the Map derives day
chips from every mapped entry without checking the trip end date. Editing trip
dates can also leave existing entries outside the new range, and Home does not
always refresh entry counts after returning from Trip View.

## Chosen behavior

Trip dates are the authoritative boundary for every trip-scoped view.

- Entries before the trip start or after the trip end must not become Map day
  chips, markers, connectors, statistics, photos, summaries, wellness totals,
  or PDF content for that trip.
- Creating an entry continues to require a date inside the trip range.
- Editing trip dates is rejected when the proposed range would exclude any
  existing entry. The user receives an actionable message and no trip data is
  changed.
- Returning from Trip View reloads Home trip counts so the list cannot retain
  a stale count.
- Existing invalid data is not silently rewritten. The specifically approved
  `First day went to KLCC` entry is corrected from August 25 to August 11 while
  preserving its time of day, content, health data, photos, and location.

## Alternatives considered

1. **Recommended and selected: enforce the range and block unsafe trip edits.**
   This preserves user intent, prevents hidden data, and keeps all modules
   consistent.
2. **Hide invalid entries only on Map.** This removes `Day 15` visually but
   leaves statistics, PDF, summary, and Entries inconsistent, so it is
   rejected.
3. **Automatically move entries or extend the trip.** This can silently change
   journal history and is rejected.

## Implementation boundaries

A pure date-range filter will produce the entries visible to Trip View and all
of its downstream consumers. The Map model will also accept the trip end date
and enforce the range itself as defense in depth. Trip edit validation will
query the trip's existing entries before saving a shortened or shifted range.
Home will reload after any normal return from Trip View, not only after moving
a trip to trash.

The correction of the approved Supabase row is a one-time data repair, scoped
by the current authenticated user, trip, entry title, and current August 25
date. The update must abort unless exactly one row matches.

## Error handling

- A rejected trip date edit explains that journal entries fall outside the new
  range and asks the user to keep dates that include them.
- A data-repair precondition mismatch stops without changing any row.
- Repository failures retain the existing trip and entries and surface the
  existing error treatment.

## Tests and verification

- Map model excludes entries before Day 1 and after the final trip day.
- Trip View passes only in-range entries to map, statistics, photos, summary,
  wellness, and PDF consumers.
- Trip edits that exclude an existing entry fail without a repository update.
- Returning from Trip View refreshes Home entry counts.
- Existing valid Day 1/Day 2 markers and connectors remain unchanged.
- The repaired entry reloads as Day 1 after a full App restart.
- Run targeted tests, `flutter analyze`, the full Flutter test suite, rebuild
  the Supabase + Android Maps Debug APK, and verify the eight-day trip exposes
  no day beyond Day 8.

