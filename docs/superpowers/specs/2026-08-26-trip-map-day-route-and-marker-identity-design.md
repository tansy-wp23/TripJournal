# Trip Map Day Route and Marker Identity Design

## Goal

Fix map-only marker corruption when different entry locations are treated as
one marker, and make each Day filter show the cumulative journey through that
day. The final mapped day must therefore show the same route and locations as
All.

## Confirmed Behaviour

- The underlying Entries and their saved locations remain correct. The defect
  is limited to map modelling/rendering.
- Different coordinates must remain distinct markers even if a location
  provider returns the same Place ID for both.
- Entries at the same real location should continue to share one marker and
  one multi-entry preview.
- All continues to show every in-range mapped entry and every valid connector
  between adjacent trip days.
- Day 1 shows Day 1 locations.
- Day N shows locations from Day 1 through Day N and connectors between each
  consecutive pair of included days.
- The final available mapped day has the same marker groups and connectors as
  All.
- Missing days are not bridged. A connector exists only when both adjacent
  days contain at least one mapped entry.
- The route remains journal order only, not road navigation.

## Root Cause and Identity Rule

The current marker group key trusts a non-empty Place ID without considering
coordinates. That lets two distinct coordinates collapse into one marker when
the provider supplies the same broad or reused Place ID. Google Maps then sees
one marker identity and displays only one position; removing one entry can make
the shared marker move or disappear even though the other Entry is intact.

Marker grouping will use both the normalized Place ID (when present) and the
six-decimal normalized coordinates. Two entries merge only when this composite
identity matches. Coordinate-only locations keep the existing six-decimal
grouping rule. Longitude normalization continues to treat positive and
negative 180 degrees as the same meridian.

Marker IDs exposed to Google Maps will continue to come from the group key, so
the corrected group identity also gives the native map stable, distinct marker
IDs.

## Cumulative Day Model

`buildTripMapModel` remains the single source of truth for platform maps and
the fallback list.

For `selectedDay == null`, visible entries remain all mapped entries inside the
trip date range. For a selected Day N, visible entries become all mapped
entries whose day number is between 1 and N inclusive. The special
previous-day context marker is removed because earlier days are now ordinary
visible route history.

Connectors use the same selected range. Day N considers source days 1 through
N - 1; each source day connects its chronologically last mapped entry to the
next day's chronologically first mapped entry. All considers every available
day, still refusing to bridge gaps.

`previousDayHasNoMappedEntry` and its UI message are removed because cumulative
history makes that one-day-only warning misleading. A missing adjacent day is
represented simply by the absence of a connector.

## Ordering

Multiple backfilled entries on one past day can share the same noon timestamp.
The existing deterministic ID tie-break remains for now because changing the
persisted ordering model is outside this bug fix. Tests will use explicit
times where first/last-stop semantics matter.

## Testing

Model regression tests will prove:

- two different coordinates with the same Place ID remain separate groups;
- two entries with the same Place ID and normalized coordinates still merge;
- Day 2 contains Day 1 and Day 2 markers and only the Day 1 to Day 2 connector;
- Day 3 contains all markers and both adjacent-day connectors, matching All;
- deleting the second Day 2 entry leaves the Day 3 marker and connector target
  intact;
- missing days are not bridged under cumulative filtering.

Surface tests will prove that corrected groups create distinct Google marker
IDs. Widget tests will update the expected filter behaviour and verify that no
obsolete previous-day warning is rendered.

After focused tests pass, run Flutter analysis and the full Flutter test suite.
No Supabase data migration or production-data mutation is required.

## Constraints

- Work stays on the existing `trip-module` branch.
- Preserve the user's uncommitted `web/index.html` modification.
- Do not expose API keys, Supabase sessions, or signing credentials.
- Emulator acceptance, if needed, uses only a Trip whose name contains
  `TEST`.
