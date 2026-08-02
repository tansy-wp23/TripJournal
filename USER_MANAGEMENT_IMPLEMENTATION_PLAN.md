# User Management Module — Agentic Implementation Plan

This plan is written for an AI coding agent (e.g. Claude Code) running on a
free-tier model with a limited context window. It breaks the module into
**9 phases**, each small enough to fit in a single working session. Do not
skip ahead — later phases assume earlier phases are done and merged.

## Scope

Tables owned by this module (from the original ERD): `Profile`,
`LinkedProvider`, `Session`, `VerificationCode`.

**Architecture change from the original ERD — read this before doing
anything else:** `LinkedProvider` and `Session` are **not built as custom
tables**. Google OAuth and session management are handled by **Supabase
Auth** instead of hand-rolled Edge Functions. See "Architecture Decisions"
below for the reasoning. Only `Profile` and `VerificationCode` are real,
custom-built tables in this module.

Out of scope (owned by other modules, only referenced by FK): `Audit_Log`,
`System_Error_Log`, `AI_Processing_Request`, `Trip`, `Journal_Entry`, etc.
Where this module needs to write an audit/error record, stub the call
(e.g. a `TODO(admin-module):` comment + a local log) rather than building
those tables here.

## Architecture Decisions (locked — do not re-litigate mid-implementation)

1. **Supabase Auth handles Google OAuth + sessions.** The Flutter app uses
   `supabase_flutter`'s built-in Google sign-in (`signInWithOAuth` /
   native Google Sign-In), which gives us token verification, JWT
   issuance, refresh, and sign-out for free, correctly implemented. We do
   **not** write our own Google-token verification or session-token
   issuance/hashing code.
2. **`LinkedProvider` is superseded by Supabase's own `auth.identities`**
   (it already records the Google identity linked to a user). We do not
   maintain a duplicate table.
3. **`Session` is superseded by Supabase's own session/JWT/refresh-token
   handling.** We do not maintain a duplicate table. "Terminate session on
   deactivation" (FuncReq 1.2.7) is done via the Supabase Admin API
   (`auth.admin.signOut(userId)`) from a privileged Edge Function/RPC, not
   by revoking a row in our own table.
4. **`Profile` stays custom** — it holds the one thing Supabase Auth
   knows nothing about: `status` (active/deactivated) and any other
   app-specific profile fields. `Profile.userID` is a 1:1 FK to
   `auth.users.id`.
5. **`VerificationCode` stays custom** — Supabase Auth has no concept of
   "email a one-time code to confirm an action." This table and its logic
   are fully hand-built, same as before.
6. **Reactivation flow, restated per your intent:** a user with a
   deactivated account reactivates by **signing in again with the same
   Google account**, then entering a code sent to that same (Google/social)
   email address. There is no separate "enter your email" step — the email
   is whatever Supabase Auth already has on file for that identity.
7. **Deactivated accounts must not get silent access.** Supabase Auth
   itself doesn't know about `Profile.status`, so a deactivated user's
   Google sign-in will succeed at the Supabase Auth layer. The app must
   intercept this itself:
   - **Default approach (built in this plan):** immediately after a
     successful sign-in, the client fetches the `Profile` row. If
     `status = deactivated`, the app does **not** navigate into the app —
     it keeps the (already-valid) Supabase session but shows the
     reactivation/code-entry screen instead. Only after the code is
     confirmed does the app treat the user as logged in and navigate in.
     If the user cancels at this screen, the app explicitly calls
     `signOut()` rather than leaving a live-but-gated session sitting
     around.
   - **This has a cross-cutting consequence for the whole project, not
     just this module:** a deactivated user still holds a technically
     valid Supabase session/JWT. Any other module's RLS policy or Edge
     Function that only checks `auth.uid()` would still let them read/write
     data. Phase 8 adds a shared Postgres check (`is_active_user()`) that
     other modules' RLS policies should also use — **flag this to your
     Trip/Journal/Trip-Recap/Admin module owners**, it's not something this
     module can enforce unilaterally.
   - **Optional hardening (not required to ship, noted in Phase 8):** a
     Supabase Auth Hook (e.g. "Customize Access Token") can reject token
     issuance server-side for deactivated accounts, which is stronger than
     the client-side check above. Left as a Phase 8 stretch item since it
     adds real complexity (Postgres function running inside the auth
     token-minting path) for a free-model agent to get right early.
8. **Mock-first**, same as before: all UI and business logic is built
   first against a repository **interface**, backed by an in-memory mock
   implementation — mirroring the `JournalRepository` pattern in
   `CLAUDE.md`. Real Supabase wiring lands in Phase 6–7.
9. **Google is the only provider for now**, but the interface should not
   hardcode "Google" where a `providerName`/generic OAuth concept will do.

## How the Agent Should Use This Plan

- Work through phases **in order**, one phase per session where possible.
- At the end of every phase, append a short **"Phase N complete"** entry to
  `docs/user-management/PROGRESS.md` (create it in Phase 0) stating: what
  was built, what files were touched, any deviation from this plan and why,
  and what the next phase should do first. This is the handoff note that
  lets a fresh context window resume without re-reading everything.
- Do not proceed to the next phase until the current phase's "Definition of
  Done" checklist is fully checked.
- Keep commits small and scoped to one task group at a time.
- If something in this plan conflicts with what's actually in the repo,
  trust the repo, note the conflict in `PROGRESS.md`, and proceed with the
  more sensible option.

---

## Phase 0 — Recon & Contracts (no feature code)

**Goal:** Know what already exists, and lock the interfaces every later
phase will build against.

**Tasks:**
1. Inspect the repo: is this a fresh Flutter project, or does scaffolding
   (Flutter project, `pubspec.yaml`, Supabase project/config, folder
   structure, other modules' code) already exist? Record findings at the
   top of `docs/user-management/PROGRESS.md`.
2. Confirm/adopt a folder convention. **Match the existing repo layout**
   (see `CLAUDE.md` and the current `lib/` tree — flat `lib/data/` for
   repositories, `lib/models/` for entities, `lib/features/<name>/` for
   screens/widgets/state):
   ```
   lib/models/           # entities: Profile, VerificationCode, AppSession
   lib/data/             # repository interfaces + mock/real implementations + locators
   lib/features/auth/    # auth screens, widgets, state
   lib/features/profile/ # profile screens, widgets, state
   supabase/functions/   # Edge Functions (Phase 6, verification + status transitions only)
   supabase/migrations/  # SQL migrations (Phase 6, Profile + VerificationCode only)
   docs/user-management/PROGRESS.md
   ```
   Mock implementations live in `lib/data/` (e.g. `mock_auth_repository.dart`)
   and real ones in `lib/data/` too (e.g. `supabase_auth_repository.dart`),
   mirroring the existing `mock_journal_repository.dart` /
   `supabase_journal_repository.dart` pattern. A single locator file
   (e.g. `lib/data/user_management_repository_locator.dart`) swaps mock ↔
   real in one line, mirroring `lib/data/repository_locator.dart`.
3. Define the domain entities matching the (revised) ERD exactly:
   - `Profile` (userID, email, display_name, role, status, deactivated_at,
     last_login_at, created_at, updated_at)
   - `VerificationCode` (codeID, code_hash, purpose, attempt_count,
     created_at, expires_at, used_at, userID)
   - A lightweight `AppSession`/`AuthState` concept representing "what
     Supabase Auth currently knows" — this is **not** a table, just an app-
     level model (current user id, current email, isSignedIn) derived from
     the Supabase SDK's auth state stream.
   - No `LinkedProvider` or `Session` entity — see Architecture Decisions.
4. Define repository interfaces (one per aggregate), e.g.:
   - `AuthRepository`: `signInWithGoogle()`, `signOut()`,
     `authStateChanges()` (stream), `currentUserId()`
   - `ProfileRepository`: `getProfile()`, `createProfileIfMissing()`,
     `updateProfile()`
   - `AccountLifecycleRepository`: `requestDeactivation()`,
     `confirmDeactivation(code)`, `requestReactivation()`,
     `confirmReactivation(code)`
   - `VerificationCodeRepository`: `sendCode(purpose)`,
     `validateCode(code)`, `resendCode()`
   These map 1:1 to the Component.md breakdown (Social Login, Session
   Management, Account Creation, etc. become thin wrappers around
   `AuthRepository`/Supabase rather than owning their own storage) — keep
   the component names in code comments for traceability even though the
   underlying persistence changed.
5. Write the custom-auth sequence into `PROGRESS.md` for later reference:
   Google sign-in (Supabase) → fetch/create `Profile` → branch on
   `Profile.status` → active: navigate into app; deactivated: show
   reactivation code-entry screen without navigating in.

**Definition of Done:**
- [ ] `PROGRESS.md` exists with recon notes + architecture summary
- [ ] Folder structure agreed and created
- [ ] `Profile`, `VerificationCode`, and `AppSession` defined; no
      `LinkedProvider`/`Session` entities created
- [ ] All 4 repository interfaces defined, no implementations yet
- [ ] Code compiles (even if unused)

---

## Phase 1 — Mock Repositories

**Goal:** In-memory fakes for all 4 interfaces so UI work in Phases 2–5
never blocks on a backend.

**Tasks:**
1. Implement `MockAuthRepository`: simulates a Google sign-in with a
   configurable result (success / failure / cancelled) and exposes a fake
   `authStateChanges()` stream, so screens can react to sign-in/sign-out
   the same way they would with the real Supabase stream.
2. Implement `MockProfileRepository`: seeded with a configurable profile
   (new user with no profile yet / active / deactivated), supports
   get/create/update with basic validation.
3. Implement `MockVerificationCodeRepository`: generates a fixed/logged
   **6-digit** code (e.g. always `"123456"` in mock mode, printed to
   console), tracks `attempt_count`, expiry via a short configurable
   timer, resend invalidates the previous code.
4. Implement `MockAccountLifecycleRepository`: deactivate/reactivate state
   transitions on the mock profile, calling into the mock verification
   repo.
5. Wire a simple dependency-injection point (e.g. a `Providers`/service
   locator file) so screens depend on the interface and one line swaps
   mock → real later.

**Definition of Done:**
- [ ] All 4 mocks implemented and unit-testable
- [ ] Mock auth repo can simulate: success, failure, cancelled sign-in
- [ ] Mock profile repo can simulate: first-time (no profile → create),
      active, and deactivated states
- [ ] A single config flag/file controls mock vs. real (even though real
      doesn't exist yet)

---

## Phase 2 — Sprint 1: Core Authentication (mock)

Maps to PB-01 through PB-05, PB-08.

**Goal:** A guest can go through the full mock Google sign-in flow, land in
the app, and stay signed in — with deactivated accounts correctly
diverted instead of let in.

**Tasks:**
1. Login screen with a single "Sign in with Google" button (Social Login
   Component UI).
2. Authentication Flow Component: calls `AuthRepository.signInWithGoogle()`.
   On success, calls `ProfileRepository.createProfileIfMissing()` (covers
   PB-03, first-time account creation) then reads the profile and
   branches:
   - `status = active` → redirect into the app (PB-04)
   - `status = deactivated` → route to the reactivation code-entry screen
     (full logic in Phase 4/5; this phase just needs the routing branch to
     exist, backed by the mock)
   On failure/cancelled → error message (PB-05).
3. Session persistence (PB-08): listen to `authStateChanges()` and keep
   the app's navigation/state in sync with it, so a signed-in user stays
   signed in across navigation within the running app — this now reflects
   Supabase's session semantics (mocked in this phase) rather than a
   custom session store.

**Definition of Done:**
- [ ] All 3 mock auth outcomes (success/fail/cancel) are reachable and
      visibly handled in the UI
- [ ] Mock "deactivated" profile correctly routes away from the main app
- [ ] Signed-in state persists across screen navigation
- [ ] Manual test steps documented in `PROGRESS.md`

---

## Phase 3 — Sprint 2a: Logout + Profile (mock)

Maps to PB-09 through PB-12.

**Tasks:**
1. Logout Component: button, calls `AuthRepository.signOut()`, returns to
   login screen (driven by the `authStateChanges()` listener from Phase 2,
   not a manual state clear).
2. Profile view screen: reads from `ProfileRepository.getProfile()`.
3. Profile edit screen + save flow: `updateProfile()`.
4. Validation rules for profile fields (decide what's actually editable —
   likely `display_name`; `email` is owned by Google/Supabase Auth and
   probably shouldn't be independently editable here — decide and note
   the decision in `PROGRESS.md`), with inline error display on invalid
   submission and a cancel option that discards changes.

**Definition of Done:**
- [ ] Logout returns user to login screen
- [ ] Profile view + edit both work against the mock repo
- [ ] Invalid input is rejected with a visible message, valid input saves

---

## Phase 4 — Sprint 2b: Verification Code Component (mock)

Maps to PB-15 through PB-18, plus PB-06 (detection).

**Goal:** Build the shared OTP component standalone, since both
deactivation and reactivation depend on it.

**Tasks:**
1. Code entry screen (reusable 6-digit OTP input widget, takes a `purpose`
   so it can be used for both deactivation and reactivation).
2. Send code / resend code UI + logic against
   `VerificationCodeRepository`.
3. Validate code logic, including wrong-code and expired-code error
   states.
4. Deactivated-account detection (PB-06), completed: in the Phase 2
   routing branch, when `Profile.status = deactivated`, automatically
   trigger `AccountLifecycleRepository.requestReactivation()` (sends a
   code to the account's email) and land on this screen with
   `purpose=reactivation`. Add a cancel action that calls
   `AuthRepository.signOut()` and returns to login (per Architecture
   Decision 7 — don't leave a gated session hanging).

**Definition of Done:**
- [ ] Code entry screen reusable for both purposes
- [ ] Expired code and wrong code both produce correct UI feedback
- [ ] Resend invalidates the prior code (verify via mock state)
- [ ] Deactivated sign-in attempt correctly and automatically routes to
      this screen with a code already sent
- [ ] Cancelling from this screen signs the user out

---

## Phase 5 — Sprint 3: Account Lifecycle (mock)

Maps to PB-13, PB-14, PB-07.

**Tasks:**
1. Account Deactivation Component: entry point from Profile screen →
   confirm identity via the Phase 4 code-entry widget
   (`purpose=deactivation`) → on success, set profile status to
   deactivated → call `AuthRepository.signOut()` (PB-14, ends the
   session) → return to login screen.
2. Account Reactivation Component: this is the tail end of the flow that
   started in Phase 2/4 — on success of code confirmation
   (`purpose=reactivation`), set profile status back to active, then
   **treat the existing (already valid) Supabase session as now fully
   authenticated** and navigate into the app. No second Google sign-in
   is needed, since the session from step 2 of the login flow was never
   torn down — only gated.
3. Cancel option on both flows, returning the user to a safe prior
   screen without side effects (deactivation cancel → back to Profile;
   reactivation cancel → sign out, per Phase 4).

**Definition of Done:**
- [ ] Full deactivate → session ends → back at login, works against mocks
- [ ] Full reactivate (starting from a deactivated sign-in attempt) → ends
      with the user signed in and inside the app, without a second Google
      prompt, works against mocks
- [ ] Both flows are cancellable before confirmation

**Checkpoint:** at this point the entire module works end-to-end against
mocks. This is a good point to demo/review before touching real
infrastructure.

---

## Phase 6 — Real Backend: Supabase Auth Config + Profile/VerificationCode

**Goal:** Stand up the real backend, independent of the Flutter app.

**Tasks:**
1. Enable the Google provider in the Supabase Auth dashboard; configure
   OAuth client ID/secret and redirect URIs for each target platform.
2. SQL migration for `Profile` only: `userID uuid` (FK to
   `auth.users.id`, PK), `email`, `display_name`, `role`, `status`,
   `deactivated_at`, `last_login_at`, `created_at`, `updated_at`.
3. SQL migration for `VerificationCode` only: `codeID`, `code_hash`,
   `purpose`, `attempt_count`, `created_at`, `expires_at`, `used_at`,
   `userID` (FK to `auth.users.id`).
4. A Postgres trigger on `auth.users` insert (`handle_new_user`,
   Supabase's standard pattern) that auto-creates a matching `Profile`
   row with `status = active`. This is the server-side source of truth
   for account creation (PB-03); the client-side
   `createProfileIfMissing()` call from Phase 2 becomes a defensive
   fallback, not the primary mechanism.
5. RLS policies: `Profile` — a user can `select`/`update` only their own
   row (`userID = auth.uid()`); no direct `insert`/`delete` from clients.
   `VerificationCode` — no direct client access at all; only accessible
   via `SECURITY DEFINER` functions/Edge Functions.
6. Edge Functions or Postgres RPC functions (only where privileged logic
   or hashing is needed):
   - `verification-send` / `verification-validate` / `verification-resend`
     — OTP generation (6-digit), hashing (never store plaintext),
     `attempt_count` lockout after a defined threshold, `expires_at`
     check, email sending.
   - `account-deactivate-confirm` — validates the code, sets
     `Profile.status = deactivated`, calls
     `auth.admin.signOut(userId)` (requires service role — this is why it
     must be a privileged function, not a plain RLS-guarded table write).
   - `account-reactivate-confirm` — validates the code, sets
     `Profile.status = active`. (No `signOut` call needed here — the
     session was never revoked per Architecture Decision 7.)
   Plain `Profile` get/update do **not** need Edge Functions — they go
   through RLS-protected direct table access from the Supabase client.

**Definition of Done:**
- [ ] Google provider enabled and working in the Supabase dashboard
- [ ] Migrations for `Profile` and `VerificationCode` run cleanly on a
      fresh Supabase project (no `LinkedProvider`/`Session` tables created)
- [ ] `handle_new_user` trigger confirmed to create a `Profile` row on
      signup
- [ ] RLS confirmed: a user can only read/update their own `Profile`;
      `VerificationCode` is not directly reachable by clients
- [ ] Every privileged function testable independently (curl / Supabase
      CLI invoke) with documented example requests in `PROGRESS.md`
- [ ] No plaintext OTPs stored anywhere server-side

---

## Phase 7 — Real Integration: Swap Mocks for Real

**Goal:** Replace mock repositories with real ones, one at a time, without
touching UI code.

**Tasks:**
1. Add `supabase_flutter` + Google sign-in platform config (Android/iOS
   client IDs, redirect URIs) per Supabase's Flutter OAuth setup.
2. Implement `SupabaseAuthRepository` wrapping `signInWithOAuth`/native
   Google sign-in, `signOut`, and the SDK's `onAuthStateChange` stream.
   Swap the DI binding from Phase 1. Re-run Phase 2's manual test steps
   against the real backend, including the deactivated-account routing
   branch.
3. Implement `SupabaseProfileRepository` using direct RLS-protected table
   access. Swap in, re-run Phase 3's tests.
4. Implement `SupabaseVerificationCodeRepository` +
   `SupabaseAccountLifecycleRepository` calling the Phase 6 functions.
   Swap in, re-run Phase 4 & 5's tests, this time with a real email
   arriving with the OTP (confirm the email-sending integration works).

**Definition of Done:**
- [ ] All mock → real swaps done, mocks kept in the codebase for future
      offline/dev-mode use but no longer wired by default
- [ ] Every manual test step from Phases 2–5 re-verified against the real
      backend
- [ ] Real Google sign-in works on at least one target platform
- [ ] Real OTP emails arrive and validate correctly
- [ ] Deactivating, then reactivating via a second real Google sign-in +
      real emailed code, works end-to-end

---

## Phase 8 — Hardening & Handoff

**Tasks:**
1. Implement the shared `is_active_user()` Postgres check discussed in
   Architecture Decision 7, and use it in this module's own RLS policies.
   Document it clearly in `PROGRESS.md` / the README and **communicate it
   to the other module owners** (Trip Management, Journal, Trip Recap,
   Admin) so their RLS policies/Edge Functions also exclude deactivated
   users — this module cannot enforce that for them.
2. Security pass: OTP length (6 digits) + entropy, timing-safe comparison
   for code hashing, rate limiting on `verification-send`/`resend` (not
   just `attempt_count` on validate).
3. (Stretch, optional) Evaluate a Supabase Auth Hook to reject token
   issuance for deactivated accounts server-side, as a stronger
   alternative/complement to the client-side + RLS approach above.
4. Edge case pass against the functional requirements table (FuncReq.md)
   — go through 1.1.1–1.3.4 one by one and confirm each is actually
   satisfied; note any gaps.
5. Error handling: make sure failures degrade to a user-facing message,
   not a crash, everywhere a network/Supabase call happens.
6. Write a short module README under `lib/features/auth/README.md`
   summarizing the architecture, including the "why no LinkedProvider/
   Session table" decision (useful for teammates who didn't read this
   plan).
7. Final `PROGRESS.md` entry summarizing the whole module status and any
   known open issues or deferred items (e.g. multi-provider support,
   Auth Hook hardening — both explicitly deferred).

**Definition of Done:**
- [ ] Every FuncReq item 1.1.1–1.3.4 checked off with a note on where it's
      implemented
- [ ] `is_active_user()` implemented, used here, and flagged to other
      module owners
- [ ] No plaintext secrets, no missing rate limits
- [ ] README written
- [ ] `PROGRESS.md` finalized

---

## Known Issues

- **OTP auto-advance focus (Phase 2):** The `OtpCodeInput` widget
  (`lib/features/auth/widgets/otp_code_input.dart`) does not automatically
  advance focus to the next digit box after a digit is entered. The
  `KeyboardListener` wrapping each `TextField` holds the `FocusNode`, but
  the `TextField` inside manages its own internal focus — calling
  `requestFocus()` on the `KeyboardListener`'s node does not move the
  `TextField`'s cursor. **Fix in Phase 4:** pass the `FocusNode` to the
  `TextField` directly (or replace `KeyboardListener` with
  `onEditingComplete`/`onSubmitted` on the `TextField`), so auto-advance
  and backspace-to-previous work correctly.

## Traceability Reference

| Sprint Item | Phase |
|---|---|
| PB-01, PB-02, PB-03, PB-04, PB-05, PB-08 | Phase 2 (mock) / Phase 7 (real) |
| PB-09, PB-10, PB-11, PB-12 | Phase 3 (mock) / Phase 7 (real) |
| PB-15, PB-16, PB-17, PB-18, PB-06 | Phase 4 (mock) / Phase 7 (real) |
| PB-13, PB-14, PB-07 | Phase 5 (mock) / Phase 7 (real) |
| Auth config + Profile/VerificationCode schema + functions | Phase 6 |
