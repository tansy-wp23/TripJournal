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

---

## Phase 1 — Mock Repositories (complete)

### What was built

In-memory fakes for all 4 repository interfaces, so UI work in Phases 2–5
never blocks on a backend.

- **`MockAuthRepository`** (`lib/data/mock_auth_repository.dart`) — simulates
  a Google sign-in with a configurable result
  (`MockAuthResult.success` / `.failure` / `.cancelled`) and exposes a fake
  `authStateChanges()` broadcast stream so screens react to sign-in/sign-out
  the same way they would with the real Supabase stream.
- **`MockProfileRepository`** (`lib/data/mock_profile_repository.dart`) —
  seeded with a configurable profile state
  (`MockProfileState.firstTime` / `.active` / `.deactivated`); supports
  `getProfile` / `createProfileIfMissing` / `updateProfile`.
- **`MockVerificationCodeRepository`**
  (`lib/data/mock_verification_code_repository.dart`) — generates a fixed
  code (`"123456"`, printed to console), tracks `attempt_count`, enforces
  expiry via a configurable `codeLifetime`, locks out after `maxAttempts`
  wrong attempts, and `resendCode` invalidates the previous code (a fresh
  one with a unique `codeID` replaces it).
- **`MockAccountLifecycleRepository`**
  (`lib/data/mock_account_lifecycle_repository.dart`) — deactivate/reactivate
  state transitions on the mock profile, calling into the mock verification
  repo for code validation. Throws `CodeValidationException` on wrong/expired
  codes.
- **DI locator** (`lib/data/user_management_repository_locator.dart`) — the
  one place the app resolves its user-management repositories from, mirroring
  `repository_locator.dart` / `trip_repository_locator.dart`. All four are
  wired to mocks; Phase 7 swaps each `Mock*` for the real `Supabase*` in one
  line here.

### Files touched (Phase 1)

- `lib/data/mock_auth_repository.dart` (new)
- `lib/data/mock_profile_repository.dart` (new)
- `lib/data/mock_verification_code_repository.dart` (new)
- `lib/data/mock_account_lifecycle_repository.dart` (new)
- `lib/data/user_management_repository_locator.dart` (new)
- `lib/models/profile.dart` (modified — added `clearDeactivatedAt` flag to
  `copyWith` so reactivation can null out `deactivatedAt`)
- `test/mock_auth_repository_test.dart` (new — 5 tests)
- `test/mock_profile_repository_test.dart` (new — 6 tests)
- `test/mock_verification_code_repository_test.dart` (new — 8 tests)
- `test/mock_account_lifecycle_repository_test.dart` (new — 6 tests)

### Deviations from plan

- **`Profile.copyWith` gained a `clearDeactivatedAt` boolean flag.** The
  standard `copyWith` pattern can't set a nullable field back to `null`
  (passing `null` means "keep the existing value"). Reactivation needs to
  clear `deactivatedAt`, so the flag was added. This is a Phase 0 entity
  change, noted here because it was discovered during Phase 1 testing.
- **`MockVerificationCodeRepository` uses a monotonic `_codeCounter`** in
  addition to `now.millisecondsSinceEpoch` for `codeID`, so two `sendCode`
  calls in the same millisecond (e.g. in tests) still produce distinct IDs.
  Discovered during Phase 1 testing.
- **`MockAccountLifecycleRepository` exposes its dependencies as public
  fields** (`profileRepository`, `verificationCodeRepository`) rather than
  private, to satisfy the `prefer_initializing_formals` lint while keeping
  the constructor API stable. Tests use these to inspect state.

### Verification

- `flutter analyze` — no issues found.
- `flutter test` (the 4 new test files) — 25 tests, all passed.

### Definition of Done

- [x] All 4 mocks implemented and unit-testable
- [x] Mock auth repo can simulate: success, failure, cancelled sign-in
- [x] Mock profile repo can simulate: first-time (no profile → create),
      active, and deactivated states
- [x] A single config flag/file controls mock vs. real (the DI locator
      `user_management_repository_locator.dart`; real doesn't exist yet)

### Next phase (Phase 2) should start with

Build the login screen + authentication flow against the mocks:
`AuthRepository.signInWithGoogle()` → `ProfileRepository.createProfileIfMissing()`
→ branch on `Profile.status` (active → navigate in; deactivated → route to
reactivation screen). Listen to `authStateChanges()` for session persistence.
Screens go in `lib/features/auth/` and `lib/features/profile/`.
