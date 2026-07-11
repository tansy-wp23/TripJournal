# Implementation Plan — Homepage & Trip Timeline (Option A)

> Companion to `IMPLEMENTATION_PLAN.md` (which covers the Wellness Journal
> module). Read `CLAUDE.md` first for project context.
>
> **Purpose:** turn the app from "a flat list of journal entries" into "a trip
> you move through," WITHOUT adding itinerary/route planning. The organizing
> principle is: **trip-as-timeline + a daily nudge to write.** All richness
> comes from organizing data we already collect, not from new modules.
>
> **Scope guard — do NOT build any of these:** route/path selection,
> accommodation-per-night, map view, itinerary planning, "where you'll stay"
> logic. Those contradict the journaling/health pivot. If a task seems to
> require them, stop and flag it.

---

## Settled Decisions (agreed with team — do NOT re-decide)

1. **Trip model ownership:** Sang You defines the `Trip` model and the
   `TripRepository` interface as the single source of truth. Nicholas's trip
   management / admin screens build on top of these. Do not declare a second
   `Trip` class elsewhere.
2. **Entries per day:** **multiple entries per day are allowed.** A trip day
   is not a single slot — each day in the timeline shows a list of that day's
   entries (0, 1, or many). See Phase 5 for how the day group renders.
3. **Trip delete cascade:** on delete, prompt the user
   ("Delete this trip and its N journal entries?") and cascade-delete the
   trip's entries on confirm.
4. **Future days:** future *journal entries* are **not allowed** — a day's
   entries only become writable once that day has arrived (today or past).
   INSTEAD, provide a **trip-level Notes / Reminders field** (attached to the
   Trip, NOT to individual future days) where the user can jot things to
   remember or prepare for the trip (packing, booking refs, addresses). This
   is journaling scaffolding, not itinerary planning — keep it trip-scoped, do
   NOT attach reminder notes to specific future days on the timeline.
5. **State management:** **Riverpod** (matches the existing Wellness Journal
   module).

---

## 0. Preconditions & Ground Rules

- This builds on the completed Wellness Journal module (models, mock
  repository, controller, screens, mock AI advice — all done).
- **Mock-first still applies.** No Supabase, no real AI, no real auth wiring
  here. Use the existing `MockJournalRepository`. A `Trip` is owned by the
  Trip Management module (teammate) and is **not yet built** — so this plan
  includes a *mock Trip layer* to develop against, mirroring how the journal
  was built. When the teammate's real Trip module lands, it swaps in behind
  the same interface.
- UI depends on interfaces, never concrete data sources (same rule as before).
- Keep each phase a runnable checkpoint. Run the app + commit between phases.
- Auth and Admin are separate teammate modules and are out of scope here;
  assume a logged-in user with a `userId` is available from a mock/session
  provider.

---

## 1. Trip Model & Mock Repository (foundation)

The journal already references `tripId`. Now give `Trip` a real shape so the
homepage and timeline have something to render. This is a **mock stand-in**
for the teammate's Trip Management module — same interface pattern.

### `Trip` model — `lib/models/trip.dart`
| Field | Type | Notes |
|---|---|---|
| `id` | String | UUID |
| `userId` | String | owner |
| `title` | String | e.g. "Penang Trip" |
| `coverPhotoPath` | String? | local path for now |
| `startDate` | DateTime | date only (normalise to midnight) |
| `endDate` | DateTime | date only; must be >= startDate |
| `notes` | String? | trip-level Notes / Reminders (decision #4) — things to prepare/remember for the trip; NOT per-day, NOT itinerary |
| `createdAt` | DateTime | |
| `updatedAt` | DateTime | |

Add computed helpers on the model (not stored):
- `int get durationDays` → `endDate.difference(startDate).inDays + 1`
- `bool isActiveOn(DateTime date)` → true if `date` is within [start, end]
- `List<DateTime> get dayList` → every date from start to end inclusive

Include `fromJson`/`toJson`/`copyWith`.

### `TripRepository` interface — `lib/data/trip_repository.dart`
```dart
abstract class TripRepository {
  Future<List<Trip>> getTrips(String userId);
  Future<Trip?> getTrip(String id);
  Future<void> addTrip(Trip trip);
  Future<void> updateTrip(Trip trip);
  Future<void> deleteTrip(String id);
}
```

### `MockTripRepository` — `lib/data/mock_trip_repository.dart`
- In-memory list seeded with 2–3 sample trips: one **past**, one **active**
  (today falls within its date range — hardcode dates relative to
  `DateTime.now()` so it's always "active" during a demo), one **upcoming**.
- Seed the active trip with 2–3 existing mock journal entries so the timeline
  shows a mix of filled and empty days.
- Leave a `// TODO: SupabaseTripRepository` stub implementing the same
  interface.

**Deliverable:** models + interface + mock repo + stub, wired through the
existing provider/locator so there's one swap point later.

---

## 2. Trip Controller

`lib/features/trip/controller/trip_controller.dart` (match the team's chosen
state management — Provider/Riverpod, per `CLAUDE.md`).

Exposes:
- `trips` (list for current user)
- `activeTrip` — the trip whose date range contains today, or null
- `loading` / `error`
- `loadTrips(userId)`, `createTrip(...)`, `editTrip(...)`, `deleteTrip(id)`

Talks only to `TripRepository`. For per-trip journal data, it coordinates with
the existing `JournalController` / `JournalRepository` by `tripId`.

---

## 3. Trip-Level Wellness Summary (cheap, high-value)

This is aggregation over data we ALREADY collect per entry — no new tracking.

Create a small helper/service `lib/features/trip/trip_summary_stats.dart`:
- Input: a `tripId` (pull that trip's journal entries via the journal repo).
- Output a `TripStats` value object:
  - `totalSteps` (sum of entry health-log steps)
  - `totalCalories` (sum)
  - `averageMood` (map moods to a scale, average, map back to a
    representative mood/emoji — keep the mapping in one place)
  - `entriesLogged` / `totalDays` (e.g. "3 of 5 days logged")
- Pure function, unit-testable, no UI.

**Note:** this is NOT the AI Trip Recap (that's the teammate's Module 2). This
is simple numeric aggregation for the dashboard. Keep them distinct.

---

## 4. Homepage / Dashboard

`lib/features/home/home_screen.dart` — the screen shown after login. Structure
top to bottom:

1. **Top bar** — app name/logo left; profile avatar + settings + logout in the
   top-right corner (menu or icons). (Auth/session is a teammate module — read
   the current user from the existing mock/session provider; don't build auth.)

2. **Active trip card** (only shown if `activeTrip != null`):
   - Large card with cover photo, title, and **"Day X of Y"** (compute from
     `activeTrip` + today's date).
   - A contextual nudge line driven by one conditional:
     - If today's entry is missing → *"You haven't written today's entry yet"*
       + a primary "Write today's entry" button that deep-links into the
       create-entry screen for today's date within this trip.
     - If today's entry exists → show a short confirmation + today's quick
       stats (steps · mood).
   - This nudge is the single most important element for making the app feel
     alive. Prioritise it.

3. **Wellness strip** — a horizontal row of the active trip's `TripStats`
   (steps, avg mood, meals/calories, "3 of 5 days logged"). Glanceable only;
   tapping it can open the trip view.

4. **"Your Trips"** — grid/list of all trips as cover-photo cards, each showing
   title, date range, and entry count. Sections or ordering: Active → Upcoming
   → Past. Tapping a card opens the Trip View (Phase 5).

5. **Create Trip** — a clear FAB or button → opens Create/Edit Trip form
   (Phase 6).

**Empty states matter** (examiners and real users hit these first):
- No trips at all → friendly empty state + prominent "Create your first trip."
- Trip exists but no entries yet → timeline shows all days as empty slots.

---

## 5. Trip View — Day-by-Day Timeline (the "journey" screen)

`lib/features/trip/trip_view_screen.dart`. This is where Option A earns its
richness. The trip's day list is generated from `startDate`→`endDate`
(`trip.dayList`), so structure is free — no planning input required.

Render a **vertical timeline**, one row (a *day group*) per day:
- Day label: `Day N — <weekday> <date>`.
- **Multiple entries per day are allowed (decision #2).** Each day group holds
  a list of that day's entries:
  - 0 entries → empty marker.
  - 1+ entries → show each as a compact item (one-line snippet + quick stats:
    steps · mood emoji). Tap an item → Entry Detail (existing screen).
- If the day is **today or past**: show an **"Add entry"** action on the day
  group → create-entry screen pre-filled with that date + this `tripId`. This
  action is available even when the day already has entries (since multiple are
  allowed).
- If the day is in the **future**: entries are **NOT writable (decision #4)** —
  show a muted "upcoming" marker with no "Add entry" action. Do NOT attach
  reminders to future days; trip-level reminders live in the Trip's `notes`
  field, surfaced in the trip header (see below), not on the timeline days.
- Mark **today** distinctly (highlight/ring) so the user's eye lands on it.

Header of the screen: trip title, date range, cover photo, and the same
`TripStats` summary. Include edit/delete trip actions here.

**Entry↔Day mapping rule:** an entry belongs to a day via its `createdAt`/entry
date falling on that calendar day within the trip. Per decision #2, a day may
hold **multiple entries** — group all entries whose date falls on that day
under the same day group, ordered by time. No one-per-day validation.

**Trip header:** show trip title, date range, cover photo, the `TripStats`
summary, edit/delete trip actions, AND the trip-level **Notes / Reminders**
(`trip.notes`) if present — this is where "things to prepare/remember" surfaces
(decision #4), at the trip level, not on individual days.

---

## 6. Create / Edit Trip Form

`lib/features/trip/trip_form_screen.dart`:
- Fields: title (required), start date, end date (date pickers), optional cover
  photo (local picker), and an optional **Notes / Reminders** multiline field
  (`trip.notes`, decision #4 — things to prepare/remember for the trip).
- Validation: end date >= start date; title non-empty. Show inline errors.
- Save → `TripController.createTrip` / `editTrip` → back to homepage or the new
  trip's view.
- Delete (edit mode): confirmation dialog. **On delete, decide the cascade
  rule** (this is a genuine design decision worth writing up in the proposal):
  - Recommended: prompt the user — "Delete this trip and its N journal
    entries?" — and cascade-delete on confirm. Document the choice.

---

## 7. Wiring & Navigation

- After (mock) login → Home screen.
- Home → Trip View (tap trip) → Entry Detail (tap day) → Create/Edit Entry.
- Home → Create Trip.
- Ensure the "Write today's entry" nudge deep-links correctly to the
  create-entry screen with `tripId` + today's date pre-filled.
- Keep the existing journal screens intact; they're now reached *through* a
  trip instead of from a flat list.

---

## 8. Tests

`test/`:
- `Trip` model: `durationDays`, `isActiveOn`, `dayList` edge cases
  (single-day trip, start==end, multi-month).
- `MockTripRepository` CRUD.
- `TripStats` aggregation: totals, average mood mapping, "X of Y days logged".
- Timeline day-generation logic (correct number of day slots; today correctly
  identified).
- Day grouping with **multiple entries** on the same day (all entries for a
  date land in one day group, ordered by time).
- Future days expose **no "Add entry"** action; today/past days do.
- Widget test: active-trip nudge shows "write today" when today's entry is
  missing, and the confirmation state when it exists.

---

## Suggested Build Order for Claude Code

```
Phase 1 → lib/models/trip.dart + lib/data/ (TripRepository, MockTripRepository, stub)
Phase 2 → lib/features/trip/controller/trip_controller.dart
Phase 3 → lib/features/trip/trip_summary_stats.dart (TripStats)
Phase 4 → lib/features/home/home_screen.dart (dashboard + active-trip nudge)
Phase 5 → lib/features/trip/trip_view_screen.dart (day-by-day timeline)
Phase 6 → lib/features/trip/trip_form_screen.dart (create/edit/delete trip)
Phase 7 → navigation wiring + deep-link "write today's entry"
Phase 8 → test/
```

Complete and run each phase before the next. Everything uses mocks; the real
Trip Management module (teammate) and Supabase swap in later behind the
existing interfaces.

---

## Design Decisions — SETTLED

All five open decisions have been agreed with the team and are recorded in the
**"Settled Decisions"** block near the top of this file. Summary:

1. Trip model/interface owned by Sang You (single source of truth). ✅
2. Multiple entries per day allowed. ✅
3. Trip delete → prompt + cascade. ✅
4. No future entries; trip-level Notes/Reminders field instead. ✅
5. Riverpod. ✅

Still worth a quick sync with Nicholas: since you own the `Trip` model and
he builds trip-management/admin on top of it, share the finalised model +
`TripRepository` interface with him before he starts so you don't diverge.

---

*Update this file as decisions firm up. Keep it beside `CLAUDE.md` and
`IMPLEMENTATION_PLAN.md` in the repo root.*
