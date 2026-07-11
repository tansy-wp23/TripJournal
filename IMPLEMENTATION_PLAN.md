# Implementation Plan — Journal + Health Tracking Module

> Scope: **Module 1 (Journal + Health Tracking, AI-aided)** — Sang You's
> assigned module for TripJournal (BMSE3004, TARUMT).
> Read `CLAUDE.md` first for full project context. This document is the
> build spec for Claude Code to work through phase by phase.

---

## 0. Ground Rules (read before writing any code)

1. **Mock-first.** Build UI + logic against a `JournalRepository` *interface*
   backed by an in-memory mock. Do NOT wire Supabase or any external API in
   phases 1–5. Supabase and the real AI call come later (phase 6+), as a
   drop-in implementation of the same interface.
2. **UI depends on interfaces, never concrete data sources.** Screens/widgets
   import `JournalRepository`, never `MockJournalRepository` or
   `SupabaseJournalRepository` directly.
3. **Lock the data model before UI** (Phase 1). Field shapes are the one thing
   that causes rework if changed late.
4. **This module owns entries + health logs only.** A `Trip` is owned by the
   Trip Management module (teammate). For now, mock a `tripId` — do not build
   trip CRUD here.
5. Keep commits small and per-phase. Each phase below should be a working,
   runnable checkpoint.

---

## 1. Data Model (do this first)

Define plain Dart model classes with `fromJson` / `toJson` (JSON now feeds the
mock; later feeds Supabase rows unchanged).

### `JournalEntry`
| Field | Type | Notes |
|---|---|---|
| `id` | String | UUID; mock can generate locally |
| `tripId` | String | FK to Trip (mocked for now) |
| `title` | String | short entry title |
| `body` | String | main journal text |
| `mood` | Mood (enum) | e.g. happy, tired, excited, stressed, neutral |
| `photoPaths` | List\<String> | local file paths for now; storage URLs later |
| `location` | GeoTag? | nullable — auto-filled by Module 2 later |
| `createdAt` | DateTime | entry timestamp |
| `updatedAt` | DateTime | last edit |
| `healthLog` | HealthLog? | one-to-one, nullable |

### `HealthLog`
| Field | Type | Notes |
|---|---|---|
| `id` | String | UUID |
| `entryId` | String | FK back to JournalEntry |
| `steps` | int | step count for the day |
| `calories` | int | total calories logged |
| `meals` | List\<Meal> | meals eaten |
| `aiAdvice` | String? | AI food-intake advice (stubbed for now) |

### `Meal`
| Field | Type | Notes |
|---|---|---|
| `name` | String | e.g. "Chicken rice" |
| `calories` | int | per-meal calories |
| `mealType` | MealType (enum) | breakfast / lunch / dinner / snack |

### `GeoTag` (placeholder — Module 2 fills this later)
| Field | Type |
|---|---|
| `latitude` | double |
| `longitude` | double |
| `placeName` | String? |

**Deliverable:** `lib/models/` with the four classes + enums, each with
`fromJson`/`toJson` and an `copyWith`.

---

## 2. Repository Layer (the swap point)

**Deliverable:** `lib/data/`

- `journal_repository.dart` — abstract interface:
  ```dart
  abstract class JournalRepository {
    Future<List<JournalEntry>> getEntries(String tripId);
    Future<JournalEntry?> getEntry(String id);
    Future<void> addEntry(JournalEntry entry);
    Future<void> updateEntry(JournalEntry entry);
    Future<void> deleteEntry(String id);
  }
  ```
- `mock_journal_repository.dart` — in-memory `List<JournalEntry>`,
  seeded with 3–4 sample entries so the UI has data on first run.
- Leave a `// TODO(phase6): SupabaseJournalRepository` stub file with the
  class skeleton implementing the same interface (empty method bodies).

Wire the app to use `MockJournalRepository` via a single provider/locator so
there's exactly one place to change later.

---

## 3. State Management

Use whatever the team standardised on (confirm in `CLAUDE.md`; if unset,
default to **Provider** or **Riverpod** — pick one and note it).

**Deliverable:** a `JournalController` / notifier exposing:
- `entries` (list, filtered by current tripId)
- `loading` / `error` states
- `loadEntries(tripId)`, `create(entry)`, `edit(entry)`, `remove(id)`

Controller talks to `JournalRepository`, never to a concrete repo.

---

## 4. UI Screens

**Deliverable:** `lib/features/journal/`

1. **Journal List Screen** — entries for the current trip, newest first;
   each row shows title, mood icon, date, and a small health summary
   (e.g. "6,240 steps · 1,850 kcal"). Tap → detail. FAB → create.
2. **Entry Detail Screen** — full body, photos, mood, and the health log
   (steps, calories, meal list, AI advice text). Edit + delete actions.
3. **Create / Edit Entry Screen** — form for title, body, mood picker,
   photo add (local picker), and an embedded **Health Log sub-form**
   (steps, add/remove meals with name + calories + type). Calories can
   auto-sum from meals. Save → repository.
4. **Delete confirmation** — dialog before removing an entry.

UI/UX styling follows the Design Lead's specs; keep widgets modular so the
Health Log sub-form is reusable.

---

## 5. AI Food-Intake Advice (stubbed)

**Deliverable:** `lib/features/journal/ai/food_advice_service.dart`

- Interface `FoodAdviceService { Future<String> adviceFor(List<Meal> meals); }`
- `MockFoodAdviceService` returns a canned but plausible string based on
  simple rules (e.g. total calories > threshold → "Consider a lighter
  dinner…"). No network call.
- The controller calls this when a health log is saved and stores the result
  in `HealthLog.aiAdvice`.
- Leave a `// TODO(phase6)` note for the real OpenAI/Gemini implementation
  (same interface).

---

## 6. Later Phases (NOT now — after Journal module works end-to-end on mock)

- **6a. Supabase integration** — implement `SupabaseJournalRepository`
  against the same interface; create matching tables (`journal_entries`,
  `health_logs`, `meals`); switch the locator from mock → Supabase.
- **6b. Real AI service** — implement `OpenAiFoodAdviceService` /
  `GeminiFoodAdviceService`; wire API key via env, not hardcoded.
- **6c. Module integration** — connect real `tripId`s from the Trip
  Management module; let Module 2 populate `GeoTag` on entries.

---

## 7. Testing (Testing Lead + you)

- Unit tests for models (`toJson`/`fromJson` round-trip, `copyWith`).
- Unit tests for `MockJournalRepository` CRUD.
- Unit test for `MockFoodAdviceService` threshold logic.
- Widget test for create-entry form validation.

---

## Suggested Build Order for Claude Code

```
Phase 1  → lib/models/           (JournalEntry, HealthLog, Meal, GeoTag, enums)
Phase 2  → lib/data/             (interface + mock repo + Supabase stub)
Phase 3  → lib/features/journal/controller/
Phase 4  → lib/features/journal/screens/ + widgets/
Phase 5  → lib/features/journal/ai/  (mock advice service)
Phase 7  → test/                 (unit + widget tests)
```

Complete and verify each phase before starting the next. Phase 6 (Supabase +
real AI) is deferred until the mock build runs end-to-end.

---

# Assignment Specification (reference)

Extracted from `Project_Proposal_Guidelines_v202605.pdf` — the deliverable
this codebase supports. The **proposal document** and the **slide deck** are
separate deliverables (tracked in `CLAUDE.md`); this file is the **code**
build plan for the module.

**Chapter 1 — Introduction:** project description, targeted user, UN SDG +
justification (SDG 3), background study (≥5 APA 7.0 references), project
significance.
**Chapter 2 — Team structure & work plan:** member roles, work plan/activities
with durations.
**Chapter 3 — Project functionalities:** technology stack + justification,
key modules & functions with the responsible member per module.

Module ownership for the code:
- **Journal + Health Tracking (this plan)** → Tan Sang You
- Location/Date-Time + AI Trip Summary → (teammate)
- Authentication → (teammate)
- Admin → (teammate)
- Trip Management (CRUD) → (teammate)

---

*Update this plan as decisions firm up (state-management choice, confirmed
field names, folder conventions). Keep it beside `CLAUDE.md` in the repo root.*
