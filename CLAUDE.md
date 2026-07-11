# Project Context

## Course & Team (BMSE3004 — Collaborative Development, TARUMT)

- Team: Nicholas Loo Jin Jack (Project Manager), Mah Chao Wei (Design Lead),
  Tan Sang You (Requirements Lead), Siow Wei Juin (Development Lead),
  Khor Zhen Yin (Testing & Documentation Lead)
- Tutor: Sir Muhammad Irsyad Bin Kamil Riadz
- Sang You's assigned module: **Journal + Health Tracking (AI-aided)**

## App Concept: TripJournal

Originally an itinerary-planner + travel journal app. **Pivoted** to a
note-taking / journal app focused on travel **and health tracking**.

Cut from scope entirely: itinerary planner, elderly pacing recommendations,
live public-transport tracking.

## Final Module List (5 modules)

1. **Journal + Health Tracking (AI-aided)** — *Sang You's module*
   - Journal entries: text, photos, mood
   - Health logging lives inside this module (not a separate module): meals
     (with AI food-intake advice), step count, calories
   - Standard CRUD on entries/logs (create, edit, delete) happens here

2. **Location/Date-Time + AI-generated Trip Summary**
   - Auto-tags each journal entry with location + date/time (no manual tagging)
   - AI generates a trip summary by reading all journal entries under one trip

3. **Authentication**

4. **Admin**

5. **Trip Management (CRUD)**
   - Parent container object: `Trip (id, title, cover_photo, start_date, end_date, user_id)`
   - Journal entries belong to a trip via `trip_id` foreign key
   - Handles create / rename / delete of trips
   - Open design decision: on trip delete, cascade-delete its journal entries,
     or ask the user / keep them orphaned?

### Data model relationship

```
Trip (parent)
 └── has many → Journal Entries (trip_id FK)
                  └── has one → Health Log (steps, calories, meals per entry/day)
```

Trip Management is the organizing layer above Journal — it doesn't compete
with the Journal module, it groups entries so Trip Summary knows what to
summarize (per-trip, not the whole account).

## Business Model

**One-time purchase** — not freemium, not subscription, not commission-based.
User pays once to unlock the full app.

## SDG Alignment

Switched from **SDG 11 (Sustainable Cities)** to **SDG 3 (Good Health and
Well-being)** — SDG 11's justification relied on public transport / elderly
pacing, both of which were cut. SDG 3 fits the health-tracking pivot.

## Proposal Writing — Progress So Far

- **1.3.1 Problem** — drafted. Core argument: journaling apps (e.g. Day One)
  and health-tracking apps (e.g. MyFitnessPal) solve only half the problem
  each; users fragment effort across both. AI food-recognition is useful but
  imperfect — positioned as an assistant, not a replacement for user input.
- **References in use (APA 7th)**:
  - Baikie, K. A., & Wilhelm, K. (2005). Emotional and physical health benefits
    of expressive writing. *Advances in Psychiatric Treatment, 11*(5), 338–346.
  - Li, X., Yin, A., Choi, H. Y., Chan, V., Allman-Farinelli, M., & Chen, J.
    (2024). Evaluating the quality and comparative validity of manual food
    logging and AI-enabled food image recognition in apps for nutrition care.
    *Nutrients, 16*(15), 2573.
  - Dugas, K., et al. (2026). Calorie-counting apps for monitoring and
    managing calorie intake in adults living with weight-related chronic
    diseases: Decade-long scoping review (2013–2024). *JMIR mHealth and
    uHealth.*
  - Child Mind Institute. (2025, March 21). The power of journaling: What
    science says about the benefits for mental health and well-being.
  - United Nations. (n.d.). Goal 3: Good health and well-being.
- **Slide deck (BMSE3004_Project_Proposal_Slide.pptx)** — updated: title,
  subtitle, core problem slide, background & motivation, project description,
  project significance. **Still pending**: SDG slide rewrite, tech stack
  slide, module detail slides (need to match the 5-module list above),
  business model slide (one-time purchase), reference list slide.

## Development Approach: Journal Module First (Mock-First)

Decision: build the Journal + Health Tracking module's UI and logic **before**
wiring up Supabase or any external API. Reasoning — Supabase is new (previous
experience was localhost-only); decoupling "learn Flutter state/UI" from
"learn Supabase" avoids debugging two unfamiliar things at once. The AI
food-advice feature can return stubbed/hardcoded responses for now.

**Constraint to make this safe (not just a shortcut that causes rework
later):** the UI must depend on a repository **interface**, not a concrete
data source, so swapping mock → Supabase later is a one-file change.

```dart
// journal_repository.dart — the contract the UI depends on
abstract class JournalRepository {
  Future<List<JournalEntry>> getEntries(String tripId);
  Future<void> addEntry(JournalEntry entry);
  Future<void> updateEntry(JournalEntry entry);
  Future<void> deleteEntry(String id);
}

// mock_journal_repository.dart — build against this NOW
class MockJournalRepository implements JournalRepository { ... }

// supabase_journal_repository.dart — swapped in LATER, same interface
class SupabaseJournalRepository implements JournalRepository { ... }
```

Screens/widgets only ever depend on `JournalRepository` (the interface) —
never on the mock or Supabase class directly.

**Still open / do this before writing UI:** lock down the actual field shapes
for `JournalEntry` and `HealthLog` (steps, calories, meals, mood, AI advice,
trip_id, location, date) — this is the one part that *does* cause rework if
it's designed loosely now and the real Supabase table ends up different.

## Tech Stack (from original proposal — needs updating)

| Component | Current | Notes |
|---|---|---|
| Frontend | Flutter / React Native | unchanged |
| Backend | Node.js / Python FastAPI | unchanged |
| Database | MySQL / Firebase Firestore | unchanged |
| Map/Location | Google Maps API / Mapbox | unchanged |
| AI | OpenAI API / Gemini API | now used for food-intake advice + trip summary generation, not route suggestions |
| Auth | Firebase Authentication | unchanged |
| ~~Transport~~ | ~~GTFS Realtime API~~ | **remove** — live transport tracking cut |
| Health data | *not yet decided* | consider Google Fit / Apple HealthKit for step tracking |

---

# Separate Project: Cafeteria Food Ordering System

Different course/project — not discussed in detail in this chat, so treat
the below as a starting point to confirm/expand, not a complete spec.

- Payment module uses the **State design pattern**
- Includes an **eWallet redirect flow**
- Tech stack, other modules, and team structure: not yet documented here

---

*Generated from a claude.ai planning conversation. Commit this file to the
repo root so Claude Code (and teammates using it) share the same context.
Keep it updated as decisions change — especially the pending slide work
and the cafeteria project details.*
