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

### Next phase (Phase 6) should start with

Real backend: enable the Google provider in the Supabase Auth dashboard;
SQL migrations for `Profile` and `VerificationCode`; the `handle_new_user`
trigger; RLS policies; and the privileged Edge Functions
(`verification-send` / `verification-validate` / `verification-resend` /
`account-deactivate-confirm` / `account-reactivate-confirm`).
