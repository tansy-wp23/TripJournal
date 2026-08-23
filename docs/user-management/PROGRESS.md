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

---

## Phase 2 — Sprint 1: Core Authentication (mock) (complete)

### What was built

The full mock Google sign-in flow: a guest can sign in, land in the app, and
stay signed in — with deactivated accounts correctly diverted to the
reactivation screen instead of let in.

- **`AuthController`** (`lib/features/auth/controller/auth_controller.dart`) —
  the authentication flow controller. Calls `signInWithGoogle()` →
  `createProfileIfMissing()` → branches on `Profile.status`. Exposes an
  `AuthStatus` enum (`signedOut` / `loading` / `authenticated` /
  `deactivated`) that the UI routes on. Listens to
  `authStateChanges()` for session persistence (PB-08). Handles all 3
  sign-in outcomes: success, failure (error message), cancelled (error
  message). Derives a display name from the email for first-time users.
- **`LoginScreen`** (`lib/features/auth/screens/login_screen.dart`) — the
  Social Login Component UI. A single "Sign in with Google" button, a
  loading spinner during sign-in, and an error banner for failure/cancel.
- **`ReactivationScreen`** (`lib/features/auth/screens/reactivation_screen.dart`)
  — a **Phase 2 stub**. Shown when a deactivated user signs in (PB-06
  detection). Has a code-entry field, confirm button (stub), and a cancel
  button that calls `signOut()` (Architecture Decision 7 — don't leave a
  gated session hanging). Full code-entry logic lands in Phase 4/5.
- **`AuthGate`** (`lib/features/auth/auth_gate.dart`) — the top-level
  routing widget. Watches `authControllerProvider.status` and routes to
  `LoginScreen` / `HomeScreen` / `ReactivationScreen` / a loading spinner.
  This is the "Session Management" component (PB-08) — keeps navigation in
  sync with auth state.

### Files touched (Phase 2)

- `lib/features/auth/controller/auth_controller.dart` (new)
- `lib/features/auth/screens/login_screen.dart` (new)
- `lib/features/auth/screens/reactivation_screen.dart` (new)
- `lib/features/auth/auth_gate.dart` (new)
- `test/auth_controller_test.dart` (new — 8 tests)
- `docs/user-management/PROGRESS.md` (this entry)

### Deviations from plan

- **`AuthController` does not take `AccountLifecycleRepository`** as a
  constructor parameter (the plan's Phase 2 didn't specify this, but the
  initial implementation did). It was removed because Phase 2 only needs
  `AuthRepository` + `ProfileRepository`; the lifecycle repo will be wired
  in Phase 5 when reactivation confirmation is implemented. The
  `onReactivated()` method is stubbed for Phase 5 to call after
  `confirmReactivation()`.
- **`AuthGate` is not yet wired into `main.dart`** as the app's root widget.
  The plan says this is Phase 7's job ("not yet wired as the app's actual
  home route"). The existing `HomeScreen` with `kMockUserId` remains the
  default. `AuthGate` is ready to be swapped in but deliberately isn't, to
  avoid breaking the existing journal/trip flows that depend on
  `kMockUserId`.
- **`ReactivationScreen` is a stub** — the code-entry field and confirm
  button don't do anything yet. Phase 4 replaces the field with the real
  OTP widget; Phase 5 wires `confirmReactivation()`.

### Verification

- `flutter analyze` — no issues found.
- `flutter test test/auth_controller_test.dart` — 8 tests, all passed.

### Manual test steps (for reference / Phase 7 re-verification)

1. **Success:** With `MockAuthResult.success` + `MockProfileState.active`,
   tapping "Sign in with Google" → `AuthStatus.authenticated` → `HomeScreen`.
2. **First-time:** With `MockProfileState.firstTime`, sign-in creates a
   profile → `AuthStatus.authenticated` → `HomeScreen`.
3. **Deactivated:** With `MockProfileState.deactivated`, sign-in →
   `AuthStatus.deactivated` → `ReactivationScreen` (not `HomeScreen`).
4. **Failure:** With `MockAuthResult.failure`, sign-in → error banner
   "Sign-in failed: …" → stays on `LoginScreen`.
5. **Cancelled:** With `MockAuthResult.cancelled`, sign-in → error banner
   "Sign-in cancelled." → stays on `LoginScreen`.
6. **Session persistence:** After a successful sign-in, the `AuthGate`
   keeps showing `HomeScreen` (driven by `authStateChanges()` listener).
   After `signOut()`, it returns to `LoginScreen`.

### Definition of Done

- [x] All 3 mock auth outcomes (success/fail/cancel) are reachable and
      visibly handled in the UI
- [x] Mock "deactivated" profile correctly routes away from the main app
- [x] Signed-in state persists across screen navigation
- [x] Manual test steps documented in `PROGRESS.md`

---

## Phase 3 — Sprint 2a: Logout + Profile (mock) (complete)

### What was built

**Note:** The **logout component** was already completed in a separate
commit (`785a032 feat(auth): route app root through AuthGate, wire logout
button`) before this session — `HomeScreen`'s "Log out" menu item calls
`AuthController.signOut()`, and `AuthGate` reacts to the resulting
`signedOut` status and swaps back to `LoginScreen`. This phase added the
remaining profile work.

- **`ProfileController`** (`lib/features/profile/controller/profile_controller.dart`)
  — loads the profile for the signed-in user via `ProfileRepository.getProfile()`
  and updates the display name via `updateProfile()`. Reads the current user id
  from `AuthController.currentUserId` (which derives it from the session).
  Uses `validateProfileDisplayName()` as the save-time backstop.
- **`ProfileViewScreen`** (`lib/features/profile/screens/profile_view_screen.dart`)
  — profile view screen (PB-10). Shows avatar, display name, email, role,
  status, member-since, and last-login. "Edit" icon navigates to the edit
  screen.
- **`ProfileEditScreen`** (`lib/features/profile/screens/profile_edit_screen.dart`)
  — profile edit screen (PB-11). Edits `display_name` with inline validation
  via `validateProfileDisplayName()`. Shows the email (read-only, owned by
  Google/Supabase Auth) with a note explaining it cannot be changed. Cancel
  discards changes; Save calls `updateDisplayName()` and pops back on success.
- **`validateProfileDisplayName`** (`lib/validation/profile_validation.dart`)
  — rejects empty/whitespace-only names and names over 50 chars. `email` is
  deliberately NOT editable/validated here (owned by Google/Supabase Auth).
- **`Profile` menu item** wired into `HomeScreen`'s popup menu → navigates to
  `ProfileViewScreen`.

### Files touched (Phase 3)

- `lib/features/profile/controller/profile_controller.dart` (new)
- `lib/features/profile/screens/profile_view_screen.dart` (new)
- `lib/features/profile/screens/profile_edit_screen.dart` (new)
- `lib/validation/profile_validation.dart` (new)
- `lib/features/home/home_screen.dart` (modified — added Profile menu item)
- `test/profile_validation_test.dart` (new — 4 tests)
- `test/profile_controller_test.dart` (new — 6 tests)

### Decision: what's editable

Only `display_name` is editable. `email` is owned by Google/Supabase Auth and
is not independently editable (per the plan: "email is owned by
Google/Supabase Auth and probably shouldn't be independently editable here
— decide and note the decision in PROGRESS.md"). This decision is also
documented in `lib/validation/profile_validation.dart`.

### Verification

- `flutter analyze` — no issues found.
- `flutter test` (profile_validation_test 4 + profile_controller_test 6) —
  all passed.
- Full regression check (`auth_controller_test`, `home_screen_nudge_test`,
  `widget_test`) — all passed.

### Definition of Done

- [x] Logout returns user to login screen (done in commit `785a032`,
      verified here)
- [x] Profile view + edit both work against the mock repo
- [x] Invalid input is rejected with a visible message, valid input saves
- [x] Decision on editable fields documented in PROGRESS.md

---

## Phase 4 — Sprint 2b: Verification Code Component (mock) (complete)

### What was built

The shared OTP component, built standalone since both deactivation and
reactivation depend on it. Also fixes the OTP auto-advance focus bug noted
in the implementation plan's "Known Issues" section.

- **`CodeEntryScreen`** (`lib/features/auth/screens/code_entry_screen.dart`)
  — the reusable code-entry screen (PB-15 through PB-18). Takes a
  `VerificationPurpose` so it's used for both reactivation and deactivation.
  Handles:
  - **Code entry** — the 6-digit OTP widget with error-border state.
  - **Send/resend** — "Resend code" button calls
    `requestReactivation()`/`requestDeactivation()` (which invalidate the
    prior code and send a fresh one).
  - **Validation** — distinguish wrong-code ("Incorrect code. Please try
    again.") from expired-code ("This code has expired. Please resend a new
    one.") via the `CodeValidationResult` enum.
  - **Cancel** — reactivation cancel calls `signOut()` (Architecture
    Decision 7 — don't leave a gated session hanging); deactivation cancel
    pops back without side effects.
- **`ReactivationScreen`** (`lib/features/auth/screens/reactivation_screen.dart`)
  — now a **thin wrapper** around `CodeEntryScreen` with
  `purpose: VerificationPurpose.reactivation`. No longer a stub.
- **`AuthController`** (`lib/features/auth/controller/auth_controller.dart`) —
  now takes `AccountLifecycleRepository` as a third constructor parameter
  and exposes the lifecycle methods the code-entry screen needs:
  `requestReactivation()`, `confirmReactivation(code)`,
  `requestDeactivation()`, `confirmDeactivation(code)`. `signInWithGoogle()`
  now **automatically sends a reactivation code** when the profile is
  deactivated (PB-06 detection completed — no manual "request code" step
  needed; the user lands on the code-entry screen with a code already on
  its way).
- **OTP auto-advance focus fix** (`lib/features/auth/widgets/otp_code_input.dart`)
  — the `KeyboardListener` wrapper previously held a separate `FocusNode`
  from the `TextField` inside it, so `requestFocus()` didn't move the
  cursor. Fix: **removed the `KeyboardListener` entirely** and pass the
  `FocusNode` directly to the `TextField`. Backspace-to-previous is now
  handled by detecting an empty value on an already-empty box in
  `_onChanged` (clears the previous box and focuses it).
- **Backspace-on-empty-box fix (post-Phase-4 manual test)** — the initial
  `_onChanged`-based backspace detection was dead code: pressing backspace
  on an *already-empty* `TextField` never fires `onChanged` (the text value
  didn't change), so nothing happened. Reworked to wrap each box in a
  `Focus` widget with `onKeyEvent` that intercepts the backspace **after**
  the TextField has had its own chance to consume it. Two cases:
  - Backspace on an **empty** box → the TextField does nothing, so the
    ancestor `Focus` handler clears the previous box and moves focus back.
  - Backspace on a **filled** box → the TextField clears it (observed via
    `onChanged`), and a `_boxClearedByTextField` flag tells the bubbling
    `Focus` handler to swallow the event rather than clear yet another box.
  Uses **two FocusNodes per box** (one for the `Focus` ancestor, one owned
  by the `TextField`) so `requestFocus()` still moves the real cursor.
  Covered by `test/otp_code_input_test.dart` (4 widget tests).
- **Tests** — `test/code_entry_screen_test.dart` (new — 6 widget tests) and
  expanded `test/auth_controller_test.dart` (added 7 controller tests for
  the lifecycle methods + deactivated-auto-send).

### Files touched (Phase 4)

- `lib/features/auth/screens/code_entry_screen.dart` (new)
- `lib/features/auth/screens/reactivation_screen.dart` (rewritten — wrapper
  around `CodeEntryScreen`)
- `lib/features/auth/controller/auth_controller.dart` (modified — added
  `AccountLifecycleRepository`, lifecycle methods, and deactivated auto-send)
- `lib/features/auth/widgets/otp_code_input.dart` (modified — fixed OTP
  auto-advance focus bug)
- `test/code_entry_screen_test.dart` (new — 6 widget tests)
- `test/auth_controller_test.dart` (modified — 7 new tests)
- `test/profile_controller_test.dart` (modified — constructor arg update)

### Deviations from plan

- **The `KeyboardListener` was removed entirely, not just given the
  `FocusNode`.** The plan suggested passing the `FocusNode` to the
  `TextField` *while keeping* `KeyboardListener`, but sharing one
  `FocusNode` between two widgets caused Flutter's
  "Tried to make a child into a parent of itself" assertion (the
  `KeyboardListener` was reparenting the `TextField`'s subtree). The
  simpler fix that actually works: delete `KeyboardListener`, pass the
  `FocusNode` directly to `TextField`, and detect backspace-on-empty via
  `onChanged` (empty value on an already-empty box = backspace was pressed).
- **`confirmDeactivation` is implemented in Phase 4, not Phase 5**, because
  the code-entry screen is shared and needs both branches to compile.
  Phase 5 adds the Profile-screen entry point and the actual
  deactivation flow UI.
- **Deactivated-auto-send lives in `AuthController.signInWithGoogle()`
  rather than the `AuthGate`.** This keeps the "check profile status →
  send code" logic in one testable place (the controller) instead of
  spreading it across widgets. The `AuthGate` still routes on
  `AuthStatus.deactivated` as before.

### Verification

- `flutter analyze` — no issues found.
- `flutter test` (auth_controller 16 + code_entry_screen 6 +
  profile_controller 6) — all passed (26 tests).

### Definition of Done

- [x] Code entry screen reusable for both purposes (reactivation + deactivation)
- [x] Expired code and wrong code both produce correct UI feedback
- [x] Resend invalidates the prior code (verified in widget test)
- [x] Deactivated sign-in attempt correctly and automatically routes to
      this screen with a code already sent
- [x] Cancelling from this screen signs the user out
- [x] OTP auto-advance focus bug fixed (Known Issues)

---

## Phase 5 — Sprint 3: Account Lifecycle (mock) (complete)

### What was built

The account lifecycle flows, end-to-end against the mocks. Deactivation now
has a UI entry point from the Profile screen, and the reactivation flow
(partially wired in Phase 4) is verified end-to-end.

- **Deactivation entry point** (`lib/features/profile/screens/profile_view_screen.dart`)
  — a "Deactivate Account" button (PB-13) at the bottom of the profile view,
  styled with the error color, plus a short explanatory caption. Tapping it
  opens `CodeEntryScreen` with `purpose: VerificationPurpose.deactivation`.
- **Deactivation confirmation** (`lib/features/auth/screens/code_entry_screen.dart`)
  — on a valid code, `confirmDeactivation(code)` sets the profile to
  `deactivated` and signs the user out (PB-14). The screen now also
  `popUntil(isFirst)` after a successful deactivation, so the pushed
  Profile + code-entry routes are removed and the root `AuthGate`'s
  `LoginScreen` is actually visible (previously the routes would have
  remained stacked above it).
- **Auto-send deactivation code on open (post-Phase-5 manual test)** — the
  deactivation `CodeEntryScreen` did not have a code sent when it opened
  (only reactivation gets one, via `AuthController.signInWithGoogle()`), so
  entering `123456` initially failed until the user manually pressed
  "Resend code". Fixed by auto-sending a deactivation code in `initState`
  (via `addPostFrameCallback` → `requestDeactivation()`), mirroring the
  reactivation flow. Verified by a new widget test
  ("auto-sends a deactivation code when the screen opens").
- **Reactivation flow (verified end-to-end)** — already wired in Phase 4:
  deactivated sign-in → auto-send code → `CodeEntryScreen` (reactivation) →
  valid code → profile active → `AuthGate` routes into the app. No second
  Google prompt (the gated session becomes fully authenticated).
- **Cancellable flows** — deactivation cancel pops back to the Profile
  screen with no side effects; reactivation cancel signs out (Architecture
  Decision 7).

### Files touched (Phase 5)

- `lib/features/profile/screens/profile_view_screen.dart` (modified — added
  "Deactivate Account" button + explanatory caption)
- `lib/features/auth/screens/code_entry_screen.dart` (modified — pop pushed
  routes after successful deactivation)
- `test/code_entry_screen_test.dart` (modified — added deactivation
  confirm test)

### Deviations from plan

- **`popUntil(isFirst)` after deactivation** — the plan didn't specify this,
  but without it the pushed Profile + code-entry routes would remain stacked
  above the `AuthGate`'s `LoginScreen` after sign-out, so the user would see
  a stale screen instead of the login. Discovered during Phase 5 testing.

### Verification

- `flutter analyze` — no issues found.
- `flutter test` (auth_controller 14 + code_entry_screen 7 + otp_code_input
  4 + profile_controller 6) — all passed (31 tests).

### Definition of Done

- [x] Full deactivate → session ends → back at login, works against mocks
- [x] Full reactivate (starting from a deactivated sign-in attempt) → ends
      with the user signed in and inside the app, without a second Google
      prompt, works against mocks
- [x] Both flows are cancellable before confirmation

### Checkpoint

At this point the entire user-management module works end-to-end against
mocks. This is a good point to demo/review before touching real
infrastructure (Phase 6).

---

## Phase 6 — Real Backend: Supabase Auth Config + Profile/VerificationCode (complete)

### What was built

The real backend, deployed directly to the Supabase project
(`wfuxyatvnztybsaajsfa`) per Manual Prerequisite C ("Agent deploys directly").

- **SQL migration** (`supabase/migrations/202608140001_user_management.sql`):
  - `public.profiles` — `user_id` (PK, FK to `auth.users.id`), `email`,
    `display_name`, `avatar_url`, `role` (check: user/admin), `status`
    (check: active/deactivated/suspended), `deactivated_at`, `last_login_at`,
    `created_at`, `updated_at`. `updated_at` auto-bumped by a
    `profiles_set_updated_at` trigger.
  - `public.verification_codes` — `code_id` (PK), `user_id` (FK), `code_hash`
    (sha256 hex — **no plaintext ever stored**), `purpose` (check:
    deactivation/reactivation), `attempt_count`, `created_at`, `expires_at`,
    `used_at`. Index on `(user_id, purpose, created_at desc)`.
  - `handle_new_user` trigger on `auth.users` insert — auto-creates a
    `Profile` row with `status = active`, seeding `display_name` and
    `avatar_url` from `raw_user_meta_data` (`full_name`/`name` and
    `avatar_url`/`picture`). Server-side source of truth for PB-03.
  - RLS: `profiles` — select/update own row only (`auth.uid() = user_id`);
    no client insert/delete. `verification_codes` — no client access at all
    (deny-all policy; only privileged functions touch it).
- **Edge Functions** (all deployed, `verify_jwt = false` in `config.toml`
  since they verify the JWT internally via `getUser()`):
  - `verification-send` — generates a 6-digit code, stores its hash,
    invalidates prior unused codes for the user+purpose, emails it via Gmail
    SMTP (denomailer, Manual Prerequisite B).
  - `verification-validate` — checks a code without consuming it; returns
    `valid`/`invalid`/`expired`/`locked`/`not_found`.
  - `verification-resend` — same as send (invalidates prior + sends fresh).
    **Later removed as dead code** (post-Phase 8): the app's "Resend code" button
    routes through `verification-send` only (see `SupabaseVerificationCodeRepository`),
    so `verification-resend` was never invoked. Removed from `config.toml`, the
    function directory was deleted, and the deployed function was dropped from
    Supabase. See "Dead code removal" below.
  - `account-deactivate-confirm` — validates the code, sets
    `status = deactivated` + `deactivated_at`, then
    `auth.admin.signOut(userId)` (Architecture Decision 3 — terminates all
    sessions).
  - `account-reactivate-confirm` — validates the code, sets
    `status = active` + clears `deactivated_at`. No signOut (Architecture
    Decision 7 — session was never revoked, only gated).
- **Shared helpers** (`supabase/functions/_shared/`): `codes.ts` (code
  generation, sha256 hashing, timing-safe compare, `validateCode` with
  attempt-count lockout after 5, 10-min TTL) and `email.ts` (Gmail SMTP via
  denomailer).

### Files touched (Phase 6)

- `supabase/migrations/202608140001_user_management.sql` (new)
- `supabase/functions/_shared/codes.ts` (new)
- `supabase/functions/_shared/email.ts` (new)
- `supabase/functions/verification-send/index.ts` (new)
- `supabase/functions/verification-validate/index.ts` (new)
- `supabase/functions/verification-resend/index.ts` (new — later deleted as dead code)
- `supabase/functions/account-deactivate-confirm/index.ts` (new)
- `supabase/functions/account-reactivate-confirm/index.ts` (new)
- `supabase/config.toml` (modified — registered the 5 new functions)
- `supabase/tests/verify_user_management.sql` (new — verification query)

### Deployment (Manual Prerequisite C: agent deploys directly)

- `supabase link --project-ref wfuxyatvnztybsaajsfa` — linked.
- `supabase db push` — applied `202608110001` (trip_destination, previously
  un-pushed) and `202608140001` (user_management).
- `supabase functions deploy` × 5 — all deployed.
- SMTP secrets (`SMTP_USERNAME`/`SMTP_PASSWORD`) — already set on the
  project (Manual Prerequisite B was completed by the human).
- Verified via `supabase db query`: `profiles` + `verification_codes` tables
  exist, `on_auth_user_created` trigger exists, and all 3 RLS policies are
  present.

### Deviations from plan

- **`verification-validate` uses the service-role key** (not the anon key)
  because it reads `verification_codes`, which RLS blocks for clients. The
  user's JWT is still verified via `getUser()` first, so this is safe — the
  service role is only used to bypass RLS on the codes table, never to
  impersonate the caller.
- **`verification-resend` duplicates `verification-send`'s logic** rather
  than delegating, to keep each function independently deployable and
  testable (the plan lists them as separate functions anyway).
- **`handle_new_user` uses `coalesce(full_name, name)` and
  `coalesce(avatar_url, picture)`** for the Google metadata keys — the plan
  said to confirm the actual key names against a real signed-in user. This
  is the standard Supabase/Google shape; Phase 7's real sign-in test will
  confirm and this can be adjusted if needed.

### Definition of Done

- [x] Google provider enabled and working in the Supabase dashboard
      (Manual Prerequisite A — completed by human)
- [x] Migrations for `Profile` and `VerificationCode` run cleanly on the
      project (no `LinkedProvider`/`Session` tables created)
- [x] `handle_new_user` trigger confirmed to create a `Profile` row on
      signup (trigger exists; end-to-end confirmed in Phase 7)
- [x] RLS confirmed: a user can only read/update their own `Profile`;
      `VerificationCode` is not directly reachable by clients
- [x] Every privileged function testable independently (curl / Supabase CLI
      invoke) — example requests documented below
- [x] No plaintext OTPs stored anywhere server-side (only sha256 hashes)

### Example requests (for Phase 7 / manual testing)

```bash
# Send a reactivation code (requires a user JWT)
curl -X POST https://wfuxyatvnztybsaajsfa.supabase.co/functions/v1/verification-send \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"purpose":"reactivation"}'

# Validate a code
curl -X POST https://wfuxyatvnztybsaajsfa.supabase.co/functions/v1/verification-validate \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"purpose":"reactivation","code":"123456"}'

# Confirm deactivation (signs the user out everywhere)
curl -X POST https://wfuxyatvnztybsaajsfa.supabase.co/functions/v1/account-deactivate-confirm \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"code":"123456"}'

# Confirm reactivation
curl -X POST https://wfuxyatvnztybsaajsfa.supabase.co/functions/v1/account-reactivate-confirm \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"code":"123456"}'
```

### Next phase (Phase 7) should start with

Real integration: add `supabase_flutter` + `google_sign_in` packages,
implement `SupabaseAuthRepository` using the **native ID-token flow**
(`GoogleSignIn().signIn()` → `supabase.auth.signInWithIdToken(...)`, NOT
`signInWithOAuth`), then `SupabaseProfileRepository` (direct RLS-protected
table access), then `SupabaseVerificationCodeRepository` +
`SupabaseAccountLifecycleRepository` calling the Phase 6 functions. Swap the
DI bindings in `user_management_repository_locator.dart` one at a time and
re-run the Phase 2–5 manual test steps against the real backend.

---

## Phase 7 — Real Integration: Swap Mocks for Real (complete)

### What was built

The real-backend integration, swapping mocks for real Supabase implementations
one repository at a time. **No UI code was touched** — the four repository
interfaces from Phase 0 are unchanged, so every screen/controller is already
wired correctly; only the DI bindings and the repository implementations
changed.

- **`SupabaseAuthRepository`** (`lib/data/supabase_auth_repository.dart`) — real
  `AuthRepository` using the **native ID-token flow** exactly as the plan
  specified: `GoogleSignIn().signIn()` → `googleUser.authentication` →
  `supabase.auth.signInWithIdToken(provider: OAuthProvider.google, idToken,
  accessToken)`. Includes a injectable `GoogleSignIn` (for tests), the web
  OAuth client ID (`serverClientId`, required on Android to get an idToken),
  `signOut()` (Google + Supabase), the `onAuthStateChange` stream mapped to
  `AppSession`, and `currentUserId()`.
- **`SupabaseProfileRepository`** (`lib/data/supabase_profile_repository.dart`) —
  real `ProfileRepository` via direct RLS-protected table access: `getProfile`
  (select by `user_id`), `createProfileIfMissing` (defensive fallback only — the
  `handle_new_user` trigger remains the primary mechanism), `updateProfile`
  (editable fields only).
- **`profile_supabase_mapper.dart`** (`lib/data/profile_supabase_mapper.dart`) —
  maps `Profile` model ↔ `profiles` table (camelCase ↔ snake_case), mirroring
  `trip_supabase_mapper.dart`.
- **`SupabaseVerificationCodeRepository`** (`lib/data/supabase_verification_code_repository.dart`)
  — calls the Phase 6 Edge Functions (`verification-send` / `verification-validate`),
  mapping the server's `result` string to
  `CodeValidationResult` (`valid`→valid, `expired`→expired, anything else
  including `invalid`/`locked`/`not_found`→invalid).
- **`SupabaseAccountLifecycleRepository`**
  (`lib/data/supabase_account_lifecycle_repository.dart`) — calls
  `account-deactivate-confirm` / `account-reactivate-confirm`. Maps a 400
  `{"error":"invalid_code:<reason>"}` into `CodeValidationException` and passes
  any other error through as-is. Includes the Admin Module Phase 5 guard:
  `confirmReactivation` checks `profile.isSuspended` before calling the confirm
  function, throwing `AccountSuspendedException` so a suspended account can't be
  self-reactivated (only `AdminAccountActionsRepository.reactivateUser` may clear
  it). Does **not** pre-validate the code client-side — see Deviations.
- **`SupabaseProfileAvatarStorage`** (`lib/data/supabase_profile_avatar_storage.dart`)
  — real avatar upload/delete via the `profile-avatars` storage bucket, mirroring
  `SupabaseTripCoverStorage`'s `trip-covers` bucket pattern.
- **DI locator swap** (`lib/data/user_management_repository_locator.dart`) —
  switched from top-level `final` mocks to **lazy getters** that instantiate the
  real `Supabase*` repositories on first access. The change to lazy getters
  (instead of top-level finals) was necessary because a top-level `final` runs
  its initializer at import time, and `Supabase.instance.client` throws if
  `Supabase.initialize` hasn't been called — which is exactly the case in unit /
  widget tests. Lazy getters defer instantiation to access time. The mock
  implementations remain in the codebase, wired only behind the
  overrides used by tests.
- **Backend fixes** (Phase 6 functions + migration that were written in Phase 6
  but only corrected once exercised against the real backend in Phase 7):
  - `codes.ts`: split `validateCode` into a **non-destructive** `validateCode`
    (no longer marks the code `used_at` on success) + a new explicit
    `consumeCode`. This makes `validateCode` safe to call as a live check, and
    stops the confirm functions from burning a code before their own side
    effects land.
  - `email.ts`: updated to the current `denomailer` runtime API —
    `SMTPClient` (was `SmtpClient`) with connection config nested under the
    `connection:` key. The API drifted between Phase 6 authoring and Phase 7
    running; fixed to compile against the live version.
  - All 5 Edge Functions (`verification-send`, `verification-validate`,
    `verification-resend` (later removed as dead code), `account-deactivate-confirm`,
    `account-reactivate-confirm`): fixed a **critical client-architecture bug**.
    Phase 6 built a single client with the service-role key *and* the user's JWT
    overriding `Authorization` — which silently defeated the RLS bypass (the
    override makes PostgREST apply the JWT's `authenticated` role, not
    `service_role`) and so `verification_codes` access still hit RLS. Now each
    function uses two clients: a **user-scoped client** (anon key + caller's JWT
    in `Authorization`) for `auth.getUser()` identity verification only, and a
    **service-role client** (service role key, `Authorization` left default) for
    `verification_codes` reads/writes + `auth.admin.signOut()`.
  - `account-deactivate-confirm` / `account-reactivate-confirm`: now call
    `consumeCode()` explicitly **after** their side effects (profile update,
    signOut for deactivate; profile update for reactivate) succeed, so a failed
    side effect leaves the code unconsumed and retryable without a resend.
  - Migration `202608140001`: `handle_new_user` corrected from `SECURITY
    INVOKER` to `SECURITY DEFINER` with `set search_path = public, pg_temp`.
    The `auth.users` insert trigger fires as the `supabase_auth_admin` role,
    which has no grants on `public.profiles`, so the `INVOKER` version couldn't
    insert the profile row. `handle_updated_at` stays `INVOKER` on purpose (it
    fires on updates the authenticated user is already permitted to make via
    RLS, so no privilege elevation is needed there).
- **New migration** (`supabase/migrations/202608150001_profile_avatars_bucket.sql`)
  — creates the `profile-avatars` storage bucket (32 MB, jpeg/png/webp only)
  plus insert/select/update/delete RLS policies scoped to
  `auth.uid()`, mirroring the `trip-covers` bucket pattern.
- **Test updates** (`test/login_screen_admin_entry_test.dart`,
  `test/responsive_layout_test.dart`) — these tests construct `LoginScreen` /
  `ProfileViewScreen` / `ReactivationScreen` directly, but those screens now
  resolve real `Supabase*` repos through the locator (which touch
  `Supabase.instance.client`, uninitialized in widget tests). Fixed by
  overriding `authControllerProvider` (and `profileControllerProvider` where
  needed) with mock-backed controllers, so the screens never touch the real
  Supabase client.
- **New unit tests** (`test/profile_supabase_mapper_test.dart`,
  `test/supabase_profile_repository_test.dart`,
  `test/supabase_verification_code_repository_test.dart`) — cover the mapper
  (snake↔camel, default fallback for unknown role/status, editable-row column
  exclusion), the profile repository (get/create/update against a mock HTTP
  client), and the verification-code repository (send/validate/re-send against a
  mock HTTP client, including the valid/expired/invalid/locked/not_found →
  `CodeValidationResult` mapping).

### Files touched (Phase 7)

New:
- `lib/data/profile_supabase_mapper.dart`
- `lib/data/supabase_auth_repository.dart`
- `lib/data/supabase_profile_repository.dart`
- `lib/data/supabase_verification_code_repository.dart`
- `lib/data/supabase_account_lifecycle_repository.dart`
- `lib/data/supabase_profile_avatar_storage.dart`
- `supabase/migrations/202608150001_profile_avatars_bucket.sql`
- `test/profile_supabase_mapper_test.dart`
- `test/supabase_profile_repository_test.dart`
- `test/supabase_verification_code_repository_test.dart`

Modified:
- `lib/data/user_management_repository_locator.dart` (mock → real swap, lazy
  getters)
- `supabase/functions/_shared/codes.ts` (`validateCode`/`consumeCode` split)
- `supabase/functions/_shared/email.ts` (denomailer API fix)
- `supabase/functions/verification-send/index.ts` (user + service-role client split)
- `supabase/functions/verification-validate/index.ts` (client split)
- `supabase/functions/verification-resend/index.ts` (client split - later deleted as dead code)
- `supabase/functions/account-deactivate-confirm/index.ts` (client split + `consumeCode`)
- `supabase/functions/account-reactivate-confirm/index.ts` (client split + `consumeCode`)
- `supabase/migrations/202608140001_user_management.sql` (`handle_new_user` → `SECURITY DEFINER`)
- `test/login_screen_admin_entry_test.dart` (mock-auth overrides)
- `test/responsive_layout_test.dart` (mock-auth overrides)

> Note: `google_sign_in` and the iOS URL-scheme / plan-update prep were
> committed separately in `chore(profile): Phase 7 prep` (`2f8b5c9`); this phase
> consumes that setup. No `pubspec.yaml` change in this commit.

### Deviations from plan / bugs found & fixed

- **Locator uses lazy getters, not top-level finals.** The plan's task 4 said
  "swap each `Mock*` for the real `Supabase*` in one line here." A naive
  top-level-`final` swap breaks widget tests (importing the locator file triggers
  `Supabase.instance.client`, which throws without `Supabase.initialize`). Lazy
  getters solve this with zero impact on production call sites.
- **`validateCode` no longer consumes the code.** Phase 6's `validateCode`
  marked `used_at` on a correct code, conflating "validate" with "consume."
  Phase 7's `confirmReactivation` was intended to client-side pre-validate then
  call the confirm function, but the pre-validate call consumed the code and the
  confirm function's *own* server-side `validateCode()` then returned `not_found`
  for a perfectly correct code. Fixed by splitting into a non-destructive
  `validateCode` + explicit `consumeCode`, and by having the client call the
  confirm functions **directly** (no client-side pre-validate) — the confirm
  functions' server-side `validateCode()` is the single source of truth.
- **Edge Functions client split was a real bug, not a refinement.** Phase 6's
  functions used the service-role key but passed the user's JWT as
  `Authorization`, which made PostgREST apply the JWT's `authenticated` role and
  silently defeated the RLS bypass — so `verification_codes` access still failed
  against the deny-all policy. Phase 7 uses a separate service-role client with
  no JWT override for all privileged `verification_codes` / `profiles` writes +
  `auth.admin.signOut()`, and an anon-key+JWT client only for `auth.getUser()`.
- **`handle_new_user` needed `SECURITY DEFINER`.** The Phase 6 `INVOKER`
  version couldn't insert into `profiles` because the `auth.users` trigger fires
  as `supabase_auth_admin` (no grants on `public.profiles`). Corrected to
  `SECURITY DEFINER` with a pinned `search_path`. **Caveat:** this modifies a
  migration already applied by `supabase db push` in Phase 6; redeploy/re-apply
  via `supabase db push` (or `supabase db reset` on dev) to pick up the
  `SECURITY DEFINER` change on the live project.
- **`confirmReactivation` blocks self-service for suspended accounts.** The plan's
  Phase 5 task for this guard lives in the Admin module, but Phase 7's
  `SupabaseAccountLifecycleRepository` enforces it client-side too: it fetches
  the profile and throws `AccountSuspendedException` before calling
  `account-reactivate-confirm`, so a suspended user never burns a code attempt on
  a flow they can't complete.
- **`deny-list` mapping quirk:** `SupabaseVerificationCodeRepository.validateCode`
  intentionally maps every non-`valid`/non-`expired` server result
  (`invalid`/`locked`/`not_found`) to `CodeValidationResult.invalid`. The Dart
  repo interface predates `locked`/`not_found`, and collapsing them into
  `invalid` keeps the UI contract stable; the confirm path surfaces the real
  reason via the `CodeValidationException` message instead.

### Verification

- `flutter analyze` — no issues found.
- New Phase 7 tests (`profile_supabase_mapper_test` 5, `supabase_profile_repository_test`
  4, `supabase_verification_code_repository_test` 5) — all passed (14 tests).
- Modified test regressions (`login_screen_admin_entry_test` 5,
  `responsive_layout_test` ~30, `auth_controller_test` 14) — all passed.
- Manual real-backend verification (per plan Definition of Done): real Google
  sign-in (native ID-token flow) works on the target platform; real OTP emails
  arrive and validate correctly (valid / wrong / expired); deactivating then
  reactivating via a second real Google sign-in + real emailed code works
  end-to-end; the Admin Module Phase 5 suspension guard was confirmed by an
  `AccountSuspendedException` path test.

### Definition of Done

- [x] All mock → real swaps done, mocks kept in the codebase for future
      offline/dev-mode use but no longer wired by default
- [x] Every manual test step from Phases 2–5 re-verified against the real
      backend (Google sign-in, deactivated routing, profile view/edit, OTP
      send/validate/re-send, deactivate→sign-out, reactivate→back in)
- [x] Real Google sign-in works on at least one target platform (native
      ID-token flow)
- [x] Real OTP emails arrive and validate correctly
- [x] Deactivating, then reactivating via a second real Google sign-in + real
      emailed code, works end-to-end


## Phase 8 — Hardening & Handoff (complete)

### What was built
- **`is_active_user()` Postgres function** (`supabase/migrations/202608160001_is_active_user.sql`,
  new) — `SECURITY DEFINER` + `stable`; other modules add `... and is_active_user()` to
  their RLS to block deactivated/suspended users who still hold a valid session
  (Architecture Decision 7).
- **`profiles` UPDATE policy hardened** with `is_active_user()` (defense in depth;
  reactivation is server-side, so the client flow is unaffected).
- **Rate limiting** (`codes.ts` + `verification-send`) —
  `isRateLimited()` blocks a send per user+purpose within `RATE_LIMIT_WINDOW_SECONDS`
  (60s) -> HTTP 429. Complements the `attempt_count` lockout on `validateCode()`
  (which guards *guessing*, not *sending*). Fail-open on a read error.
- **Module README** (`lib/features/auth/README.md`, new).
- **`verify_user_management.sql`** now also asserts `is_active_user` exists.

### Files touched (Phase 8)
New:
- `supabase/migrations/202608160001_is_active_user.sql`
- `lib/features/auth/README.md`

Modified:
- `supabase/tests/verify_user_management.sql` (assert is_active_user)
- `supabase/functions/_shared/codes.ts` (`RATE_LIMIT_WINDOW_SECONDS`, `isRateLimited()`,
  `gt` on `QueryBuilderLike`)
- `supabase/functions/verification-send/index.ts` (rate-limit -> 429)
- `supabase/functions/verification-resend/index.ts` (rate-limit -> 429 - later deleted as dead code)
- `docs/user-management/PROGRESS.md` (this entry)

> These are SQL / TypeScript / Markdown only — **no Dart changed**, so
> `flutter analyze` + `dart test` are unchanged from Phase 7's clean run. The SQL
> needs `supabase db push`; the TS needs `supabase functions deploy`
> (verify/send/resend) + a Deno typecheck to take effect.

### Deviations from plan
- **`is_active_user()` is NOT applied to the `profiles` SELECT policy.** The plan said
  "use it in this module's own RLS policies," but gating SELECT would make
  `AuthController` unable to read a `deactivated`/`suspended` user's own profile right
  after sign-in, collapsing both cases onto `AuthStatus.signedOut` and breaking the
  PB-06 gate. SELECT stays `auth.uid() = user_id`; only UPDATE is gated. Documented in
  the migration header and `lib/features/auth/README.md`.
- **Error handling (task 5) — already satisfied; no Dart change.** Every user-facing
  call is wrapped in try/catch at the controller/screen layer (`AuthController.signInWithGoogle`,
  `CodeEntryScreen._confirm` / `_resend` / `_sendInitialCode`,
  `ProfileController.loadProfile` / `updateDisplayName` / `updateAvatar` / `removeAvatar`).
  No unguarded Supabase/network call can crash the UI. The confirm path's
  `_mapConfirmError` also deliberately rethrows non-400 errors as-is so they aren't
  misreported as "invalid code." The cosmetic gap (raw `PostgrestException.toString()`)
  was deferred to avoid widening scope.
- **FuncReq audit (task 4)** — blocked: `USER_MANAGEMENT_IMPLEMENTATION_PLAN.md`
  references a `FuncReq.md` with checklist 1.1.1–1.3.4, but **no such file exists in the
  repo**. Flagged as a known gap in `lib/features/auth/README.md` -> "Open issues".
- **Auth Hook (task 3, stretch)** — evaluated and **deferred**: a Supabase Auth Hook
  ("Customize Access Token") would reject token issuance for `deactivated`/`suspended`
  users server-side — stronger than the client-side + RLS approach — but adds a Postgres
  function in the token-minting path; deferred for a free-tier agent.

### Verification
- `flutter analyze` / `dart test` — not re-run (no Dart source changed this phase);
  status unchanged from Phase 7 (clean).
- `is_active_user()` — canonical pattern (`security definer` + `stable` + pinned
  `search_path`); the UPDATE gate was checked against the client-side SELECT gate and is
  safe (reactivation is server-side).
- Rate limit — 1-row existence check on `created_at > now() - window`, fail-open; HTTP 429
  with `rate_limited: true`.
- `verify_user_management.sql` now asserts `is_active_user` exists.

### Definition of Done
- [x] `is_active_user()` implemented; applied to this module's own RLS (UPDATE); SELECT
      intentionally left ungated — documented
- [x] Documented + flagged to other module owners in `lib/features/auth/README.md`
      (they adopt `... and is_active_user()` on their own data tables)
- [x] Security pass: timing-safe hash compare (already in `codes.ts`), `attempt_count`
      lockout on validate, and rate-limiting on `verification-send`/`resend`
- [x] Auth Hook evaluated + deferred with rationale
- [x] Error handling audited (no crashes; controller-layer try/catch everywhere)
- [x] `lib/features/auth/README.md` module doc written (incl. "why no
      `LinkedProvider`/`Session` table")
- [x] Final end-to-end `PROGRESS.md` summary + open issues captured

### Open items carried forward
- `FuncReq.md` does not exist — the 1.1.1–1.3.4 requirements traceability can't be
  completed until that doc is added.
- OTP entropy (6 digits ≈ 20 bits) is a known limitation; consider 8 digits / TOTP.
- Auth Hook (server-side token rejection for deactivated users) is deferred.
- `202608160001` migration + the `verification-*` function edits require
  `supabase db push` / `supabase functions deploy` to reach the live project (now deploys 4 functions, not 5).


---

## Phase 9 — Account Deletion (Permanent) (complete)

### What was built

A signed-in user can now permanently delete their account, distinct from the
existing reversible deactivation flow. Deactivation is for "I want to step
away, might come back" (reversible, data intact); deletion is for "I want
this gone" (irreversible, right-to-erasure). Built directly against the real
backend (no mock-first step — Phases 0–8 were already live).

- **`'deletion'` purpose** added to the `VerificationCode` infrastructure:
  - `VerificationPurpose.deletion` enum value (`lib/models/verification_code.dart`).
  - `verification-send` Edge Function now accepts `purpose: "deletion"`.
  - `email.ts` sends a "Your TripJournal account deletion code" subject.
  - Migration `202608200001_account_deletion.sql` adds `'deletion'` to the
    `verification_codes.purpose` check constraint.
- **New Edge Function `account-delete-confirm`**
  (`supabase/functions/account-delete-confirm/index.ts`) — follows the exact
  same two-client pattern as `account-deactivate-confirm` /
  `account-reactivate-confirm`: user-scoped client (anon key + caller JWT)
  for `auth.getUser()` identity verification only; service-role client
  (Authorization left default) for `validateCode`, `auth.admin.deleteUser`,
  and `consumeCode`. The code is only consumed **after** the delete succeeds,
  so a failed delete leaves the code valid for a retry without a resend.
  Deleting the `auth.users` row cascades to `profiles` and
  `verification_codes` automatically (both have `on delete cascade` FKs from
  the Phase 6 migration).
- **Repository methods** — `requestDeletion()` and `deleteAccount(code)` on
  `AccountLifecycleRepository`, implemented in both
  `SupabaseAccountLifecycleRepository` (calls `account-delete-confirm`) and
  `MockAccountLifecycleRepository` (validates the mock code; the controller's
  `signOut()` clears local state).
- **`AuthController`** — `requestDeletion()` and `deleteAccount(code)`. On
  success, `deleteAccount` explicitly calls `signOut()` to clear local app
  state — the local Supabase session now points at a user that no longer
  exists, so we reset proactively rather than relying on a later API call
  failing naturally.
- **`CodeEntryScreen`** — now handles `purpose: deletion`: auto-sends a
  deletion code on open, deletion-specific title/message/icon/button text,
  calls `deleteAccount` on confirm, and pops to root on success.
- **New `DeleteAccountScreen`**
  (`lib/features/auth/screens/delete_account_screen.dart`) — the deletion
  warning/confirmation screen with **real friction**: the user must type
  "DELETE" into a field to unlock the "Send code" button, deliberately more
  resistant than the deactivation flow since this can't be undone. Routes to
  `CodeEntryScreen` with `purpose: deletion`.
- **`ProfileViewScreen`** — added a "Delete Account" button (with explanatory
  caption) below the deactivation button, opening `DeleteAccountScreen`.

### Files touched (Phase 9)

New:
- `supabase/migrations/202608200001_account_deletion.sql`
- `supabase/functions/account-delete-confirm/index.ts`
- `lib/features/auth/screens/delete_account_screen.dart`
- `test/delete_account_screen_test.dart`

Modified:
- `supabase/functions/verification-send/index.ts` (accept `deletion` purpose)
- `supabase/functions/_shared/email.ts` (deletion subject)
- `supabase/config.toml` (register `account-delete-confirm`)
- `lib/models/verification_code.dart` (`VerificationPurpose.deletion`)
- `lib/data/account_lifecycle_repository.dart` (`requestDeletion`/`deleteAccount`)
- `lib/data/supabase_account_lifecycle_repository.dart` (deletion impl)
- `lib/data/mock_account_lifecycle_repository.dart` (deletion impl)
- `lib/features/auth/controller/auth_controller.dart` (`requestDeletion`/`deleteAccount`)
- `lib/features/auth/screens/code_entry_screen.dart` (deletion handling)
- `lib/features/profile/screens/profile_view_screen.dart` (Delete Account button)
- `test/mock_account_lifecycle_repository_test.dart` (3 deletion tests)
- `test/auth_controller_test.dart` (3 deletion tests)
- `test/code_entry_screen_test.dart` (3 deletion tests)
- `docs/user-management/PROGRESS.md` (this entry)

### Deployment (completed 2026-08-20)

- `supabase db push` — applied `202608200001_account_deletion.sql` (and
  `202608190001_journal_entry_location_and_meal_photo.sql`, an un-pushed
  migration from another module).
- `supabase functions deploy account-delete-confirm` — deployed.
- `supabase functions deploy verification-send` — deployed (accepts
  `deletion` purpose).
- `supabase functions deploy verification-validate` — deployed (accepts
  `deletion` purpose; caught during manual review — the initial Phase 9
  pass updated `verification-send` but missed `verification-validate`,
  which would have returned 400 for `purpose: "deletion"`).
- Verified via `supabase projects list` — project `wfuxyatvnztybsaajsfa`
  (TripJournal) is linked and all four deployments succeeded.

### Cross-module risk (flagged to teammates)

Deletion only cascades cleanly if **every** module's tables that reference
`auth.users.id` also specify `on delete cascade` (or an explicit
anonymization strategy) on their own FKs. If Trip/Journal/Health Log don't,
deleting a user could either fail outright or leave orphaned rows. This
module can't fix that unilaterally — same category of cross-module dependency
as the `is_active_user()` flag from Phase 8. **Flag to Trip/Journal/Trip
Recap/Admin module owners.**

### UX improvement: friendly send/resend error messages (post-manual-test)

After manual testing confirmed the deletion flow works, the raw error strings
shown on send/resend failure were replaced with plain-language messages so a
non-technical user gets an honest reason without seeing exception types.

- **`SendCodeException` + `SendCodeFailureKind`** (`lib/data/verification_code_repository.dart`)
  — a domain exception with a `rateLimited` / `serverError` / `networkError` /
  `other` kind, mirroring the existing `CodeValidationException` pattern.
- **`SupabaseVerificationCodeRepository.sendCode()`** now maps:
  - HTTP 429 → `rateLimited`
  - HTTP 5xx → `serverError`
  - `http.ClientException` / `SocketException` / `TimeoutException` → `networkError`
  - anything else → `other`
- **`CodeEntryScreen`** shows a friendly message per kind (applies to send +
  resend, and the generic confirm catch no longer leaks `$e`):
  - rate limited: *"You've requested a code too recently. Please wait about a minute and try again."*
  - server error: *"We couldn't send your code. Please try again in a moment."*
  - network error: *"We couldn't send your code. Please check your connection and try again."*
  - other: *"We couldn't send your code. Please try again."*
  - confirm generic: *"Something went wrong. Please try again."*
- Raw exceptions are still logged via `debugPrint` for debugging.
- **Tests**: 4 new unit tests in `supabase_verification_code_repository_test.dart`
  (429/500/400/network mapping) and 4 new widget tests in
  `code_entry_screen_test.dart` (friendly message per kind). `AuthTestHarness`
  gained an optional `verificationRepository` parameter to inject a throwing mock.

### Post-Phase-9 fix: `last_login_at` was never written (2026-08-23)

**Problem:** `last_login_at` in `public.profiles` was always `NULL`. The
column was defined in the Phase 6 migration and mapped in the Dart code, but
**nothing ever wrote to it** — it was planned for the Phase 10 `record-sign-in`
Edge Function, which was removed due to time constraints.

**Fix:** Stamp `last_login_at` on **every sign-in** (interactive Google
sign-in and passive session restore) in
`ProfileRepository.createProfileIfMissing()`, which is called from both
sign-in paths in `AuthController`:

- `SupabaseProfileRepository.createProfileIfMissing()` — for an existing
  profile, calls `updateProfile(existing.copyWith(lastLoginAt: DateTime.now()))`;
  for a new profile, sets `lastLoginAt: now` at creation.
- `MockProfileRepository.createProfileIfMissing()` — mirrors the same
  behavior so mock-mode and tests behave consistently.

No backend deployment or new Edge Function was needed — `last_login_at` was
already in `profileEditableFieldsToSupabaseRow()`, so `updateProfile` persists
it via RLS-protected direct table access.

**Tests:** updated `supabase_profile_repository_test.dart` (existing-profile
path now issues a PATCH stamping `last_login_at`, no insert) and
`mock_profile_repository_test.dart` (stamps `last_login_at` on an existing
profile). `flutter analyze` clean; full `flutter test` suite passes.

**Note on existing data:** this stamps `last_login_at` going forward. Rows
that are already `NULL` are left as-is (their true last-login time is
unknowable); the next sign-in populates the column.

### Manual test checklist

The automated tests cover the mock/unit layer; these need a real end-to-end
run against the live backend. **Use a throwaway Google account** — this
deletes real data.

1. **Happy path** — Profile → Delete Account → verify the "type DELETE"
   friction field (case-sensitive; `delete` must NOT enable the button) →
   "Send code" → real email arrives with subject "Your TripJournal account
   deletion code" → enter code → confirm → lands on login. Signing back in
   with the same Google account creates a **fresh** account, not a restore.
2. **"Account is gone" state (most important)** — after deleting, verify no
   broken "authenticated but the account is gone" state; restart the app and
   confirm it stays on login (no crash, no stale session).
3. **Wrong / expired code** — wrong 6-digit code → "Incorrect code. Please
   try again."; expired code → "This code has expired…".
4. **Cancel / back** — Cancel on the DELETE screen returns to Profile with no
   side effects; Back on the code-entry screen returns to the DELETE screen.
5. **Cross-module cascade (flag to teammates)** — create a trip + journal
   entry + health log on the test account, delete the account, then query
   `trips` / `journal_entries` / `health_logs` in Supabase for that user ID.
   Gone = cascade works; still present = orphaned rows (or the delete failed)
   — Trip/Journal/Health Log owners need `on delete cascade` on their FKs.
6. **Regression: deactivation + reactivation** — verify the shared
   `CodeEntryScreen` changes didn't break the deactivate → sign out →
   reactivate → back in flow.

### Verification

- `flutter analyze` — no issues found.
- `flutter test` (mock_account_lifecycle_repository 10, auth_controller 17,
  code_entry_screen 9, delete_account_screen 4) — all passed.
- `flutter test test/responsive_layout_test.dart` — all passed (the new
  "Delete Account" button doesn't overflow at any screen size).

### Definition of Done

- [x] `'deletion'` purpose works through send/resend/validate identically to
      the other two purposes
- [x] Confirmation UI has genuine friction (type "DELETE"), visibly distinct
      from the deactivation flow's UI
- [x] `account-delete-confirm` deletes the `auth.users` row; the code is only
      consumed after the delete actually succeeds
- [x] After deletion, the app lands cleanly on the login screen — no broken
      "authenticated but the account is gone" state
- [x] Cross-module cascade risk documented and flagged to teammates

---

## Dead code removal: verification-resend (post-Phase 8)

### What was done

The `verification-resend` Edge Function and all client-side references to it
were removed as dead code. It was never invoked by any code path:

- The app's "Resend code" button (`CodeEntryScreen._resend`) routes through
  `AccountLifecycleRepository.requestReactivation()` / `requestDeactivation()`
  -> `VerificationCodeRepository.sendCode()` -> the `verification-send` Edge
  Function. The `resendCode()` method (on the interface + both
  `Supabase*`/`Mock*` implementations) that would have called
  `verification-resend` was the only consumer, and it was never wired to the
  UI.

### Files changed

- `supabase/config.toml` - removed the `[functions.verification-resend]`
  registration block.
- `supabase/functions/verification-resend/` - directory deleted (was:
  `index.ts` + any bundled deps).
- `lib/data/verification_code_repository.dart` - removed
  `resendCode()` from the interface.
- `lib/data/supabase_verification_code_repository.dart` - removed
  `resendCode()`.
- `lib/data/mock_verification_code_repository.dart` - removed
  `resendCode()`; `sendCode()` already handles resend (invalidates prior
  codes + sends a fresh one), so the mock comment was updated to note resend
  reuses `sendCode()`.
- `test/supabase_verification_code_repository_test.dart` - removed
  `resendCode` test group.
- `test/mock_verification_code_repository_test.dart` - replaced
  `resendCode` test with a `sendCode again (resend)` test.
- `lib/features/auth/README.md` - updated the "Security notes" section to
  reference only `verification-send` (not `verification-send`/`resend`).
- `docs/user-management/PROGRESS.md` - this file; Phase 6/7/8 entries
  annotated with dead-code-removal notes.

### Deployment

- `supabase functions delete verification-resend` - dropped the deployed
  function from the live Supabase project.
- No new function deploy needed (the remaining 4 functions are unchanged by
  this cleanup; their rate-limiting edits from Phase 8 are already live).

### Tests

- Dart: `flutter analyze` + `flutter test` - clean (the `resendCode` method
  was only referenced in the 2 test files that were updated).
