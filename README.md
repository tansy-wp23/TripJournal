# TripJournal

A Flutter mobile app that combines **travel journaling** with **health tracking**.
Users record daily journal entries during a trip — text, photos, mood — while
logging steps, meals, and calories alongside them, with AI-assisted daily
wellbeing advice.

Built for **BMSE3004 — Collaborative Development** (TAR UMT).

---

## Quick Start

```bash
# 1. Clone and enter the project
git clone https://github.com/tansy-wp23/TripJournal.git
cd TripJournal

# 2. Install dependencies
flutter pub get

# 3. Set up your environment file  (see "Environment Setup" below — REQUIRED)
copy .env.example .env      # Windows
# cp .env.example .env      # macOS/Linux

# 4. Run
flutter run
```

> ⚠️ **The app will not start without a valid `.env` file.** See below.

---

## Environment Setup (required)

The Supabase credentials are **not** in this repo (they're gitignored — never
commit them).

1. Copy `.env.example` → `.env`
2. **Ask Sang You for the two values** (sent privately, not via the repo)
3. Paste them in:
   ```
   SUPABASE_URL=...
   SUPABASE_ANON_KEY=...
   ```

Without this, `dotenv.load()` fails on startup and the app crashes immediately.
If you get a startup error, check this first.

---

## Optional: Real AI (Gemini)

The AI daily advice and food-photo detection features work out of the box with
**no key at all** — they fall back to built-in mock implementations, fully
offline. Only add a key if you want the real model responses.

1. Get a free key from [Google AI Studio](https://aistudio.google.com/).
2. Add it to your `.env`:
   ```
   GEMINI_API_KEY=your-key-here
   ```
3. Restart the app. `daily_advice_locator.dart` and `food_detection_locator.dart`
   pick it up automatically at startup — nothing else to wire up.

Leave it blank (or omit it) to keep using `MockDailyAdviceService` /
`MockFoodDetectionService`. See `IMPLEMENTATION_PLAN_REAL_AI.md` for the full
design (why it's dotenv-based, the safety/tone constraints sent to the model,
etc.).

The model name is centralized in `lib/features/journal/ai/gemini_model.dart`
(`geminiModel`, currently `gemini-3.6-flash`) — both
`GeminiDailyAdviceService` and `GeminiFoodDetectionService` read it from
there, so there's one place to change if it ever needs to move.

> ⚠️ A valid key isn't a guarantee of working calls — free-tier quota is
> granted **per model name, not per key**, and Google periodically retires
> model versions. Both failure modes have already happened here:
>
> - `gemini-2.0-flash` (the original choice) returned 429
>   `RESOURCE_EXHAUSTED` (`limit: 0`) once its free tier was wound down,
>   even with billing enabled on the project.
> - `gemini-flash-latest` (the alias that replaced it) exhausted its
>   **daily request cap** in ordinary use. Probing found the alias returning
>   429 while `gemini-3.7-flash` — the model that alias resolves to —
>   answered normally, so an alias has its own quota bucket separate from
>   the concrete version behind it. Pinning a version is the fix.
>
> Note that `ListModels` still lists models you cannot call:
> `gemini-2.5-flash` appears in it but returns 404 *"no longer available to
> new users"*. Always confirm a candidate with a real request before pinning
> it. If it fails again, check
> [the models list](https://ai.google.dev/gemini-api/docs/models) and swap
> the constant. Failures are graceful either way: daily advice falls back to
> a "tap to retry" affordance, food detection falls back to manual entry.

> ⚠️ **Real device note:** on some Android OEM skins (confirmed on an Infinix
> running XOS), the modern Android Photo Picker silently reports
> `RESULT_CANCELED` for every pick, so `ImagePicker().pickImage()` returns
> `null` before food detection is ever reached — no Gemini call, no error,
> just silent failure. Fixed via `android/app/src/main/AndroidManifest.xml`
> (`io.flutter.plugins.imagepicker.useAndroidPhotoPicker` set to `false`),
> which forces the classic `ACTION_GET_CONTENT` picker instead. If photo
> pick silently does nothing on your test device, this is the first thing to
> check.

---

## Read This Before You Start Coding

The project has a documented architecture and a set of design decisions that are
already settled. **Please skim these before writing code** — they'll save you
from building something that has to be redone:

| File | What it covers |
|---|---|
| `CLAUDE.md` | Project context, module list, settled decisions, tech stack |
| `IMPLEMENTATION_PLAN.md` | Wellness Journal module (models, repos, controllers, UI) |
| `IMPLEMENTATION_PLAN_HOMEPAGE.md` | Homepage dashboard + trip day-by-day timeline |
| `IMPLEMENTATION_PLAN_ENHANCEMENTS.md` | Health platform data, dual-calorie model, photos |
| `IMPLEMENTATION_PLAN_VALIDATION.md` | **All validation rules + warning messages** (app-wide) |
| `IMPLEMENTATION_PLAN_UX_AI.md` | AI daily advice, portion sizes, save flow |
| `IMPLEMENTATION_PLAN_UX_POLISH.md` | AI food detection, thumbnails, save/discard guards |
| `IMPLEMENTATION_PLAN_INLINE_PHOTO.md` | Inline notes editing, full-screen photo viewer |
| `IMPLEMENTATION_PLAN_HEALTH.md` | Health Connect / HealthKit integration |
| `IMPLEMENTATION_PLAN_EXTRA_FEATURES.md` | Wellness stats, journal search/filter, trip sort/filter, PDF export |
| `IMPLEMENTATION_PLAN_REAL_AI.md` | Swapping mock AI services for real Gemini calls |
| `tripjournal_schema.sql` | The database schema (already applied to Supabase) |

---

## Architecture (important — please follow)

### Repository pattern — UI never talks to a data source directly

All data access goes through an **interface**. The UI and controllers depend on
the interface, never on a concrete implementation:

```dart
abstract class JournalRepository { ... }     // the contract
class MockJournalRepository     implements JournalRepository { ... }   // dev/tests
class SupabaseJournalRepository implements JournalRepository { ... }   // real
```

Swapping mock → Supabase is a **one-line change** in the provider/locator.
**Do not** call Supabase directly from a widget or controller.

### Mock-first development

Build and test against the **mock** implementations first, then swap in the real
data source. This keeps the app runnable in an emulator without a network or a
physical device.

### `BACKEND_MODE` — one switch for the whole app

Which data sources the app uses is **one** decision, not one per repository:

```bash
flutter run                                  # mock (the default)
flutter run --dart-define=BACKEND_MODE=supabase
```

`lib/data/backend_mode.dart` reads it once; `repository_locator.dart` and
`trip_repository_locator.dart` both route through it, covering the journal
repository, photo storage, trip repository, trip cover storage and the
current-user-id provider.

It is a single switch on purpose. When each locator chose independently, a
half-migrated state was representable — real journal rows written against a mock
trip id, or a real trip owned by `kMockUserId`, which no `auth.uid()` will ever
match. Those states fail **silently**: the write is accepted and the row simply
never comes back. An unrecognised value (`BACKEND_MODE=supabse`) throws rather
than falling back to mock, for the same reason.

`flutter test` passes no define, so the suite always runs on mock.

**Supabase mode needs a signed-in user.** Every RLS policy gates on `auth.uid()`,
and an anonymous session doesn't error — it reads back empty.

### State management

**Riverpod.** Please stick with it — don't introduce a second state solution.

---

## Database

Supabase (PostgreSQL). The schema is already applied — see `tripjournal_schema.sql`.

**Existing tables:** `trips`, `journal_entries`, `health_logs`, `meals`

### If you're adding tables, follow these conventions:

- **`user_id uuid references auth.users(id)`** — every user-owned table has one.
  (⚠️ If we later add a `profiles` table and standardise on it, these foreign
  keys get migrated. Flagged in the schema file.)
- **Enable Row Level Security (RLS)** on every table, with policies scoping rows
  to `auth.uid() = user_id`. Copy the pattern from `tripjournal_schema.sql`.
  **Do not skip this** — without it, either your data is public or your queries
  silently return nothing.
- `snake_case` column names.
- Photos are **not** stored in tables — files go to Supabase **Storage**, and
  only the resulting URL string is saved in the DB.

---

## Module Ownership

| Module | Owner | Status |
|---|---|---|
| **Wellness Journal** (entries, health logging, meals, AI advice) | Tan Sang You | ✅ Built |
| **Trip Management** (create/edit/delete trip, homepage CRUD) | Nicholas Loo Jin Jack   |In Progress |
| **Trip Recap** (location/date tagging, AI trip summary) | Siow Wei Juin | In Progress |
| **Authentication / User Management** |  Mah Chao Wei | In Progress|
| **Admin** |  Khor Zhen Yin| In Progress |

### Notes for whoever picks up the open modules

- The `Trip` model and `TripRepository` interface are the **single source of
  truth** — build on top of them, don't declare a second `Trip` class.
- **Auth:** the app currently has no logged-in user, which means RLS blocks
  queries. Wiring up Supabase Auth is what makes the real (non-mock)
  repositories actually work end-to-end.
- Follow the existing repository-interface pattern for your module's data layer.

---

## Testing Notes

- Most of the app runs fine in an **emulator** using the mock data sources.
- **Health Connect / HealthKit do NOT work on emulators.** The health
  integration must be verified on a **physical phone** (a wearable is not
  required — phones count steps natively).
- Manual entry is always available as a fallback, so a missing health platform
  never blocks the app.

---

## Things That Will Bite You

- **No `.env`** → app crashes on startup. Copy `.env.example` and get the keys.
- **Never commit `.env`.** It's gitignored — keep it that way. A leaked key in
  commit history can't be cleanly removed.
- **RLS + no auth** → inserts/selects get rejected. This is expected until the
  Auth module is built; use the mock repositories in the meantime.
- **Don't bypass the repository interfaces** — direct Supabase calls in widgets
  will break the mock/real swap and the tests.
