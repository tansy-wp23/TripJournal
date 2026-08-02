# User Management Module — Progress Log

## Phase 0 — Recon & Contracts (complete)

### Repo Recon (2026-08-02)

**State: existing, mature Flutter project — NOT a fresh scaffold.**

- Flutter project `tripjournal` with `pubspec.yaml`; Dart SDK `^3.12.2`.
- Dependencies already include `supabase_flutter: ^2.16.0`,
  `flutter_riverpod: ^3.3.2`, `flutter_dotenv: ^6.0.1`, `http`, `image_picker`,
  `health`, `pdf`, `printing`.
- `lib/main.dart` already calls `Supabase.initialize(...)` from `.env`
  (`SUPABASE_URL`, `SUPABASE_ANON_KEY`). `.env` exists locally; `.env.example`
  is committed.
- Existing folder structure:
  - `lib/data/` — flat repository layer: `journal_repository.dart`,
    `mock_journal_repository.dart`, `supabase_journal_repository.dart`,
    `trip_repository.dart`, `mock_trip_repository.dart`,
    `supabase_trip_repository.dart`, plus DI locators
    `repository_locator.dart` / `trip_repository_locator.dart`.
  - `lib/models/` — `trip.dart`, `journal_entry.dart`, `health_log.dart`,
    `meal.dart`, `geo_tag.dart`, enums (`mood.dart`, `meal_type.dart`,
    `portion_size.dart`).
  - `lib/features/` — `health/`, `home/`, `journal/`, `trip/` (feature folders
    with `controller/`, `screens/`, `widgets/` subfolders).
  - `lib/validation/` — per-entity validation.
  - `test/` — extensive widget/unit tests (60+ files).
- `tripjournal_schema.sql` exists: `trips`, `journal_entries`, `health_logs`,
  `meals`. All reference `auth.users(id)` directly. **No `Profile` /
  `VerificationCode` tables yet.**
- `lib/features/trip/mock_user.dart` defines `kMockUserId = 'user-001'` — a
  placeholder until real auth lands. This module supersedes that placeholder.
- No `docs/` directory, no `supabase/` directory yet.

### Folder Convention (adopted)

**Matches the existing repo layout** (flat `lib/data/` for repositories,
`lib/models/` for entities, `lib/features/<name>/` for screens/widgets/state):

```
lib/models/           # entities: Profile, VerificationCode, AppSession
lib/data/             # repository interfaces + mock/real implementations + locators
lib/features/auth/    # auth screens, widgets, state
lib/features/profile/ # profile screens, widgets, state
supabase/functions/   # Edge Functions (Phase 6)
supabase/migrations/  # SQL migrations (Phase 6)
docs/user-management/PROGRESS.md
```

Mock implementations live in `lib/data/` (e.g. `mock_auth_repository.dart`)
and real ones in `lib/data/` too (e.g. `supabase_auth_repository.dart`),
mirroring the existing `mock_journal_repository.dart` /
`supabase_journal_repository.dart` pattern. A single locator file
(e.g. `lib/data/user_management_repository_locator.dart`) swaps mock ↔ real
in one line, mirroring `lib/data/repository_locator.dart`.

### Architecture Summary (locked decisions)

1. **Supabase Auth handles Google OAuth + sessions.** No custom
   Google-token verification or session-token hashing code.
2. **`LinkedProvider` superseded by `auth.identities`** — no table.
3. **`Session` superseded by Supabase session/JWT handling** — no table.
   Deactivation sign-out via `auth.admin.signOut(userId)` (Phase 6).
4. **`Profile` stays custom** — `userID` 1:1 FK to `auth.users.id`, holds
   `status` (active/deactivated) + app-specific fields.
5. **`VerificationCode` stays custom** — fully hand-built OTP table + logic.
6. **Reactivation** = sign in again with same Google account → code sent to
   that same (Google/social) email. No separate "enter your email" step.
7. **Deactivated accounts must not get silent access.** Client-side gate
   after sign-in: fetch `Profile`, branch on `status`. Cross-cutting
   consequence: other modules' RLS should use `is_active_user()` (Phase 8).
8. **Mock-first** — UI depends on repository interfaces; mocks in Phase 1,
   real Supabase wiring in Phase 6–7.
9. **Google is the only provider for now** — interfaces stay provider-agnostic.

### Custom-Auth Sequence (reference for Phases 2/4/5)

1. Google sign-in via Supabase Auth (`AuthRepository.signInWithGoogle()`).
2. Fetch/create `Profile` (`ProfileRepository.createProfileIfMissing()`).
3. Branch on `Profile.status`:
   - `active` → navigate into the app.
   - `deactivated` → keep the (valid) Supabase session but show the
     reactivation code-entry screen; do **not** navigate in. Cancel →
     `signOut()` (don't leave a gated session sitting around).

### Phase 0 Deliverables

- [x] `docs/user-management/PROGRESS.md` created (this file).
- [x] Folder structure agreed and created (matches existing repo layout).
- [x] Entities defined: `Profile`, `VerificationCode`, `AppSession`.
      **No `LinkedProvider` / `Session` entities created.**
- [x] Repository interfaces defined (no implementations):
      `AuthRepository`, `ProfileRepository`, `AccountLifecycleRepository`,
      `VerificationCodeRepository`.
- [x] Code compiles (`flutter analyze` clean).

### Files touched (Phase 0)

- `docs/user-management/PROGRESS.md` (this file)
- `lib/models/profile.dart`
- `lib/models/verification_code.dart`
- `lib/models/app_session.dart`
- `lib/data/auth_repository.dart`
- `lib/data/profile_repository.dart`
- `lib/data/account_lifecycle_repository.dart`
- `lib/data/verification_code_repository.dart`
- `.gitkeep` placeholders for `supabase/functions`, `supabase/migrations`.

### Deviations from plan

- **Folder convention:** the plan originally proposed
  `lib/features/{auth,profile}/{domain,data,presentation}/`. Per teammate
  feedback, this was refactored to **match the existing repo layout**:
  entities in `lib/models/`, repository interfaces + implementations +
  locators in `lib/data/`, and screens/widgets/state in
  `lib/features/{auth,profile}/`. The implementation plan
  (`USER_MANAGEMENT_IMPLEMENTATION_PLAN.md` Phase 0 task 2) was updated to
  match.
- `validateCode()` returns a `CodeValidationResult` enum
  (`valid`/`invalid`/`expired`) instead of `bool`, so Phase 4's wrong-code vs
  expired-code UI states don't require an interface change later.
- `getProfile()` / `createProfileIfMissing()` take an explicit `userId`
  (plus email/displayName for create) rather than reading auth state
  internally, keeping the repository testable and decoupled from the auth
  stream.
- `UserRole` enum defined as `{ user, admin }` — provisional; the Admin
  module owns the final role vocabulary.

### Next phase (Phase 1) should start with

Implement the four mock repositories in `lib/data/`
(`mock_auth_repository.dart`, `mock_profile_repository.dart`,
`mock_verification_code_repository.dart`,
`mock_account_lifecycle_repository.dart`), plus a DI locator
(`lib/data/user_management_repository_locator.dart`, mirroring
`lib/data/repository_locator.dart`) so screens depend on interfaces only.