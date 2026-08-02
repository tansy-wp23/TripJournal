# Implementation Plan — Additional Enhancement Features

> Optional enhancements layered on the completed Wellness Journal + Trip
> Management work, added as documented "additional effort" beyond the core
> requirements. Read `CLAUDE.md` first.
>
> **Guiding rule — safety over ambition.** Every feature here must (a) reuse the
> existing data layer / repository interfaces, (b) NOT touch or risk the core
> journaling flow, and (c) be fully finished before it counts. A half-working
> enhancement scores worse than none — it draws attention to a defect. Build in
> priority order; stop wherever time runs out with each completed feature fully
> working.
>
> **For the marks:** each feature must also be written up in the report as a
> deliberate enhancement (what it does, why it adds value). The documentation is
> half the credit — code alone in the repo is easy to miss.

**Priority order (build top-down; each is independently shippable):**
1. Per-Trip Wellness Stats  (highest value-per-effort)
2. Search / Filter Journal Entries
3. Sort / Filter Trip List
4. Empty States & Onboarding Hints  (polish; do alongside)
5. Export Entry / Trip as PDF  (optional / last — only one with real new deps)

---

## 1. Per-Trip Wellness Stats View

Surfaces the health data already collected per entry as a trip-level summary.
Makes the health-tracking/SDG angle visible instead of buried inside entries.
Pure aggregation over existing data — no new tables, no new source.

### Data
- Add a pure helper `lib/features/trip/trip_wellness_stats.dart` producing a
  `TripWellnessStats` value object from a trip's journal entries + health logs:
  - `totalSteps`, `averageStepsPerDay`
  - `totalCaloriesEaten`, `totalCaloriesBurned` (kept SEPARATE — no net; matches
    the existing decision)
  - `moodBreakdown` (count per mood) and/or a representative `dominantMood`
  - `entriesLogged` / `tripDays` (e.g. "5 of 7 days journaled")
- Reads through the existing journal repository by `tripId`. No schema change.

### UI
- A stats section/screen reachable from the trip view (e.g. a "Trip Wellness"
  tab or card on the trip details header).
- Show the figures with simple visuals — a small bar/line for steps per day, a
  mood distribution (e.g. small segmented bar or emoji tally). If a chart lib is
  already in the project, reuse it; otherwise simple styled bars are fine and
  avoid a new dependency.
- Handle a trip with no entries → friendly "No data yet" state (see feature 4).

### Guardrails
- **No net-calorie figure.** Eaten and burned stay two separate numbers.
- Descriptive only — no targets, goals, or judgement copy (consistent with the
  wellbeing constraints already in the project).
- This is NOT the AI Trip Recap (teammate's module) — it's numeric aggregation.
  Keep them distinct in code and in the report.

---

## 2. Search / Filter Journal Entries

Lets the user find entries across a trip (or all trips) by text, mood, or date.
Reuses the data layer entirely — a filter over the entry list.

### Logic
- Add filtering to the journal controller (Riverpod): given a query, return
  entries where the text matches title/body, and/or mood matches, and/or the
  entry date falls in a selected range.
- Filtering happens over already-loaded entries (or as a repository query if you
  prefer) — no new persistence.

### UI
- A search bar on the journal timeline / entry list.
- Optional filter chips: by mood, and a date-range picker.
- Live-update the list as the query changes; show a "no matching entries" state
  when empty (feature 4).

### Guardrails
- Debounce the search input so it doesn't rebuild the list on every keystroke.
- Don't break the default (unfiltered) view — an empty query shows everything.

---

## 3. Sort / Filter Trip List

Small, safe organisation feature for the trip list on the home screen.

### Logic
- Add sort options to the trip controller: by start date (newest/oldest), by
  title (A–Z), and a filter for Upcoming / Active / Past (derived from each
  trip's date range vs today — logic already exists on the Trip model).

### UI
- A sort/filter control (dropdown or segmented control) above the trip list.
- Default ordering stays as it is now (e.g. active first, then upcoming, then
  past) when no option is chosen.

### Guardrails
- Sorting/filtering is view-only — never mutates or persists trip data.

---

## 4. Empty States & Onboarding Hints (polish)

Not a standalone feature — cross-cutting polish that makes the app read as
finished. Do this alongside 1–3; it directly improves how the additions above
present.

- **Empty states** with a friendly message + a clear action for: no trips yet,
  a trip with no entries, no search results, no health data on a stats view.
- **First-use hints** where helpful: e.g. a one-line prompt on the empty home
  screen ("Create your first trip to start journaling"), or a subtle hint that
  entries can be tapped to edit.
- Keep copy short, supportive, and consistent with the app's tone.

### Guardrails
- Hints must be dismissible / non-intrusive — never block the UI.
- No new storage for "has seen hint" unless trivial; in-memory for the session
  is fine.

---

## 5. Export Entry / Trip as PDF  (optional — do last)

Highest "wow" in a demo, but the ONLY feature here with a real new dependency
and real formatting effort. Treat as optional; only start it once 1–4 are done
and working.

### Approach
- Add a PDF package (e.g. the `pdf` + `printing` packages on pub.dev — let the
  tool resolve current versions; do not hardcode).
- Two possible exports (start with whichever is simpler — the single entry):
  - **Single journal entry** → a formatted page: title, date, location if
    present, body, mood, meals, steps/calories, photos (thumbnails), AI advice.
  - **Whole trip** → a multi-page document: trip header + each day's entries.
- Generate from existing data via the repository. Offer a share/save action.

### Guardrails
- **This is the riskiest item — timebox it.** If PDF generation fights you
  (layout, images, package setup), stop and ship without it. A working app
  without export beats a broken export.
- Photos in the PDF: load from the existing paths/URLs; handle a
  missing/unloadable image gracefully (skip it, don't crash the export).
- Test the export on a real device if photos are involved (same caveat as the
  health/photo features).

---

## Suggested Build Order for Claude Code

```
Phase 1 → trip_wellness_stats.dart (pure aggregation) + stats UI on trip view.
Phase 2 → journal search/filter in the controller + search bar & filter chips.
Phase 3 → trip list sort/filter control + controller sort logic.
Phase 4 → empty states + onboarding hints across the above screens.
Phase 5 → (optional) PDF export of a single entry, then whole trip.
Phase 6 → tests: stats aggregation (totals, averages, mood breakdown),
          search filter matching (text/mood/date), trip sort/filter ordering.
```

Run + commit after each phase. Every phase is independently shippable — a
completed Phase 1–2 alone is solid additional effort. Do not start a phase you
can't finish; a fully-working subset beats a broken full set.

---

## Report Write-Up (needed to earn the marks)

For each feature actually built, add a short entry to the report's enhancements
section covering: what it does, how it reuses existing data (shows good
architecture), and the value it adds. Emphasise that these go beyond the core
requirements. Note explicitly that the wellness stats are descriptive (not
targets) and separate from the AI Trip Recap, so scope stays clear.

---

*Keep this beside the other plans in the repo root.*
