# Admin Module — Progress Log

## Phase 0 — Recon & Contracts (complete)

### Recon (2026-08-05)

- Confirmed `lib/models/profile.dart` still defines `UserRole { user, admin }`
  and `AccountStatus` as described in `ADMIN_MODULE_IMPLEMENTATION_PLAN.md` —
  the User Management module hadn't moved it since the plan was written.
- Confirmed `lib/data/profile_repository.dart` (single-caller) and
  `lib/data/account_lifecycle_repository.dart` (self-service, OTP-gated) are
  the User Management module's interfaces this module reads/depends on but
  does not own.

### Open Decisions — resolved with the plan's recommended defaults

No team confirmation round happened before this phase (single-agent
session); the plan's recommended defaults were taken so Phases 0–1 weren't
blocked. **All three should still be confirmed with the team — flagging
here per the plan's own instruction, especially Decision 1 before Phase 2
and Decision 2's cross-module edge was already applied to a shared file.**

1. **Credential mechanism** — **confirmed 2026-08-12** (team decision, not
   just a default): administrators authenticate via the existing
   `AuthRepository.signInWithGoogle()` + a `Profile.role == admin` check.
   No new auth repository is needed. `AdminLoginScreen` is a distinct
   screen/route from the traveler login (different heading, "Admin
   Portal"), but calls the same underlying sign-in method — the role check
   after sign-in is what gates access, not a separate credential store.
   Any user can *attempt* admin sign-in; only a `role == admin` profile
   reaches the dashboard. This must be enforced server-side (RLS via an
   `is_admin_user()` helper, Phase 7) once real backend wiring lands — the
   client-side check in `AdminAuthController` is a UX gate, not the real
   security boundary.

   **Identity model, also confirmed 2026-08-12**: admin accounts are
   **dedicated accounts**, always a separate `Profile` row from any
   traveler account the same person might separately have — never one
   account holding both roles. `Profile.role` stays mutually exclusive
   (`user` XOR `admin`), matching the Phase 1 seed data
   (`admin@tripjournal.dev` is its own row, distinct from the 5 traveler
   profiles). Consequence: **no post-login "choose dashboard" screen is
   needed or should be built** — `AuthGate` (traveler) and `AdminGate`
   (admin) remain two independent, non-overlapping entry points, since no
   single sign-in can ever resolve to both. If this changes later (one
   person needing both a personal travel account and admin rights), that's
   a new cross-module decision requiring `profile.dart` changes coordinated
   with the User Management module owner — not an extension of this
   decision.
2. **`suspended` vs. reusing `deactivated`** — default taken:
   `AccountStatus` gained a third value, `AccountStatus.suspended`
   (`lib/models/profile.dart`, plus a new `Profile.isSuspended` getter).
   This is a **change to a file owned by the User Management module** —
   coordinate with whoever owns it. The actual guard (making
   `AccountLifecycleRepository.confirmReactivation` reject a `suspended`
   profile so self-service reactivation can't undo an admin suspension) is
   **not yet wired** — that's Phase 5's job per the plan. Until Phase 5,
   `suspended` is a valid status value with no enforcement against
   self-service reactivation. **Known gap, tracked here, not silently
   forgotten.**
3. **"Report summaries" in PB-02** — default taken: read as dashboard
   summary statistics, not a content-moderation reports feature. No
   reports/flagging table or field was added anywhere.

### Entities defined (`lib/models/`)

- `AdminAuditLog` (`admin_audit_log.dart`) — `logId`, `adminUserId`,
  `targetUserId`, `action` (`AdminAction { suspend, reactivate }`),
  `reason`, `createdAt`. Includes `fromJson`/`toJson` for the eventual
  Phase 7 Supabase swap.
- `AdminDashboardStats` (`admin_dashboard_stats.dart`) — `totalUsers`,
  `activeUsers`, `suspendedUsers`, `deactivatedUsers`, `adminUsers`,
  `newUsersThisWeek`. No cross-module (trip/journal) fields yet, per the
  plan's guidance to defer those.

### Repository interfaces defined (`lib/data/`, no implementations)

- `AdminDashboardRepository` — `getDashboardStats()`
- `AdminUserDirectoryRepository` — `searchUsers({query})`,
  `getUserById(userId)`
- `AdminAuditLogRepository` — `recordAction(entry)`,
  `getHistoryForUser(userId)`
- `AdminAccountActionsRepository` — `suspendUser(...)`,
  `reactivateUser(...)`

No new `AdminAuthRepository` was added (see Open Decision 1 above) — Phase
2 will add a thin `AdminAuthController` over the existing
`AuthRepository`/`ProfileRepository` if the default credential mechanism
holds.

### Files touched (Phase 0)

- `lib/models/profile.dart` (modified — added `AccountStatus.suspended` +
  `Profile.isSuspended`)
- `lib/models/admin_audit_log.dart` (new)
- `lib/models/admin_dashboard_stats.dart` (new)
- `lib/data/admin_dashboard_repository.dart` (new)
- `lib/data/admin_user_directory_repository.dart` (new)
- `lib/data/admin_audit_log_repository.dart` (new)
- `lib/data/admin_account_actions_repository.dart` (new)
- `docs/admin/PROGRESS.md` (this file)

### Definition of Done

- [x] `docs/admin/PROGRESS.md` created with recon notes + Open Decisions
      1–3 resolved with documented defaults (not a full team sign-off)
- [x] `AdminAuditLog`, `AdminDashboardStats` defined
- [x] `AdminDashboardRepository`, `AdminUserDirectoryRepository`,
      `AdminAuditLogRepository`, `AdminAccountActionsRepository` defined,
      no implementations yet
- [x] Code compiles

---

## Phase 1 — Mock Repositories (complete)

### What was built

In-memory fakes for all 4 repository interfaces, so UI work in Phases 2–6
never blocks on a backend.

- **`MockAdminUserStore`** (`lib/data/mock_admin_user_store.dart`) — a
  shared, mutable seed list of 6 `Profile` rows (1 admin, 5 travelers
  spanning `active`/`suspended`/`deactivated` and a range of `createdAt`
  dates for the "new this week" stat). Shared across the three mocks below
  so a suspend/reactivate action is visible in search results and
  dashboard counts without any extra wiring.
- **`MockAdminUserDirectoryRepository`** — case-insensitive substring match
  on `displayName`/`email`; empty/null query returns everyone.
- **`MockAdminDashboardRepository`** — computes all six
  `AdminDashboardStats` fields by filtering the shared store's current
  state on each call (not cached), so it always reflects the latest
  mutation.
- **`MockAdminAuditLogRepository`** — in-memory list; `getHistoryForUser`
  filters and sorts newest-first. Exposes `nextLogId()` (monotonic counter
  + timestamp, mirroring `MockVerificationCodeRepository`'s `_codeCounter`
  pattern) for callers composing an `AdminAuditLog` before calling
  `recordAction`.
- **`MockAdminAccountActionsRepository`** — `suspendUser`/`reactivateUser`
  mutate the shared store's `Profile.status` and write through to
  `MockAdminAuditLogRepository`. Deliberately does **no** "already
  suspended" / "target is an admin" validation — that's explicitly a Phase
  5 task per the plan, not this phase's job (mirrors how
  `MockAccountLifecycleRepository` also leaves higher-level validation to
  its callers). Throws `StateError` for an unknown `targetUserId`.
- **DI locator** (`lib/data/admin_repository_locator.dart`) — the one place
  the app resolves its admin repositories from, mirroring
  `user_management_repository_locator.dart`. All four wired to mocks,
  sharing one `MockAdminUserStore` instance.

### Files touched (Phase 1)

- `lib/data/mock_admin_user_store.dart` (new)
- `lib/data/mock_admin_user_directory_repository.dart` (new)
- `lib/data/mock_admin_dashboard_repository.dart` (new)
- `lib/data/mock_admin_audit_log_repository.dart` (new)
- `lib/data/mock_admin_account_actions_repository.dart` (new)
- `lib/data/admin_repository_locator.dart` (new)
- `test/mock_admin_user_directory_repository_test.dart` (new)
- `test/mock_admin_dashboard_repository_test.dart` (new)
- `test/mock_admin_audit_log_repository_test.dart` (new)
- `test/mock_admin_account_actions_repository_test.dart` (new)

### Deviations from plan

- None. The shared-store approach the plan suggested ("or a shared
  in-memory store passed to both") was taken directly rather than the
  alternative (independently seeded mocks), since it's what makes Phase
  5's suspend/reactivate actions observable in Phase 3/4's screens during
  manual testing without extra glue code.

### Verification

- `flutter analyze` — see command output in this session; run again after
  any further change before starting Phase 2.
- `flutter test test/mock_admin_*_test.dart` — new tests for all 4 mocks.

### Definition of Done

- [x] All 4 mocks implemented and unit-testable
- [x] Suspending/reactivating a user via the mock is visible in both the
      mock directory list and the mock dashboard stats (shared store,
      verified by test)
- [x] A single locator file (`admin_repository_locator.dart`) controls
      mock vs. real

### Next phase (Phase 2) should start with

Resolve Open Decision 1 (credential mechanism) with the team first — it's
the fork most likely to change what gets built. Then: `AdminLoginScreen`,
`AdminAuthController` (branches on `Profile.role == admin`, exposing
`AdminAuthStatus.unauthorized` for non-admins), and `AdminGate` routing
between login and dashboard. Screens go in `lib/features/admin/`.

---

## Phase 2 — PB-01: Authenticate Administrator (mock) (complete)

### What was built

- **`AdminAuthController`** (`lib/features/admin/controller/admin_auth_controller.dart`,
  `ChangeNotifier`, mirrors `AuthController`) — Google sign-in (mocked) →
  look up the signed-in id's profile → verify `role == UserRole.admin` and
  `isActive`. Exposes `AdminAuthStatus { signedOut, loading, authenticated,
  unauthorized }`. Does **not** auto-provision a profile the way the
  traveler flow's `createProfileIfMissing` does — an admin profile must
  already exist.
- **`AdminLoginScreen`** (`lib/features/admin/screens/admin_login_screen.dart`)
  — distinct screen/route, "Admin Portal" heading, single Google sign-in
  button, surfaces `AdminAuthController.error` the same way `LoginScreen`
  surfaces `AuthController.error`.
- **`AdminDashboardScreen`** (`lib/features/admin/screens/admin_dashboard_screen.dart`)
  — **placeholder only**: welcome text + a working logout button. Phase 3
  replaces the body with the real `AdminDashboardStats` tiles; the logout
  button is a head start on Phase 6, not a claim that Phase 6 is done.
- **`AdminGate`** (`lib/features/admin/admin_gate.dart`) — routes on
  `AdminAuthController.status`; `unauthorized` renders the same
  `AdminLoginScreen` as `signedOut` (no separate "access denied" screen),
  since the screen already surfaces the error regardless of status.
- **Entry point**: **revised mid-phase, 2026-08-12.** First built as a
  visible "Admin Portal" text button on the traveler `LoginScreen` — flagged
  to the team as a low-risk default. Team feedback: a visible admin link
  advertises the admin backend's existence to every traveler, which is
  worth avoiding even though the role check still gates real access.
  Replaced with a **hidden gesture**: tapping the TripJournal logo 3 times
  within 3 seconds (`_adminTapsRequired`, `_adminTapWindow` in
  `login_screen.dart`) opens `AdminGate` via `Navigator.push`. No visible
  admin affordance remains on `LoginScreen`. Chosen over a
  `kDebugMode`-gated button (would vanish in release builds, so a
  release-build demo/test couldn't reach it) and a keyboard shortcut (not
  touch-compatible, so it wouldn't cover mobile testing at all) — the
  tap gesture works identically with mouse clicks and touch taps, in both
  debug and release builds.

### Confirmed decisions (this session, 2026-08-12)

- **Credential mechanism** (Open Decision 1) and **admin identity model**
  (dedicated accounts, no dual-role support, no post-login chooser screen)
  — both confirmed and already recorded above under Phase 0's Open
  Decisions section.

### Deviation from the plan's literal wording

Architecture Decision 2 / Open Decision 1 describe the role check as
reading "the already-fetched profile" without naming which repository
fetches it. `AdminAuthController` uses
`AdminUserDirectoryRepository.getUserById` (this module's own interface,
backed by `MockAdminUserStore`, which seeds an `admin-001` / `role: admin`
row) rather than the User Management module's `ProfileRepository.getProfile`.
Reason: `ProfileRepository`/`MockProfileRepository` model a single fixed
traveler persona (`user-001`, always `role: user`, no `role` constructor
param at all) — a real admin sign-in could never succeed against that mock,
and giving it one would mean editing a file owned by the User Management
module for a need that's already met by an interface this module owns.
No cross-module file was touched for this. Per the plan's own instruction
("if this plan conflicts with what's actually in the repo, trust the repo,
note the conflict, proceed with the more sensible option").

### Mock-only wiring note

`admin_repository_locator.dart` gained `adminAuthRepository` — a **second**
`MockAuthRepository` instance (same class the traveler flow uses, not a new
type), seeded with `admin-001` / `admin@tripjournal.dev` to match
`MockAdminUserStore`'s admin row. This only exists because the mock can
simulate one signed-in persona per instance; real Supabase Auth (Phase 7)
is one shared backend for both flows, so this collapses back to reusing the
single `authRepository` instance then — not a second production auth
system.

### Files touched (Phase 2)

- `lib/features/admin/controller/admin_auth_controller.dart` (new)
- `lib/features/admin/screens/admin_login_screen.dart` (new)
- `lib/features/admin/screens/admin_dashboard_screen.dart` (new, placeholder)
- `lib/features/admin/admin_gate.dart` (new)
- `lib/data/admin_repository_locator.dart` (modified — added `adminAuthRepository`)
- `lib/features/auth/screens/login_screen.dart` (modified — hidden 3-tap
  admin entry gesture on the logo; converted to `StatefulWidget` to hold
  the tap-count/timestamp state; no visible admin affordance)
- `test/admin_auth_controller_test.dart` (new, 9 tests)
- `test/login_screen_admin_entry_test.dart` (new, 4 tests — no visible
  link, 3-tap opens `AdminGate`, 2 taps doesn't, taps outside the 3s
  window don't accumulate)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (559 tests) passes, including the 9
  `AdminAuthController` tests and 4 `LoginScreen` hidden-entry tests; no
  regressions in existing suites.

### Definition of Done

- [x] A `role = admin` profile reaches the dashboard
- [x] A `role = user` profile is rejected with a visible message, not
      routed into the admin dashboard
- [x] Manual test steps documented below

### Manual test steps

1. Launch the app → traveler `LoginScreen` → tap the TripJournal logo 3
   times within 3 seconds → `AdminGate` opens on top, showing
   `AdminLoginScreen`.
2. On `AdminLoginScreen`, tap "Sign in with Google" (mock always resolves
   to `admin-001`, the seeded admin) → lands on the placeholder
   `AdminDashboardScreen`, "Signed in as Admin Account (admin@tripjournal.dev)."
3. Tap the logout icon → returns to `AdminLoginScreen`.
4. To see the rejection path, temporarily change `adminAuthRepository`'s
   seeded id in `admin_repository_locator.dart` to a non-admin row (e.g.
   `user-101`) and re-run → sign-in shows "This Google account is not
   registered as an administrator." and stays on `AdminLoginScreen`.

### Next phase (Phase 3) should start with

`AdminDashboardController` (calls `AdminDashboardRepository.getDashboardStats()`,
loading/error/data states) and replace `AdminDashboardScreen`'s placeholder
body with real `AdminDashboardStats` stat tiles — reuse the `StatTile`
widget pattern from `lib/features/trip/widgets/stat_tile.dart` if it fits,
per the plan.

---

## Phase 3 — PB-02: View Admin Dashboard (mock) (complete)

### What was built

- **`AdminDashboardController`** (`lib/features/admin/controller/admin_dashboard_controller.dart`,
  `ChangeNotifier`) — calls `AdminDashboardRepository.getDashboardStats()`,
  exposes `stats`/`loading`/`error`. Mirrors `TripController`'s plain
  manual loading/error flags convention (not `AsyncNotifier`), for
  consistency with the rest of the app.
- **`AdminDashboardScreen`** (`lib/features/admin/screens/admin_dashboard_screen.dart`)
  — the placeholder body from Phase 2 is now the real dashboard: a 2-column
  `GridView` of `StatTile`s (reused from `lib/features/trip/widgets/stat_tile.dart`,
  as the plan suggested) covering all six `AdminDashboardStats` fields
  (total/active/suspended/deactivated/admin users, new this week). Loading
  shows a spinner; a failed load shows an error message with a "Retry"
  button (`Key('admin-dashboard-retry')`) rather than a blank screen. Load
  is triggered once via `initState` + `addPostFrameCallback`, guarded by an
  in-progress flag — same pattern `HomeScreen` already uses for its own
  dashboard load. The logout button and "Signed in as …" line carried over
  from Phase 2's placeholder unchanged.

### Files touched (Phase 3)

- `lib/features/admin/controller/admin_dashboard_controller.dart` (new)
- `lib/features/admin/screens/admin_dashboard_screen.dart` (modified —
  placeholder body replaced with the real stat grid)
- `test/admin_dashboard_controller_test.dart` (new, 6 tests — initial
  state, successful load matches the default seed, a suspend action on the
  shared store is reflected on the next `loadStats` call, loading flag
  transitions, a failing repository sets `error`/leaves `stats` null,
  retry after failure succeeds and clears the error)
- `test/admin_dashboard_screen_test.dart` (new, 2 tests — stat grid
  renders the seeded counts; full flow: sign in on `AdminLoginScreen` →
  dashboard grid → logout → back to `AdminLoginScreen`)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (567 tests) passes, including the 8 new
  Phase 3 tests; no regressions in existing suites.

### Definition of Done

- [x] Dashboard renders all fields of `AdminDashboardStats` against the mock
- [x] Loading and error states both have visible UI (spinner; error text +
      Retry button), not just a blank screen

### Next phase (Phase 4) should start with

`AdminUserListScreen` (search field over `AdminUserDirectoryRepository.searchUsers()`,
reusing `JournalSearchBar`'s pattern from
`lib/features/trip/widgets/journal_search_bar.dart` if it fits) and
`AdminUserDetailScreen` (full `Profile` detail view via `getUserById`, plus
entry points for Phase 5's suspend/reactivate and audit history). A search
entry point needs to be added to `AdminDashboardScreen` (e.g. an app bar
action or a "Manage Users" tile) — not yet wired anywhere, per the plan.

---

## Post-Phase-3 addition — Unauthorized admin sign-in attempt logging (complete)

### Team decision (2026-08-12)

Question raised: if a non-admin account (accidentally or intentionally)
reaches `AdminLoginScreen` and attempts to sign in, is that recorded
anywhere? As built through Phase 3, the answer was **no** — a rejected
sign-in only set an in-memory error string on `AdminAuthController`;
nothing was persisted.

Team decision: **any non-admin sign-in attempt against the admin portal
must be recorded** so admins can review which accounts have tried, in
order to decide on a warning or penalty action later. **The
warning/penalty mechanism itself is explicitly undecided** — this addition
covers recording and visibility only, no enforcement.

### What was built

- **`AdminAccessAttemptLog`** (`lib/models/admin_access_attempt_log.dart`)
  — `logId`, `attemptedUserId`, `attemptedEmail`, `reason`
  (`AdminAccessAttemptReason { notAnAdmin, noProfileFound,
  adminAccountNotActive }`), `createdAt`. **Deliberately a separate table
  from `AdminAuditLog`**, not folded into it — `AdminAuditLog`'s shape
  (`adminUserId` + `targetUserId` + `AdminAction { suspend, reactivate }`)
  assumes an admin actor acting on a target account; a rejected sign-in has
  no admin actor at all, so it doesn't fit that schema.
- **`AdminAccessAttemptLogRepository`** (interface) +
  **`MockAdminAccessAttemptLogRepository`** (in-memory impl, mirrors
  `MockAdminAuditLogRepository`'s `nextLogId()` pattern) — `recordAttempt`,
  `getRecentAttempts({limit})` (newest first), `getAttemptsForUserId`
  (for a future per-user review once Phase 4/5's user detail screen and a
  warning/penalty mechanism exist).
- **`AdminAuthController`** now takes a third constructor arg
  (`AdminAccessAttemptLogRepository`) and calls it on every rejection
  branch (`notAnAdmin`, `noProfileFound`, `adminAccountNotActive`) — but
  **not** on `AuthException` (cancelled/failed Google sign-in), since no
  account identity was ever established in that case, so there's nothing
  meaningful to attribute the attempt to. The write is best-effort
  (wrapped in its own try/catch, logged via `debugPrint` on failure) so a
  logging problem never overrides the more specific rejection message
  already shown to the user.
- **`AdminDashboardController`** now also loads the 10 most recent
  attempts alongside `AdminDashboardStats` in the same `loadStats()` call
  (one loading/error cycle for both, rather than a second controller).
- **`AdminDashboardScreen`** gained a "Recent unauthorized admin sign-in
  attempts" section below the stat grid — email, rejection reason, and a
  relative timestamp per entry; "No attempts recorded." when empty. This
  is the actual visibility half of the team's ask — recording alone
  wouldn't let an admin "get a hold on" anything.

### Files touched

- `lib/models/admin_access_attempt_log.dart` (new)
- `lib/data/admin_access_attempt_log_repository.dart` (new)
- `lib/data/mock_admin_access_attempt_log_repository.dart` (new)
- `lib/data/admin_repository_locator.dart` (modified — added `adminAccessAttemptLogRepository`)
- `lib/features/admin/controller/admin_auth_controller.dart` (modified —
  third constructor arg, records rejected attempts)
- `lib/features/admin/controller/admin_dashboard_controller.dart`
  (modified — second constructor arg, loads `recentAttempts`)
- `lib/features/admin/screens/admin_dashboard_screen.dart` (modified —
  added the attempts section; grid moved inside a `ListView` to make room)
- `test/admin_auth_controller_test.dart` (modified — third constructor
  arg everywhere; added recording assertions to the three rejection tests;
  added two tests confirming cancelled/failed sign-in do *not* record)
- `test/admin_dashboard_controller_test.dart` (modified — second
  constructor arg everywhere; added a `recentAttempts` test)
- `test/admin_dashboard_screen_test.dart` (modified — added a test for
  the attempts section, using a taller test viewport since `ListView` is
  lazy and won't build off-screen children at the default size)
- `test/mock_admin_access_attempt_log_repository_test.dart` (new, 4 tests)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (573 tests) passes; no regressions.

### Known follow-ups (not built, by design — undecided/out of scope)

- **Warning/penalty mechanism**: not decided by the team yet. Once
  decided, it most likely composes with Phase 5's existing
  `AdminAccountActionsRepository.suspendUser` (an admin reviews an
  account's attempt history and chooses to suspend it manually) rather
  than needing new enforcement machinery — but that's a call for whoever
  designs the mechanism, not assumed here.
- **Per-user attempt history UI**: `getAttemptsForUserId` exists on the
  repository but has no screen calling it yet — natural fit for Phase 4/5's
  `AdminUserDetailScreen` once built, alongside the existing
  `AdminAuditLogRepository.getHistoryForUser` section. **Closed in Phase 4
  below** — `AdminUserDetailScreen` now shows both sections.
- **Rate limiting / repeated-attempt alerting**: not built. The dashboard
  shows recent attempts individually; it doesn't flag e.g. "5 attempts
  from the same account in an hour" as suspicious. Would need explicit
  design if wanted.

---

## Phase 4 — PB-03: Search and View User (mock) (complete)

### What was built

- **`AdminUserManagementController`** (`lib/features/admin/controller/admin_user_management_controller.dart`,
  `ChangeNotifier`, global provider like the other admin controllers) —
  debounces `setQuery` (300ms, mirrors `JournalSearchBar`'s window, but the
  debounce lives in the controller here per the plan's wording rather than
  the search field widget) before calling
  `AdminUserDirectoryRepository.searchUsers()`. Uses a `_searchGeneration`
  counter (mirrors `TripController`'s `_loadGeneration`) so a slower,
  superseded search response can't overwrite a newer one's results.
  `clearQuery()` bypasses the debounce for the search field's "clear"
  action.
- **`AdminUserListScreen`** (`lib/features/admin/screens/admin_user_list_screen.dart`)
  — search field + results list. Empty state
  (`Key('admin-user-search-empty-state')`) distinguishes "no users at all"
  from "no matches for this query" in its message. Tapping a result
  pushes `AdminUserDetailScreen`.
- **`AdminUserDetailController`** (`lib/features/admin/controller/admin_user_detail_controller.dart`,
  `ChangeNotifier`) — loads one user's `Profile` via
  `AdminUserDirectoryRepository.getUserById`, plus their `AdminAuditLog`
  history and `AdminAccessAttemptLog` history (closes the follow-up from
  the post-Phase-3 addition above — this is the per-user view that
  `getAttemptsForUserId` was built for but had no screen calling it yet).
  **Deliberately not a global Riverpod provider** like the other admin
  controllers — this one is per-user, constructed fresh by the screen for
  whichever `userId` it's showing (mirrors how `EntryDetailScreen` looks
  its subject up by id rather than holding shared singleton state). A
  fresh `getUserById` fetch (rather than reusing
  `AdminUserManagementController`'s already-fetched list) is what lets
  Phase 5 call `load()` again to refresh this exact screen after a
  suspend/reactivate action.
- **`AdminUserDetailScreen`** (`lib/features/admin/screens/admin_user_detail_screen.dart`)
  — profile header (avatar-or-initials, name, email, role chip, status
  chip, joined/last-signed-in dates), "Status history" section (audit
  log), "Admin sign-in attempts" section (access-attempt log). A `TODO(admin-module,
  phase-5)` comment marks exactly where the Suspend/Reactivate action
  buttons go — **deliberately not built as stub/disabled buttons**, since
  Phase 5 owns a real product decision (reject double-suspend? reject
  admin-on-admin suspension?) that a fake button would either wrongly
  imply is already handled or need throwing away — see "Deviation from the
  plan" below.
- **`lib/features/admin/admin_format_utils.dart`** (new) — `formatRelativeTime`
  and `accessAttemptReasonLabel` extracted from `AdminDashboardScreen`'s
  original private methods so `AdminUserDetailScreen`'s attempt section
  doesn't duplicate them.
- **Entry point closed**: `AdminDashboardScreen`'s app bar gained a
  "Manage users" action (`Key('admin-manage-users')`) → `AdminUserListScreen`
  — this was the gap Phase 3's `PROGRESS.md` entry flagged as not yet
  wired anywhere.

### Deviation from the plan

The plan's Phase 4 task list says `AdminUserDetailScreen` should include
"entry points to Phase 5's suspend/reactivate actions." Read literally
that could mean visible (if non-functional) buttons now. Built instead as
a `TODO` comment marking the insertion point, with no button in the UI —
reasoning: Phase 5's own Definition of Done treats "validate suspension
request" (reject an already-suspended target, decide whether an admin can
suspend another admin) as a real decision still to be made, not a given.
A visible-but-dead button risks reading as "this works" during manual
testing/demo, and a stub that's later swaped for the real thing is pure
rework. Per the plan's own instruction ("trust the repo, note the
conflict, proceed with the more sensible option") — noted here rather than
silently resolved.

### Files touched (Phase 4)

- `lib/features/admin/admin_format_utils.dart` (new)
- `lib/features/admin/controller/admin_user_management_controller.dart` (new)
- `lib/features/admin/controller/admin_user_detail_controller.dart` (new)
- `lib/features/admin/screens/admin_user_list_screen.dart` (new)
- `lib/features/admin/screens/admin_user_detail_screen.dart` (new)
- `lib/features/admin/screens/admin_dashboard_screen.dart` (modified —
  "Manage users" app bar action; switched to the shared
  `admin_format_utils.dart` helpers instead of its own private copies)
- `test/admin_user_management_controller_test.dart` (new, 10 tests —
  debounce timing, name/email substring match, rapid-typing only searches
  the final query, no-match yields empty not error, `clearQuery` bypasses
  the debounce, failing repository sets error)
- `test/admin_user_detail_controller_test.dart` (new, 8 tests — known/unknown
  user id, audit history scoped to that user, access-attempt history
  scoped to that user, `load()` reflects a status change on refresh)
- `test/admin_user_list_screen_test.dart` (new, 4 tests — loads all users
  on open, search narrows results after the debounce, empty state,
  tap-to-navigate)
- `test/admin_user_detail_screen_test.dart` (new, 6 tests — profile fields
  for a traveler and an admin, empty history states, a recorded audit
  entry renders, a recorded access attempt renders, unknown id shows
  error + retry)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (601 tests) passes, including the 28 new
  Phase 4 tests; no regressions.

### Definition of Done

- [x] Search by partial username or email returns matching seeded users
- [x] Selecting a user shows their full detail view
- [x] Empty search results show a visible empty state, not a blank list

### Next phase (Phase 5) should start with

`SuspendConfirmationDialog` (mirroring `delete_trip_confirmation_dialog.dart`'s
`Future<bool> show...` pattern), then the actual Suspend/Reactivate
buttons at the `TODO` marker in `AdminUserDetailScreen`. After a
successful action, call `AdminUserDetailController.load(userId)` again to
refresh the screen. Also: verify (with a cross-module test, since it
touches the User Management module's code) that
`AccountLifecycleRepository.confirmReactivation` rejects a `suspended`
profile, per Open Decision 2's still-outstanding guard.

### Phase 5 validation decisions — confirmed (2026-08-12)

The three questions the plan flagged as needing a decision before the
Suspend/Reactivate buttons could be built (see Phase 4's "Deviation from
the plan" above):

1. **Admin-on-admin suspension: blocked entirely.** The Suspend action is
   disabled/hidden on `AdminUserDetailScreen` when the viewed profile's
   `role == UserRole.admin`. No confirmation-dialog escape hatch — this is
   a hard block, not a "type to confirm" style extra step. If a compromised
   or misbehaving admin account genuinely needs handling, that's a
   separate, more deliberate flow to design later, not this button.
2. **Double-action (suspend-already-suspended /
   reactivate-already-active): blocked with an error**, not a silent
   no-op. Since the button should already reflect current status, hitting
   this case means something's stale (e.g. two admin sessions racing) —
   worth surfacing to the admin, not swallowing quietly.
3. **Reason: required, free text, presence-only validation.** The
   Suspend confirmation dialog won't submit with an empty reason field,
   but nothing validates the text's content — no policy body or second
   admin reviews it. It's an accountability record for `AdminAuditLog.reason`
   (so a disputed or later-reviewed suspension has *something* explaining
   it), not an approval gate. A fixed reason dropdown was considered and
   rejected for now — free text is simpler and someone would have to
   define that list, which is out of scope here.

---

## Phase 5 — PB-04 + PB-05: Suspend / Reactivate User (mock) (complete)

### What was built

- **`SuspendConfirmationDialog`** (`lib/features/admin/widgets/suspend_confirmation_dialog.dart`)
  — `Future<String?> showSuspendConfirmationDialog(context, {targetDisplayName})`.
  A required reason text field; the Suspend button stays disabled
  (`onPressed: null`) until the trimmed text is non-empty. Returns the
  trimmed reason on confirm, `null` on cancel — since a reason is
  mandatory, `null` unambiguously means "cancelled."
- **`ReactivateConfirmationDialog`** (`lib/features/admin/widgets/reactivate_confirmation_dialog.dart`)
  — `Future<bool> showReactivateConfirmationDialog(context, {targetDisplayName})`,
  mirroring `showDeleteTripConfirmationDialog`'s pattern directly (no
  reason field needed).
- **`AdminUserDetailScreen`** — converted from `StatefulWidget` to
  `ConsumerStatefulWidget` (needs `ref.read(adminAuthControllerProvider)`
  for the acting admin's id). The `TODO` marker from Phase 4 is now a real
  `_AccountActionsSection`:
  - `role == admin` → explanatory text, no button (Phase 5 decision 1).
  - `status == deactivated` → explanatory text, no button — this case
    wasn't explicitly named in the plan, but follows directly from the
    architecture: `AdminAccountActionsRepository.reactivateUser` is
    documented as only for admin-imposed suspensions, not self-service
    deactivation, so surfacing it as a self-service-only path here (rather
    than silently accepting a tap) keeps that boundary visible in the UI,
    not just in a repository doc comment.
  - `status == suspended` → "Reactivate account" button.
  - otherwise (active traveler) → "Suspend account" button.
  - `_suspend`/`_reactivate` repeat the "already suspended" /
    "admin-on-admin" checks as defense-in-depth even though the button
    is already hidden for those cases (Phase 5 decision 2 — reject with a
    message, not a silent no-op, in case the screen's data is stale).
    On success, both call `_controller.load(widget.userId)` to refresh
    the profile/history sections, then a `SnackBar` confirms the action;
    on failure, the repository's error message is shown the same way.
- **Cross-module guard wired** (`docs/admin/PROGRESS.md` Open Decision 2,
  flagged as a known gap since Phase 0): `MockAccountLifecycleRepository.confirmReactivation`
  now checks `profile.isSuspended` and throws a new `AccountSuspendedException`
  (`lib/data/account_lifecycle_repository.dart`) — a valid OTP code no
  longer clears an admin-imposed suspension via the self-service flow.
  `CodeEntryScreen` (User Management module) gained a matching catch
  clause for a clear message ("This account has been suspended by an
  administrator.") instead of falling into its generic
  `'An unexpected error occurred: $e'` fallback. **Cross-module change** —
  three files outside this module's own folders touched:
  `lib/data/account_lifecycle_repository.dart`,
  `lib/data/mock_account_lifecycle_repository.dart`,
  `lib/features/auth/screens/code_entry_screen.dart`. Flagged here per the
  plan's coordination rule, same as Phase 0's `AccountStatus.suspended`
  addition.

### Files touched (Phase 5)

- `lib/features/admin/widgets/suspend_confirmation_dialog.dart` (new)
- `lib/features/admin/widgets/reactivate_confirmation_dialog.dart` (new)
- `lib/features/admin/screens/admin_user_detail_screen.dart` (modified —
  `ConsumerStatefulWidget`, `_AccountActionsSection`, `_suspend`/`_reactivate`)
- `lib/data/account_lifecycle_repository.dart` (modified — `AccountSuspendedException`)
- `lib/data/mock_account_lifecycle_repository.dart` (modified — suspended guard)
- `lib/features/auth/screens/code_entry_screen.dart` (modified — catch clause)
- `test/suspend_confirmation_dialog_test.dart` (new, 4 tests)
- `test/reactivate_confirmation_dialog_test.dart` (new, 2 tests)
- `test/admin_user_detail_screen_test.dart` (modified — added a
  `ProviderContainer`-based sign-in helper and 6 new tests: admin-blocked,
  deactivated-blocked, cancel leaves state unchanged, suspend flow
  end-to-end, reactivate flow end-to-end)
- `test/mock_account_lifecycle_repository_test.dart` (modified — added the
  cross-module "confirmReactivation rejects a suspended profile" test the
  plan's Phase 5 Definition of Done calls for)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (613 tests) passes, including 13 new Phase 5
  tests; no regressions.

### Definition of Done

- [x] Suspend flow: confirm → status updates → audit log entry recorded →
      visible in the audit history section
- [x] Reactivate flow: same, in reverse
- [x] Both actions are cancellable before confirmation with no side effects
- [x] A suspended user cannot self-reactivate via the existing OTP flow
      (cross-module test — `mock_account_lifecycle_repository_test.dart`)

**Checkpoint reached**: Sprint 1 (PB-01 through PB-05, PB-10 not yet
built) works end-to-end against mocks. PB-10 (Logout Administrator) is
Phase 6 — largely already working as a side effect of Phase 2's
`AdminDashboardScreen` logout button, but not yet formally verified
against Phase 6's own Definition of Done.

### Next phase (Phase 6) should start with

Formally verifying PB-10: logout clears `AdminAuthController` state (no
stale profile/session) and returns to `AdminLoginScreen`, driven by
`AdminGate`'s state rather than a manual redirect — this already appears
true from Phase 2's implementation, but Phase 6 should add the explicit
test coverage the plan's Definition of Done calls for, since Phase 2 only
covered it incidentally.

---

## Phase 6 — PB-10: Logout Administrator (mock) (complete)

### What was built

Nothing new — the behavior has existed since Phase 2 as a side effect of
`AdminDashboardScreen`'s app bar logout button (`ref.read(adminAuthControllerProvider.notifier).signOut()`).
This phase is entirely about giving PB-10 the **explicit, named**
verification the plan's Definition of Done calls for, rather than relying
on it being covered incidentally by other phases' tests.

- **Confirmed the logout button is the only way to trigger `signOut()`**
  in the admin feature (`grep` for `signOut`/`admin-logout` across
  `lib/features/admin/`), and that it only exists on
  `AdminDashboardScreen`'s app bar — not on `AdminUserListScreen` or
  `AdminUserDetailScreen`. Consequence: logout can only be tapped while
  `AdminDashboardScreen` is the visible top-of-stack screen, which rules
  out the "stale pushed screen left behind after logout" failure mode
  (an admin can't be on `AdminUserDetailScreen` and tap logout, because
  that button isn't there — they'd have to navigate back to the
  dashboard first, at which point the stack is exactly one level deep
  again). No code change needed for this; confirmed by inspection, not
  assumed.
- **Confirmed "driven by `AdminGate`'s state, not a manual redirect"**:
  the logout `onPressed` handler calls only `signOut()` — no
  `Navigator.pop`/`push` inside it. `AdminGate` reacts to
  `AdminAuthController.status` transitioning to `signedOut` and swaps in
  `AdminLoginScreen` on its own, exactly mirroring how `AuthGate` handles
  the traveler logout (Architecture Decision precedent, not a new
  pattern).
- **New explicit test file**, `test/admin_logout_test.dart`, driven
  through `AdminGate` end-to-end (sign in → dashboard → logout), rather
  than pumping `AdminDashboardScreen` in isolation like Phase 3's test
  did:
  1. Logout returns to `AdminLoginScreen`, `AdminDashboardScreen` no
     longer found in the tree.
  2. Logout clears `AdminAuthController.profile`/`.session`/`.error` to
     null and `.status` to `signedOut` — read directly off a
     `ProviderContainer`, not just inferred from what's on screen.
  3. Signing back in after logout reaches the dashboard again (no lasting
     `signedOut` staleness blocking a fresh sign-in).

### Deliberately not built

- **Cache invalidation for `AdminDashboardController`/`AdminUserManagementController`
  on logout.** Both are global `ChangeNotifierProvider`s (not
  `autoDispose`) — their last-loaded stats/search results stay in memory
  across a logout/re-login cycle. The plan's Definition of Done scopes
  "no stale admin state" to profile/session specifically, which is fully
  satisfied. Given the mock seed has exactly one admin account, there's
  no scenario yet where stale data could leak between *different* admins'
  sessions — revisit if/when Phase 7's real backend makes multi-admin
  sessions on one device a real case.

### Files touched (Phase 6)

- `test/admin_logout_test.dart` (new, 3 tests)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (616 tests) passes, including the 3 new
  Phase 6 tests; no regressions.

### Definition of Done

- [x] Logout returns the admin to `AdminLoginScreen`
- [x] No stale admin state (profile/session) survives the logout

**Sprint 1 complete.** PB-01 through PB-05 and PB-10 all work end-to-end
against mocks, matching the plan's own checkpoint description — a good
point to demo/review before touching real infrastructure. Phase 7 (real
Supabase backend) is out of scope for this sprint; see the plan's Phase 7
outline for what that involves (SQL migration, RLS policies via an
`is_admin_user()` helper, Edge Functions for suspend/reactivate,
swapping `admin_repository_locator.dart` from `Mock*` to `Supabase*`).

---

## Post-Sprint-1 fix — `AuthController` never checked `isSuspended` (complete)

### What prompted this

A question about cross-device behavior surfaced two separate things
worth distinguishing:

1. **No cross-device (or even same-device cross-flow) sync** — expected
   and by design at this stage. `MockAdminUserStore` (admin side) and
   `MockProfileRepository`/`MockAuthRepository` (traveler side,
   hardcoded to a single fixed `user-001` persona) are two entirely
   separate in-memory datasets that don't share ids, let alone data.
   Suspending a seeded admin-side user has no effect on the traveler
   mock right now. This resolves itself once Phase 7 gives both flows
   one real shared Supabase table — no fix needed pre-Phase-7, just
   worth naming so it isn't mistaken for a bug.
2. **A genuine, pre-existing bug, unrelated to mocks vs. real backend**:
   `AuthController.status` (`lib/features/auth/controller/auth_controller.dart`,
   owned by the User Management module) checked `Profile.isDeactivated`
   but never `Profile.isSuspended`. Even once the two mocks above are
   connected — or once Phase 7's real backend makes them the same table
   — a suspended profile would still have fallen through to
   `AuthStatus.authenticated` on sign-in, on any device. This is
   distinct from Phase 5's `confirmReactivation` guard, which only
   protects the *self-service reactivation* path — this gap was in the
   *primary* sign-in path itself.

### What was built

- **`AuthStatus` gained a `suspended` value** (`enum AuthStatus { signedOut,
  loading, authenticated, deactivated, suspended }`), checked *before*
  `isDeactivated` in `AuthController.status` (order doesn't actually
  matter for correctness — `AccountStatus` is a single mutually-exclusive
  field — but suspended is checked first for clarity).
- **`signInWithGoogle()` does *not* auto-request a reactivation code**
  for a suspended profile (unlike deactivated) — sending one would be
  pointless, since Phase 5 already guarantees `confirmReactivation`
  rejects it. No code change was needed here; the existing `if
  (profile.isDeactivated)` check already only fires for that specific
  status.
- **`SuspendedScreen`** (`lib/features/auth/screens/suspended_screen.dart`,
  new) — a distinct screen from `ReactivationScreen`, deliberately
  offering **no OTP entry** (would only walk the user through a
  guaranteed-to-fail code submission). Shows a static explanation and a
  "Sign out" button.
- **`AuthGate`** gained the `AuthStatus.suspended` case, routing to
  `SuspendedScreen`.

### Cross-module footprint

Three files owned by the User Management module were touched:
`auth_controller.dart` (enum + status getter), `auth_gate.dart` (new
case), plus the new `suspended_screen.dart` under that module's own
`lib/features/auth/screens/` folder. Flagged here per this project's
established coordination convention for cross-module changes (same as
Phase 0's `AccountStatus.suspended` addition and Phase 5's
`AccountSuspendedException`).

### Files touched

- `lib/features/auth/controller/auth_controller.dart` (modified)
- `lib/features/auth/auth_gate.dart` (modified)
- `lib/features/auth/screens/suspended_screen.dart` (new)
- `test/auth_controller_test.dart` (modified — 2 new tests: status
  derivation, no auto-reactivation-code for suspended)
- `test/suspended_screen_test.dart` (new, 2 tests — `AuthGate` routes to
  `SuspendedScreen` for a suspended profile; "Sign out" returns to
  `LoginScreen`)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (620 tests) passes; no regressions.

### Still not built (correctly out of scope)

Terminating an *already signed-in* session the moment an admin suspends
that account (rather than only gating the *next* sign-in attempt)
requires the privileged `auth.admin.signOut(userId)` call the plan
already earmarks for `suspendUser`'s real implementation — Phase 7,
service-role Edge Function only. Nothing client-side, mock or real, can
do this; not attempted here.

---

## Phase 7 — Real Backend (complete, built 2026-08-19 alongside Phase 14)

### Context / how this got unblocked

Phase 7 sat as an outline-only "next sprint" placeholder until 2026-08-19,
when this branch (`admin-module`) fast-forward-merged `main`, which had
already picked up the User Management module's own real-backend work
(`USER_MANAGEMENT_IMPLEMENTATION_PLAN.md` Phases 6–8, merged via PRs #7–#9):
the real `profiles`/`verification_codes` tables, RLS, `is_active_user()`,
and `Supabase*` repositories. That's exactly the schema Phase 7 needed to
build against (`Profile.role`, `AccountStatus.suspended` — confirmed
already shipped for real, matching Open Decision 2's recommended default
taken back in Phase 0), so Phase 7 and Phase 14 were both built in the
same session rather than waiting for a separate sprint.

### What was built

- **Migration `202608190001_admin_rbac_and_audit_logs.sql`**:
  - `is_admin_user()` — mirrors `is_active_user()` (same SECURITY DEFINER +
    pinned `search_path` rationale).
  - `profiles_select_admin` — one new, purely additive SELECT policy on
    `public.profiles` (owned by User Management). Does not touch
    `profiles_select_own`/`profiles_update_own`. **Cross-module change**,
    flagged per the plan's coordination rule — team decision 2026-08-19 to
    proceed without a separate review cycle since it's additive-only (see
    `202608190001_admin_rbac_and_audit_logs.sql`'s own header comment).
  - `admin_audit_log` table + RLS (`is_admin_user()`-gated select; insert
    policy is defense-in-depth, not the primary write path — see below).
  - `admin_access_attempt_log` table + RLS. Deliberately **not**
    `is_admin_user()`-gated on insert — the whole point is recording an
    attempt from someone who just failed that exact check, so requiring it
    would make every real attempt unrecordable. Insert policy is instead
    `auth.uid() = attempted_user_id` (a caller can only record an attempt
    about themselves); reads are `is_admin_user()`-scoped.
- **Edge Functions** `admin-suspend-user` / `admin-reactivate-user`
  (`supabase/functions/`, registered in `supabase/config.toml` with
  `verify_jwt = false` — auth is checked manually inside, matching
  `account-deactivate-confirm`'s pattern): two-client architecture
  (anon client for identity only, service-role client for every
  privileged read/write). `admin-suspend-user` also calls
  `auth.admin.signOut(targetUserId)` (Architecture Decision 4 — the
  reason this is a privileged function and not a plain RLS-guarded table
  write) and re-checks "target is admin" / "target already suspended"
  server-side as defense-in-depth against stale client state (Phase 5's
  own validation decisions, now enforced on both ends).
- **Real repositories** (`lib/data/`): `SupabaseAdminUserDirectoryRepository`,
  `SupabaseAdminDashboardRepository` (computes stats client-side over a
  minimal-column fetch, per Phase 0's "keep to fields a mock can trivially
  compute" guidance — no server-side aggregate query), `SupabaseAdminAuditLogRepository`,
  `SupabaseAdminAccountActionsRepository` (calls the two Edge Functions;
  `adminUserId` param accepted for interface parity but not sent — the
  Edge Function derives the acting admin from the caller's own JWT),
  `SupabaseAdminAccessAttemptLogRepository`.
- **`admin_repository_locator.dart` swapped** to lazy getters resolving
  the real repositories (mirrors `user_management_repository_locator.dart`'s
  Phase 7 shape). `adminAuthRepository` now reuses
  `user_management_repository_locator.dart`'s `authRepository` directly
  (Architecture Decision 2) rather than a separate instance — the mock
  locator used a separate `MockAuthRepository` only because a mock can
  simulate exactly one signed-in persona per instance; the real Supabase
  Auth backend is one shared service for both flows.

### The test-architecture gap this surfaced (and how it was closed)

Every admin widget test that pumped a screen via a bare `ProviderScope`
(or an un-overridden `ProviderContainer`) was implicitly relying on the
locator's globals resolving to mocks. Swapping to real Supabase broke
that silently — not a compile error, a runtime "you must initialize the
Supabase instance" crash the moment any admin provider was first read.
Two shapes of this problem, two different fixes:

1. **Screens whose controller comes from a top-level Riverpod provider**
   (`AdminDashboardScreen`, `AdminUserListScreen`, `AdminIssueReportListScreen`,
   `AuditLogScreen`, `AdminGate`/`AdminLoginScreen`) — fixed with
   **`AdminTestHarness`** (`test/support/admin_test_harness.dart`),
   mirroring `AuthTestHarness`: a shared `MockAdminUserStore` + mock
   repositories, five controllers built from them, and a `.wrap(widget)`
   helper that overrides all five providers in one `ProviderScope`. All
   directly-affected test files were migrated to it:
   `admin_dashboard_screen_test.dart`, `admin_user_list_screen_test.dart`,
   `admin_issue_report_list_screen_test.dart`, `admin_logout_test.dart`,
   `report_issue_button_test.dart` (constructor-injection only — it's a
   plain `StatelessWidget`, no provider), `responsive_layout_test.dart`
   (new `_appWithMockAdmin` helper alongside its existing
   `_appWithMockAuth`), and `login_screen_admin_entry_test.dart`'s one
   test that reaches `AdminGate` (merged the traveler-side
   `AuthTestHarness` override with `AdminTestHarness.overrides` in a
   single `ProviderScope`, since that's the only test in the file that
   crosses into admin providers at all).
2. **`AdminUserDetailScreen` / `IssueReportDetailScreen`** — these were
   already a known exception (Phase 4/10's own doc comments): their
   controllers are constructed locally per-instance, not resolved from a
   provider, because they need an instance parameter (`userId`/`reportId`)
   a plain global provider can't carry. No provider means no override
   seam. Fixed with **test-only constructor-injection params**
   (`controller`, `accountActionsRepository` /
   `issueReportRepositoryOverride`) — the same pattern `ReportIssueButton`
   already used for `userIdProvider`. `admin_user_detail_screen_test.dart`
   and `issue_report_detail_screen_test.dart` (which pump these screens
   directly) inject harness-backed controllers this way.
3. **Internal navigation *into* those two screens from elsewhere**
   (tapping a dashboard access-attempt, a user-list row, an issue-report
   tile, or an audit-log entry) is a third shape neither fix above
   reaches: the *pushed* screen's constructor is called by production
   code inside another screen's tap handler, not by the test. Closed by
   adding a **test-only builder-function parameter** to the four
   navigating screens (`AdminDashboardScreen.userDetailScreenBuilder`,
   `AdminUserListScreen.userDetailScreenBuilder`,
   `AdminIssueReportListScreen.detailScreenBuilder`,
   `AuditLogScreen.userDetailScreenBuilder` +
   `.issueDetailScreenBuilder`) — `Widget Function(String id)?`, defaulting
   to the real screen construction, letting a test hand the pushed screen
   a harness-backed controller the same way the two fixes above already
   do. The five tests this affected (`admin_dashboard_screen_test.dart`,
   `admin_user_list_screen_test.dart`, `admin_issue_report_list_screen_test.dart`,
   and two in `audit_log_screen_test.dart`) now assert on the pushed
   screen's actual loaded content again, not just that navigation happened.

### Deferred / not built

- `SystemHealthScreen`'s eventual "database connectivity status" (Sprint
  3, Open Decision 7) — unrelated to this work, still N/A until built.
- Real automatic screenshot upload for issue reports (Sprint 2 Open
  Decision 5) — `ReportIssueButton` still stores the picked photo's local
  device path directly, same as mock mode; the `issue-report-attachments`
  storage bucket (Phase 14 migration) exists and is RLS-ready but nothing
  uploads to it yet. Flagged as a known gap, not attempted here — wiring
  actual upload is separate scope from "swap the mocks for real reads/writes."

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (941 tests) passes.

---

# Sprint 2 — Issue Management & Audit Monitoring

## Phase 8 — Recon & Contracts (complete)

### Open Decisions 4–6 — confirmed 2026-08-12 (team decision)

1. **Issue-report submission belongs to this module's scope** — not
   deferred elsewhere. Without it, PB-07's list has nothing to show; see
   `ADMIN_MODULE_IMPLEMENTATION_PLAN.md` Sprint 2 for the full reasoning
   (this was the resolution to a bigger question raised first: Sprint 2's
   original backlog table assumed peer-to-peer content moderation, which
   doesn't fit TripJournal — no user can see another user's content to
   report it. The team's revised Sprint 2/3 tables replaced that with issue
   management, which does fit).
2. **`AdminAuditLog` generalized** rather than given a second parallel
   table: `targetUserId: String` → `targetType: AdminAuditTargetType {
   user, issueReport }` + `targetId: String`; `AdminAction` gains
   `issueMarkInProgress`, `issueMarkResolved`, `issueReopen`. Continues
   Sprint 1's Architecture Decision 5 (one generic audit table) rather than
   Sprint 1's own precedent for *not* forcing a bad fit
   (`AdminAccessAttemptLog` stayed separate because it had no admin actor
   at all) — the issue-status case is different: it *does* have an admin
   actor acting on a target, it's just a different kind of target, which a
   generalized `targetType` handles cleanly.
3. **Administrator remarks on an issue report are optional**, unlike
   Sprint 1's suspend reason (required). The reasoning for suspend's
   required reason was specific to account-suspension accountability, not
   a general "always require text" rule — resolving an issue doesn't carry
   the same weight.

### What was built

- **`AdminAuditLog` migration** (`lib/models/admin_audit_log.dart`) — the
  shape change above. This is a **refactor of Sprint 1's shipped code**,
  not purely additive:
  - `AdminAuditLogRepository`/`MockAdminAuditLogRepository`:
    `getHistoryForUser(userId)` renamed `getHistoryForTarget({targetType,
    targetId})`; new `getAllEntries({targetTypeFilter, actionFilter,
    startDate, endDate})` added for Phase 13 (PB-10). Deliberately plain
    `DateTime` bounds, not `package:flutter/material.dart`'s
    `DateTimeRange` — `lib/data/` has no Flutter UI dependency anywhere
    else and shouldn't gain one here.
  - `MockAdminAccountActionsRepository`'s `suspendUser`/`reactivateUser`
    updated to pass `targetType: AdminAuditTargetType.user`.
  - `AdminUserDetailController.load` updated to call `getHistoryForTarget`.
  - `AdminUserDetailScreen`'s `_AuditLogTile` switch on `AdminAction` made
    exhaustive for the 3 new values (labels/icons added; unreachable from
    that screen in practice, since it only ever loads `targetType: user`
    history, but Dart requires exhaustiveness regardless).
  - `AdminAccessAttemptLog`'s doc comment (explaining why it's a separate
    table from `AdminAuditLog`) updated to describe the new shape instead
    of the stale Sprint-1-only one.
- **`IssueReport`** (`lib/models/issue_report.dart`) — `reportId,
  submittedByUserId, page, description, screenshotUrl (String?), status
  (IssueReportStatus: open, inProgress, resolved), adminRemarks (String?),
  createdAt, updatedAt`.
- **`IssueReportRepository`** (`lib/data/issue_report_repository.dart`, no
  implementation yet) — `submitReport(...)` (not admin-gated — any
  signed-in user can call it), `getAllReports({statusFilter})`,
  `getReportById(reportId)`, `updateStatus({adminUserId, reportId, status,
  remarks})` (composition: update report + write `AdminAuditLog`, mirroring
  `AdminAccountActionsRepository`'s pattern).

### Files touched (Phase 8)

- `lib/models/admin_audit_log.dart` (modified — generalized)
- `lib/data/admin_audit_log_repository.dart` (modified — renamed/added methods)
- `lib/data/mock_admin_audit_log_repository.dart` (modified — implements the above)
- `lib/data/mock_admin_account_actions_repository.dart` (modified — call sites)
- `lib/features/admin/controller/admin_user_detail_controller.dart` (modified — call site)
- `lib/features/admin/screens/admin_user_detail_screen.dart` (modified — exhaustive switch)
- `lib/models/admin_access_attempt_log.dart` (modified — doc comment only)
- `lib/models/issue_report.dart` (new)
- `lib/data/issue_report_repository.dart` (new)
- `test/mock_admin_audit_log_repository_test.dart` (rewritten for the
  generalized API — 14 tests, including 5 new for `getAllEntries`)
- `test/mock_admin_account_actions_repository_test.dart` (modified — call sites)
- `test/admin_user_detail_controller_test.dart` (modified — call sites)
- `test/admin_user_detail_screen_test.dart` (modified — call site)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (626 tests) passes; the generalization
  changed no observable behavior for any Sprint 1 test (renamed API, same
  guarantees), and no other module's tests were affected.

### Definition of Done

- [x] `AdminAuditLog` generalized; all Sprint 1 call sites updated;
      existing Sprint 1 tests still pass (renamed API, same guarantees)
- [x] `IssueReport`, `IssueReportRepository` defined
- [x] `AdminAuditLogRepository.getAllEntries` defined
- [x] Code compiles, `flutter analyze` clean

### Next phase (Phase 9) should start with

`MockIssueReportRepository` — in-memory list seeded with 3–5 sample reports
spanning all three statuses, mirroring `MockAdminUserStore`'s seeding
approach. Wire into `admin_repository_locator.dart`. Sprint 1's mocks
(`MockAdminAuditLogRepository` etc.) already updated in Phase 8, not
Phase 9's job to revisit.

---

## Post-Phase-8 redesign — AdminDashboardScreen stat cards made interactive (complete)

### What prompted this

Team feedback (2026-08-12): the dashboard's 6 stat tiles looked like icons
but did nothing when tapped — not "more organised" and not "user friendly".

### What was built

- **`AdminUserManagementController`** gained a status/role/"new this week"
  filter (`setFilter`, `clearFilter`, `hasActiveFilter`), layered on top of
  the existing text search client-side — `AdminUserDirectoryRepository.searchUsers`
  wasn't touched, since it only ever needed a text query.
- **`AdminUserListScreen`** now takes an optional `title` +
  `initialStatusFilter`/`initialRoleFilter`/`initialNewThisWeek`, applies
  it on load, and shows a dismissible filter chip
  (`Key('admin-user-filter-chip')`) so the active filter is visible and
  clearable, not a silent dead end. Empty state message is now
  filter-aware ("No users match this filter." vs. the existing query/
  no-users messages).
- **`AdminDashboardScreen`** redesigned:
  - The 6 stats are now `_DashboardStatCard`s (`Card` + `InkWell`,
    mirroring `HomeScreen`'s trip-card pattern) instead of read-only
    `StatTile`s — each tap opens `AdminUserListScreen` pre-filtered to
    that subset (Total users → unfiltered; Active/Suspended/Deactivated →
    status filter; Admins → role filter; New this week → recency filter).
  - Content reorganized under explicit "Overview" and "Recent Activity"
    headers instead of one undifferentiated list.
  - The shared `StatTile` widget (`lib/features/trip/widgets/stat_tile.dart`)
    is no longer used on this screen — it's read-only by design and was
    never meant to carry tap affordance; bending it to a second purpose
    would have made it worse for its original use (the trip wellness row).
    A dedicated `_DashboardStatCard` was added instead.

### Files touched

- `lib/features/admin/controller/admin_user_management_controller.dart` (modified — filter support)
- `lib/features/admin/screens/admin_user_list_screen.dart` (modified — title/initial filters/chip/empty state)
- `lib/features/admin/screens/admin_dashboard_screen.dart` (modified — tappable cards, sections)
- `test/admin_user_management_controller_test.dart` (modified — 6 new filter tests)
- `test/admin_user_list_screen_test.dart` (modified — 5 new tests: initial status/role filter, no-chip-when-unfiltered, chip delete clears filter, filter-specific empty state)
- `test/admin_dashboard_screen_test.dart` (modified — 4 new tests: tapping Suspended/Admins/New-this-week/Total-users cards navigates with the right filter applied)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (641 tests) passes; all pre-existing
  dashboard/user-list tests passed unmodified (widget keys preserved),
  confirming the redesign didn't silently change unrelated behavior.

---

## Phase 9 — Mock Repositories (Sprint 2) (complete)

### What was built

- **`MockIssueReportRepository`** (`lib/data/mock_issue_report_repository.dart`)
  — in-memory list seeded with 4 sample `IssueReport`s spanning all three
  `IssueReportStatus` values (`open` ×2, `inProgress` ×1, `resolved` ×1)
  across two `page` values (`TripViewScreen`, `HomeScreen`), mirroring
  `MockAdminUserStore`'s `daysAgo`-based seeding pattern. `submitReport`
  appends a new `open` report with a monotonic-counter id (mirrors
  `MockAdminAuditLogRepository.nextLogId()`'s pattern, renamed
  `_nextReportId`). `getAllReports`/`getReportById` are plain reads,
  newest-first for the list. `updateStatus` is a composition, per
  Architecture Decision 8: mutates the report's `status`/`adminRemarks`/
  `updatedAt`, then writes through to the shared
  `MockAdminAuditLogRepository` with `targetType: issueReport`. Each of the
  three target statuses maps 1:1 to one of the three issue-specific
  `AdminAction` values added in Phase 8 (`open → issueReopen`, `inProgress
  → issueMarkInProgress`, `resolved → issueMarkResolved`) — the mapping
  only needs the *target* status, not the report's previous one, since
  Phase 8 added those three actions in exact correspondence with the three
  statuses. A `null` `remarks` argument **preserves** the report's existing
  remarks rather than clearing them (not explicitly specified by the plan;
  chosen because Sprint 2 Open Decision 6 makes remarks optional per call,
  and clearing on omission would let an accidental blank submission erase
  a previous admin's notes).
- **`MockAdminAuditLogRepository`** — already updated for the generalized
  `getHistoryForTarget`/`getAllEntries` shape in Phase 8; nothing further
  needed here, per Phase 8's own "next phase" note.
- **Locator** (`lib/data/admin_repository_locator.dart`) — added
  `issueReportRepository`, wired to `MockIssueReportRepository` sharing the
  same `MockAdminAuditLogRepository` instance `adminAccountActionsRepository`
  already writes to, so a suspend/reactivate entry and an issue-status entry
  both land in one place for Phase 13's global audit view.

### Files touched (Phase 9)

- `lib/data/mock_issue_report_repository.dart` (new)
- `lib/data/admin_repository_locator.dart` (modified — added
  `issueReportRepository`)
- `test/mock_issue_report_repository_test.dart` (new, 10 tests — seed
  spans all three statuses, newest-first ordering, status-filtered read,
  `getReportById` hit/miss, `submitReport` appends an `open` report,
  `updateStatus` updates fields + records the matching audit entry, a
  `null` remarks argument preserves existing remarks, each target status
  maps to its own `AdminAction`, unknown report id throws)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (651 tests) passes, including the 10 new
  Phase 9 tests; no regressions.

### Definition of Done

- [x] `MockIssueReportRepository` implemented and unit-testable
- [x] `MockAdminAuditLogRepository`'s existing (Sprint 1) tests still pass
      against the generalized shape (unchanged this phase — already true
      since Phase 8)
- [x] Locator wires the new mock; still the one place mock vs. real is
      decided

### Next phase (Phase 10) should start with

`ReportIssueButton` (`lib/features/admin/widgets/`) — description field +
optional `image_picker` attachment, per Sprint 2 Open Decision 5 — placed
on a small, representative set of non-admin screens (e.g. `HomeScreen`,
`TripViewScreen`; cross-module touches, flag them here same as Sprint 1's
`login_screen.dart` edit). Then `AdminIssueReportListScreen` +
`IssueReportManagementController` (status badges, empty state, mirroring
`AdminUserListScreen`'s precedent) with an entry point on
`AdminDashboardScreen`'s app bar.

---

## Phase 10 — PB-06 (added) + PB-07: Submit + View Issue Reports (mock) (complete)

### What was built

- **`ReportIssueButton`** (`lib/features/admin/widgets/report_issue_button.dart`)
  — a plain `StatelessWidget` (not `Consumer*`) that opens a modal bottom
  sheet form: a required description field + an optional photo attachment.
  Photo picking mirrors `ProfileEditScreen._pickAvatar`'s camera-vs-gallery
  bottom sheet exactly, per Sprint 2 Open Decision 5 (an existing photo via
  `image_picker`, not literal screen-capture). The picked file's local
  device path is stored directly as `screenshotUrl` — mirrors
  `CreateEditEntryScreen`'s journal-photo handling; unlike
  `ProfileAvatarStorage`/`TripCoverStorage`, there is no upload step for
  issue-report photos yet in mock mode. Submits via
  `issueReportRepository.submitReport(...)` called directly from the
  form's own local state (no dedicated controller for the write) —
  mirrors `AdminUserDetailScreen`'s Suspend/Reactivate buttons, which call
  `adminAccountActionsRepository` directly rather than through a
  `ChangeNotifier`, since Phase 4/5 already established that precedent for
  a one-shot write action backed by its own loading/error local state.
  Resolves the current user id the same way the screens it's placed on
  already do: `(userIdProvider ?? currentUserIdProvider).requireUserId()`
  (`lib/data/trip_repository_locator.dart`'s shared instance, not
  `AuthController.currentUserId` — reusing the identity source the host
  screens already resolve with, rather than introducing a second one that
  could diverge in mock mode). `userIdProvider` is an optional constructor
  override, mirroring `HomeScreen`/`TripViewScreen`'s own
  `CurrentUserIdProvider?` parameter, for the same test-injection reason.
- **Cross-module placements** (flagged per the plan's coordination
  convention, same as Sprint 1's `login_screen.dart` edit): `ReportIssueButton`
  added to `HomeScreen`'s app bar (`page: 'HomeScreen'`) and
  `TripViewScreen`'s app bar (`page: 'TripViewScreen'`) — 2 of the "small,
  representative set" the plan calls for, enough to prove the flow works
  end-to-end without instrumenting every screen.
- **`IssueReportManagementController`** (`lib/features/admin/controller/issue_report_management_controller.dart`)
  — loads via `IssueReportRepository.getAllReports`, exposing
  loading/error/data, plus an optional `IssueReportStatus?` filter applied
  server-side (the repository call itself takes `statusFilter`, unlike
  `AdminUserManagementController`'s client-side filter layered on top of a
  text search — PB-07 never asked for a text search over reports).
- **`AdminIssueReportListScreen`** (`lib/features/admin/screens/admin_issue_report_list_screen.dart`)
  — a row of `ChoiceChip`s (All + one per `IssueReportStatus`) instead of
  `AdminUserListScreen`'s dismissible single-filter `Chip`, since a report
  list has exactly one filter dimension with mutually exclusive values
  (choosing one always replaces the last), rather than several independent
  filters that can combine. Each tile shows a status icon/color, the
  report's `page`, and a relative timestamp (`formatRelativeTime`, reused
  from `admin_format_utils.dart`). Empty state
  (`Key('admin-issue-list-empty-state')`) distinguishes "no reports at
  all" from "no reports match this status", matching
  `AdminUserListScreen`'s precedent. Loading/error states mirror
  `AdminUserListScreen`'s spinner + error-with-retry pattern exactly.
  Added `issueReportStatusLabel` to `admin_format_utils.dart` (shared
  between this screen and Phase 11's future detail screen, so the two
  can't drift on wording).
- **Entry point**: `AdminDashboardScreen`'s app bar gained an "Issue
  reports" action (`Key('admin-issue-reports')`), next to "Manage users",
  mirroring that action's precedent exactly.
- **`MockIssueReportRepository`/`admin_repository_locator.dart`**:
  unchanged this phase — Phase 9 already wired them; Phase 10 only
  consumes them.

### Deviation from the plan

Task 3 says the list screen should have "tap to open detail (Phase 11)".
`IssueReportDetailScreen` doesn't exist yet — Phase 11 is the next phase,
not this one. Rather than either (a) wiring a `Navigator.push` to a
screen that doesn't exist (compile error) or (b) building a throwaway
placeholder detail screen now that Phase 11 would need to replace, each
`_ReportTile` has a `TODO(admin-module, phase-11)` marking exactly where
the push goes, and no `onTap` at all (so the tile shows no tap ripple,
rather than a tap that silently does nothing). Same reasoning Phase 4
already applied to the not-yet-built Suspend/Reactivate buttons — see
Phase 4's "Deviation from the plan" above — except here there's no open
product decision blocking Phase 11 (the detail screen's fields are fully
specified by Phase 8/the plan already); it's purely phase sequencing, not
an undecided design question.

### Files touched (Phase 10)

- `lib/features/admin/widgets/report_issue_button.dart` (new)
- `lib/features/admin/controller/issue_report_management_controller.dart` (new)
- `lib/features/admin/screens/admin_issue_report_list_screen.dart` (new)
- `lib/features/admin/admin_format_utils.dart` (modified — added
  `issueReportStatusLabel`)
- `lib/features/admin/screens/admin_dashboard_screen.dart` (modified —
  "Issue reports" app bar action)
- `lib/features/home/home_screen.dart` (modified, **cross-module** —
  `ReportIssueButton` in the app bar)
- `lib/features/trip/trip_view_screen.dart` (modified, **cross-module** —
  `ReportIssueButton` in the app bar)
- `test/issue_report_management_controller_test.dart` (new, 7 tests)
- `test/admin_issue_report_list_screen_test.dart` (new, 6 tests — seeded
  reports render, status-chip filtering narrows and restores, empty state
  for zero reports, filter-specific empty state, failing-repository retry)
- `test/report_issue_button_test.dart` (new, 5 tests — opens the form,
  empty description blocked, cancel submits nothing, a filled-in
  description submits and is visible via the repository, an
  unauthenticated `userIdProvider` blocks submission with a visible error)
- `test/admin_dashboard_screen_test.dart` (modified — 1 new test: tapping
  "Issue reports" opens `AdminIssueReportListScreen`)

### Verification

- `flutter analyze` — no issues found (the one `TODO` lint on `_ReportTile`
  is informational, not a warning/error).
- `flutter test` — full suite (670 tests) passes, including the 19 new
  Phase 10 tests; no regressions.

### Definition of Done

- [x] Submitting a report from a traveler-facing screen creates an
      `IssueReport` an admin can see (verified both directly against the
      repository in `report_issue_button_test.dart` and, structurally, by
      `AdminIssueReportListScreen` reading from the same repository)
- [x] The list shows status per report
- [x] Empty state has visible UI, not a blank list

### Next phase (Phase 11) should start with

`IssueReportDetailScreen` (`lib/features/admin/screens/`) — full report
view (page/module, description, attached photo if any, submitting user's
`displayName`/`email` via `AdminUserDirectoryRepository.getUserById`,
submission timestamp), wired up as the `_ReportTile.onTap` this phase left
as a `TODO`. An unknown/deleted report id should show an error state with
retry, mirroring `AdminUserDetailScreen`'s precedent.

---

## Phase 11 + Phase 12 — PB-08: View Issue Details + PB-09: Update Issue Status (mock) (complete)

Built together in one session (team decision, 2026-08-12) rather than
sequentially — the team asked mid-Phase-10 how status updates should work
("add a resolve button, or edit the database directly?"); the answer
(status-change buttons calling the existing composed `updateStatus`, never
manual DB edits) meant `IssueReportDetailScreen` and its status control
were designed as one screen from the start, so building Phase 11's read
view and Phase 12's write control as two separate passes would have meant
reopening the same file immediately after closing it. The plan's phase
split (read screen first, write control second) still describes the
underlying task breakdown accurately — this just collapses the *build*
step, not the design.

### What was built

- **`IssueReportDetailController`** (`lib/features/admin/controller/issue_report_detail_controller.dart`)
  — loads one `IssueReport` by id, the submitter's `Profile` (via
  `AdminUserDirectoryRepository.getUserById` — reusing Sprint 1's lookup
  rather than duplicating one, per the plan's Phase 11 task 1), and status
  history (`AdminAuditLog`, `targetType: issueReport`). Read-only, same
  split as `AdminUserDetailController`/`AdminUserDetailScreen`: the
  controller loads, the screen calls `issueReportRepository.updateStatus`
  directly for the write (PB-09) and then calls `load` again to refresh —
  mirrors how Suspend/Reactivate work on `AdminUserDetailScreen`, not a
  second controller-level write path. Deliberately **not** a global
  `ChangeNotifierProvider`, same reasoning as `AdminUserDetailController`
  — per-report, constructed fresh by the screen.
- **`IssueReportDetailScreen`** (`lib/features/admin/screens/issue_report_detail_screen.dart`)
  — status chip + page, description, an attached photo via `PhotoThumbnail`
  (reused from the Journal module — same local-file-path rendering
  `CreateEditEntryScreen`'s photos already use, cross-module reuse in the
  same spirit as Sprint 1 reusing `stat_tile.dart`) when `screenshotUrl` is
  set, submitter's `displayName`/`email` (or an explicit "unknown user"
  message if the submitting account no longer resolves — a distinct case
  from the report itself failing to load), submission timestamp. Loading/
  error+retry mirrors `AdminUserDetailScreen` exactly
  (`Key('admin-issue-detail-retry')`/`Key('admin-issue-detail-content')`).
  **Status control** (`_StatusControl`, answering the team's question):
  three explicit buttons (Open/In Progress/Resolved), not a single
  "Resolve" button — an admin needs to walk a report *backward* too (e.g.
  reopen one mistakenly marked resolved), and `AdminAction` already models
  all three transitions, not just a forward-only resolve. The button
  matching the report's *current* status renders disabled
  (`FilledButton`, no `onPressed`) rather than hidden, so all three options
  stay visible; the other two are tappable `OutlinedButton`s
  (`Key('admin-issue-set-status-<name>')`). A persistent "Admin remarks"
  text field (optional, per Sprint 2 Open Decision 6) sits above the
  buttons — its current text is sent with whichever status button is
  tapped, seeded once from `report.adminRemarks` on first load only (not
  re-synced on every reload, so a just-submitted value isn't clobbered).
  Tapping a button calls `issueReportRepository.updateStatus(...)` →
  `_controller.load(reportId)` → confirmation snackbar, exactly mirroring
  Sprint 1's suspend/reactivate UX, per the plan's task 2. Defense-in-depth
  repeats the "already this status" check in `_updateStatus` even though
  the matching button is already disabled — same pattern Phase 5 used for
  suspend/reactivate.
- **Shared audit-tile formatting extracted**: `adminActionLabel`/
  `adminActionIcon` moved from `AdminUserDetailScreen`'s private
  `_AuditLogTile` switch into `admin_format_utils.dart` (pure refactor, no
  behavior change — `admin_user_detail_screen_test.dart` still passes
  unmodified) so this screen's own status-history tiles don't duplicate
  the switch. `admin_format_utils.dart` gained a `package:flutter/material.dart`
  import for `IconData`/`Icons` as a result — still a pure-Dart-value
  utils file, just one whose values now include Flutter icon constants.
- **`AdminIssueReportListScreen`**: the Phase 10 `TODO` closed —
  `_ReportTile.onTap` now pushes `IssueReportDetailScreen(reportId: ...)`.

### Files touched (Phase 11 + 12)

- `lib/features/admin/controller/issue_report_detail_controller.dart` (new)
- `lib/features/admin/screens/issue_report_detail_screen.dart` (new)
- `lib/features/admin/admin_format_utils.dart` (modified — added
  `adminActionLabel`/`adminActionIcon`)
- `lib/features/admin/screens/admin_user_detail_screen.dart` (modified —
  `_AuditLogTile` now calls the shared helpers instead of its own switch)
- `lib/features/admin/screens/admin_issue_report_list_screen.dart`
  (modified — `_ReportTile.onTap` wired to `IssueReportDetailScreen`)
- `test/issue_report_detail_controller_test.dart` (new, 9 tests — known/
  unknown report id, submitter lookup found/unresolvable, status history
  scoped to that report and to `targetType: issueReport` specifically,
  `load()` reflects a status change on refresh)
- `test/issue_report_detail_screen_test.dart` (new, 10 tests — report
  fields render, unknown-submitter message, photo thumbnail shown/hidden,
  empty and populated status-history states, unknown report id shows
  error+retry, the current-status button is disabled, selecting a new
  status updates/records/confirms, reopening a resolved report records
  `issueReopen`)
- `test/admin_issue_report_list_screen_test.dart` (modified — 1 new test:
  tapping a report opens `IssueReportDetailScreen`)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (690 tests) passes, including the 20 new
  tests from this combined phase; no regressions, and
  `admin_user_detail_screen_test.dart`'s existing tests pass unmodified
  against the refactored `_AuditLogTile`.

### Definition of Done

- [x] Tapping a report in Phase 10's list opens this screen with every
      field populated
- [x] An unknown/deleted report id shows an error state with retry, not a
      crash
- [x] Status change persists and is reflected immediately in the detail
      view and Phase 10's list (same shared `issueReportRepository`
      instance backs both)
- [x] An audit entry is recorded and independently verifiable via
      `AdminAuditLogRepository`

### Next phase (Phase 13) should start with

`AuditLogScreen` — a **global** view (every admin, every target type),
distinct from this phase's per-report status-history section, using
`AdminAuditLogRepository.getAllEntries({filters})` (already defined since
Phase 8). Filtering by target type, action, and date range at minimum.
Entry point on `AdminDashboardScreen`'s app bar, alongside "Manage users"
and "Issue reports".

---

## Post-Phase-12 addition — leaving `Resolved` now requires a confirmed remark (complete)

### What prompted this

Team discussion (2026-08-12) proposed requiring a remark specifically for
**Resolved → In Progress**. Considered and generalized before building:
singling out that one target status would have left **Resolved → Open**
(arguably the bigger "undo" — a full reopen, not a partial one) still a
silent one-tap action with no explanation, which is the more inconsistent
outcome. Rule built instead: **any transition that leaves `Resolved`**
(to either `open` or `inProgress`) requires a confirmed remark. Every other
transition (the routine `Open → In Progress → Resolved` forward flow, plus
Sprint 2 Open Decision 6's "remarks are optional" default) is unchanged.
This mirrors Sprint 1's `SuspendConfirmationDialog` precedent — undoing a
completed decision gets the same accountability bar as suspending an
account — rather than Sprint 2's general "issue remarks don't carry that
weight" default, which still holds everywhere else.

### What was built

- **`showLeavingResolvedRemarkDialog`** (`lib/features/admin/widgets/leaving_resolved_remark_dialog.dart`)
  — `Future<String?> showLeavingResolvedRemarkDialog(context, {required
  targetStatusLabel, initialRemarks = ''})`, structurally mirroring
  `showSuspendConfirmationDialog`: a required text field, confirm button
  disabled until non-empty, returns the trimmed remark on confirm or `null`
  on cancel. Pre-fills from whatever's already typed in
  `IssueReportDetailScreen`'s persistent remarks field, so an admin who
  already explained themselves there isn't forced to retype it — but a
  blank field still won't confirm.
- **`IssueReportDetailScreen._updateStatus`** — when `report.status ==
  IssueReportStatus.resolved` and the target status differs, awaits the
  dialog before calling `updateStatus`; a `null` result (cancelled) returns
  early with no repository call and no `_updatingStatus` spinner shown (the
  wait is on a user decision, not a network call). A confirmed remark both
  becomes the write's `remarks` value and is written back into the
  persistent field, so the two stay in sync. Every other transition is
  untouched — same optional-remarks behavior as before this addition.

### Files touched

- `lib/features/admin/widgets/leaving_resolved_remark_dialog.dart` (new)
- `lib/features/admin/screens/issue_report_detail_screen.dart` (modified —
  `_updateStatus` branches on `report.status == resolved`)
- `test/leaving_resolved_remark_dialog_test.dart` (new, 5 tests — confirm
  disabled until non-blank, whitespace-only doesn't enable it, cancel
  resolves to `null`, confirm resolves to the trimmed remark, pre-fill from
  `initialRemarks`)
- `test/issue_report_detail_screen_test.dart` (modified — the existing
  "reopening a resolved report" test now drives the dialog instead of
  expecting an immediate status change; added 3 tests: cancelling leaves
  the report status unchanged, Resolved → In Progress also requires the
  dialog, and forward transitions still show no dialog while a confirmed
  remark carries forward to pre-fill the next leaving-`Resolved` dialog)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (698 tests) passes, including the 8 new/
  modified tests from this addition; no regressions.

---

## Phase 13 — PB-10 (Sprint 2): Monitor Audit Log (mock) (complete)

### What was built

- **`AuditLogController`** (`lib/features/admin/controller/audit_log_controller.dart`,
  `ChangeNotifier`, global provider) — calls
  `AdminAuditLogRepository.getAllEntries({filters})` (defined since Phase 8,
  never called by anything until now), exposing loading/error/data plus
  four independent filters: `targetTypeFilter`, `actionFilter`, and a
  `startDate`/`endDate` window. Mirrors `IssueReportManagementController`'s
  plain manual loading/error convention. `setTargetTypeFilter` also drops
  the current action filter if it no longer applies to the new target type
  (e.g. switching to "User" while "Marked Resolved" was selected) — a
  combination that could never match anything otherwise silently returning
  zero results instead of surfacing that the two filters conflict.
- **`actionsForTargetType`** (same file) — which `AdminAction` values are
  meaningful for a given target-type filter (`user` → suspend/reactivate;
  `issueReport` → the three issue actions; `null` → all five). Shared
  between the controller (to drop a stale action filter) and the screen (to
  populate the action dropdown's choices) so the two can't drift.
- **`AuditLogScreen`** (`lib/features/admin/screens/audit_log_screen.dart`)
  — the **global** view distinct from `AdminUserDetailScreen`'s and
  `IssueReportDetailScreen`'s per-target "Status history" sections (both
  still backed by `getHistoryForTarget`, unchanged). Filter row: target-type
  `ChoiceChip`s (All/User/Issue Report, mirroring
  `AdminIssueReportListScreen`'s status chips), an action `DropdownButtonFormField`
  scoped to the current target-type filter via `actionsForTargetType`, and a
  date-range button opening `showDateRangePicker` (plain `DateTime`s in the
  controller/repository layer per Phase 8's own note; the picker is the only
  place this screen touches `DateTimeRange`). An app-bar "Clear filters"
  icon appears only when `hasActiveFilter` is true. Each entry renders via
  `adminActionIcon`/`adminActionLabel` (reused from `admin_format_utils.dart`,
  unchanged since Phase 11) plus a new `adminAuditTargetTypeLabel` helper —
  the first screen that ever shows entries spanning more than one target
  type at once, so it's the first to need that label. Loading/error+retry/
  empty-state pattern mirrors `AdminIssueReportListScreen` exactly, with a
  filter-aware empty message ("match these filters" vs. "have been recorded
  yet").
- **Entry point**: `AdminDashboardScreen`'s app bar gained an "Audit log"
  action (`Key('admin-audit-log')`), next to "Manage users" and "Issue
  reports", mirroring those actions' precedent exactly.

### Deliberately not built

- **Resolving `adminUserId`/`targetId` to a display name.** Every row shows
  the raw id (`by admin admin-001`, `User user-101`) rather than looking up
  and showing `displayName`. Unlike `IssueReportDetailScreen`'s single
  submitter lookup, this list can show many different admins and targets
  across two different repositories per page — batch-resolving all of them
  would add real complexity (multiple repository round-trips, a name cache)
  for a mock-data screen with one seeded admin account. Natural follow-up
  once Phase 14's real backend makes a joined query the natural way to get
  this rather than N client-side lookups.
- **Pagination / infinite scroll.** `getAllEntries` returns everything
  matching the filters in one call; fine for mock data volumes, would need
  revisiting against a real table with real admin activity history.

### Files touched (Phase 13)

- `lib/features/admin/controller/audit_log_controller.dart` (new)
- `lib/features/admin/screens/audit_log_screen.dart` (new)
- `lib/features/admin/admin_format_utils.dart` (modified — added
  `adminAuditTargetTypeLabel`)
- `lib/features/admin/screens/admin_dashboard_screen.dart` (modified —
  "Audit log" app bar action)
- `test/audit_log_controller_test.dart` (new, 13 tests — initial state,
  load populates newest-first, each filter narrows independently, switching
  target type drops a now-irrelevant action filter, `clearFilters` resets
  everything, loading flag transitions, a failing repository sets error,
  retry after failure succeeds, `actionsForTargetType`'s three cases)
- `test/audit_log_screen_test.dart` (new, 8 tests — entries from both
  target types render, a recorded reason renders, target-type chip
  narrows/restores, clear-filters action appears only when a filter is
  active and resets it, empty states for zero entries and for a filter
  matching nobody, failing-repository retry)
- `test/admin_dashboard_screen_test.dart` (modified — 1 new test: tapping
  "Audit log" opens `AuditLogScreen`)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (720 tests) passes, including the 22 new
  tests from this phase; no regressions.

### Definition of Done

- [x] Every audit entry from both Sprint 1 (suspend/reactivate) and Sprint
      2 (issue status changes) appears in one place (verified — entries of
      both target types render together in `audit_log_screen_test.dart`)
- [x] At least one filter dimension demonstrably narrows the results
      (verified for all three dimensions — target type, action, and date
      range — in `audit_log_controller_test.dart`; target type additionally
      covered end-to-end through the screen)

**Sprint 2 complete.** PB-06 through PB-10 (Sprint 2's reused id) all work
end-to-end against mocks. Phase 14 (real Supabase backend for Sprint 2) is
out of scope here — see `ADMIN_MODULE_IMPLEMENTATION_PLAN.md`'s Phase 14
outline (SQL migration for `issue_reports` and the generalized
`admin_audit_log` shape, a storage bucket for attachments, RLS, and
swapping `admin_repository_locator.dart` from `Mock*` to `Supabase*`).

---

## Post-Phase-13 improvement — audit log entries navigate to their target (complete)

### What prompted this

A post-Phase-13 review pass (2026-08-12) looked for improvements beyond the
plan's checklist. Highest value-for-effort finding: `AuditLogScreen`'s
entries showed `targetType`/`targetId` as inert text — an admin spotting
something worth following up on (e.g. "Suspended user-101 — 3 weeks ago")
had no way to get from that entry to the actual user or report without
leaving the screen and searching by name/status elsewhere, which the entry
itself doesn't even show.

### What was built

- **`_AuditLogEntryTile`** (`audit_log_screen.dart`) is now tappable —
  `entry.targetType` selects `AdminUserDetailScreen(userId: entry.targetId)`
  or `IssueReportDetailScreen(reportId: entry.targetId)`, the same two
  screens `AdminUserListScreen`/`AdminIssueReportListScreen` already open.
  No new screen was needed. Both destinations already handle an
  unresolvable id with an error+retry state (Phase 4/Phase 11), so routing
  a possibly-stale historical entry into them required no new handling —
  confirmed by a dedicated test rather than assumed.
- A `Key('admin-audit-entry-<logId>')` was added to each tile (previously
  unkeyed) so individual entries are independently addressable in tests,
  and a trailing chevron signals the new tap affordance, mirroring
  `_DashboardStatCard`'s pattern for the same purpose.

### Files touched

- `lib/features/admin/screens/audit_log_screen.dart` (modified —
  `_AuditLogEntryTile` gained `_openTarget`/`onTap`/key/chevron)
- `test/audit_log_screen_test.dart` (modified — 3 new tests: a user-target
  entry opens `AdminUserDetailScreen` for that user, an issue-report-target
  entry opens `IssueReportDetailScreen`, and an entry whose target no
  longer resolves shows that destination screen's own error state rather
  than crashing)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (723 tests) passes, including the 3 new
  tests; no regressions.

---

## Post-Phase-13 improvement — raw ids resolved to display names; access attempts made actionable (complete)

### What prompted this

Continuing the post-Phase-13 review: two more findings from that pass.
Raw ids (`admin-001`, `user-101`) shown as-is on `AuditLogScreen` aren't
meaningful to an admin scanning history; and the dashboard's "Recent
unauthorized admin sign-in attempts" section (post-Phase-3 addition) was
still purely passive — no path from "I see this suspicious account" to
"I'll review or suspend it," even though the team's original stated intent
for building it was exactly that review-then-decide loop.

### What was built

**Name resolution (`AuditLogController`)** — now takes two more
dependencies, `AdminUserDirectoryRepository` and `IssueReportRepository`,
alongside `AdminAuditLogRepository`. After each `load()`, `_resolveLabels()`
collects the *unique* ids across the loaded entries (every `adminUserId`,
every `user`-type `targetId`, every `issueReport`-type `targetId`) and
batch-resolves each once via `getUserById`/`getReportById`, caching results
in `_userCache`/`_reportCache` (keyed by id; a cached `null` means "looked
up, unresolvable" — distinct from "not yet looked up" — so a since-deleted
account/report isn't re-fetched on every subsequent load). Exposes
`adminLabel(adminUserId)` and `targetLabel(entry)`, both falling back to the
raw id if the lookup came back null — same "degrade, don't blank out"
principle as the tap-through improvement. A report has no "display name" the
way a `Profile` does, so `targetLabel` for an `issueReport` target shows the
report's `description` instead. The resolution step is wrapped in its own
try/catch so a naming-lookup failure can't block the audit log's own
entries from displaying — verified by a dedicated test. `AuditLogScreen`'s
subtitle line now reads e.g. `"User: Alice Tan · by Admin Account"` instead
of `"User user-101 · by admin admin-001"`.

**Actionable access attempts (`AdminDashboardScreen._AccessAttemptTile`)**
— `AdminAccessAttemptLog.attemptedUserId` is always the id Auth returned
for the signed-in account (sign-in itself succeeded; only the role check
failed), but a `Profile` only exists for it when the rejection reason isn't
`noProfileFound`. The tile is now tappable **only** when
`reason != noProfileFound` — for `notAnAdmin`/`adminAccountNotActive` it
navigates to `AdminUserDetailScreen(userId: attempt.attemptedUserId)`,
closing the loop back to Suspend/the account's own status. For
`noProfileFound` there's genuinely nothing to navigate to (no chevron, no
`onTap`) — a known-in-advance dead end, not left to the destination
screen's error state the way the audit log's since-deleted targets are,
since here it's knowable before the tap rather than something that could
go stale later. The section's caption text was updated to describe this
("Tap an entry with a matching account to review it").

### Files touched

- `lib/features/admin/controller/audit_log_controller.dart` (modified —
  two new constructor dependencies, `_userCache`/`_reportCache`,
  `adminLabel`/`targetLabel`, `_resolveLabels`)
- `lib/features/admin/screens/audit_log_screen.dart` (modified —
  `_AuditLogEntryTile` takes the controller and uses the resolved labels)
- `lib/features/admin/screens/admin_dashboard_screen.dart` (modified —
  `_AccessAttemptTile` gains conditional `onTap`/key/chevron; caption text
  updated)
- `test/audit_log_controller_test.dart` (modified — a `buildController`
  helper wires the two new mock dependencies for every existing test; 6 new
  tests under "label resolution": admin/target resolve to real seeded
  names, both fall back to the raw id when unresolvable, and a failing
  naming lookup doesn't block entries from loading)
- `test/audit_log_screen_test.dart` (modified — same `buildController`
  helper; existing tests otherwise unchanged since none asserted on the
  old raw-id subtitle text)
- `test/admin_dashboard_screen_test.dart` (modified — 2 new tests: a
  matching-profile attempt navigates to `AdminUserDetailScreen`; a
  `noProfileFound` attempt's tile has no `onTap`/`trailing`)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (731 tests) passes, including the 8 new
  tests from this addition; no regressions.

---

## Post-Phase-13 improvement — ReportIssueButton discard guard + autofocus (complete)

### What prompted this

A review pass on `ReportIssueButton` specifically (2026-08-12): it had no
guard against silently losing a typed-out report. `CreateEditEntryScreen`
already has a "Discard changes?" prompt for exactly this situation
(`IMPLEMENTATION_PLAN_UX_POLISH.md` §6) — this form had no equivalent,
despite the same kind of loss being possible (a filled-out bug report,
gone on one accidental tap).

### What was built

- **`showModalBottomSheet`'s default silent-dismiss paths were disabled**
  (`isDismissible: false`, `enableDrag: false`) — both scrim-tap and
  drag-to-dismiss call `Navigator.pop` directly, which bypasses `PopScope`
  entirely (it only intercepts *system*-initiated pop attempts, not
  explicit calls app or framework code makes) — so leaving them enabled
  would have meant the new guard could still be silently routed around.
- **`_hasContent`** (`_descriptionController.text.trim().isNotEmpty ||
  _pickedPhoto != null`) mirrors `CreateEditEntryScreen`'s `_dirty` flag —
  gates the prompt so a pristine, untouched form still closes silently, no
  nagging.
- **`PopScope(canPop: !_hasContent, onPopInvokedWithResult:
  _handleBackAttempt)`** wraps the form, exactly mirroring
  `CreateEditEntryScreen`'s own `PopScope` usage — catches the system back
  gesture.
- **The Cancel button** now routes through `_handleCancelTap` (confirm only
  if `_hasContent`) instead of calling `Navigator.pop` directly — it's an
  explicit call too, so without this change it would have silently bypassed
  the guard the same way scrim-tap/drag would have.
- **`_confirmDiscard()`** — "Discard this report?" / "Your description and
  photo will be lost.", "Keep editing" vs. "Discard", directly mirroring
  `CreateEditEntryScreen._confirmDiscard`'s shape and copy style.
- **Description field gained `onChanged: (_) => setState(() {})`** — needed
  only so `_hasContent`'s derived `PopScope.canPop` value stays current as
  the user types (the field's own displayed text doesn't need `setState`,
  `TextEditingController` already handles that) — without it, `canPop`
  would freeze at whatever it was on the sheet's first build.
- **`autofocus: true`** added to the description field, matching
  `SuspendConfirmationDialog`'s reason field precedent — the keyboard now
  opens immediately when the sheet appears instead of requiring an extra
  tap.
- A successful **Submit** still closes without any prompt regardless of
  `_hasContent` — its `Navigator.pop(context)` call is explicit, same as
  Cancel's used to be, so it was never subject to `PopScope.canPop` in the
  first place; no change was needed there.

### Files touched

- `lib/features/admin/widgets/report_issue_button.dart` (modified)
- `test/report_issue_button_test.dart` (modified — the old single "cancel
  closes the form" test split into 5: pristine-cancel closes silently,
  dirty-cancel prompts, "Keep editing" preserves the typed text, "Discard"
  closes without submitting, and the system back gesture — driven via
  `Navigator.maybePop` rather than `tester.pageBack()`, since a bottom
  sheet has no app-bar back button for that helper to find — triggers the
  same prompt)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (735 tests) passes, including the 4 net-new
  tests from this addition; no regressions.

---

## Phase 14 — Real Backend (Sprint 2) (complete, built 2026-08-19 alongside Phase 7)

Built in the same session as Phase 7 (see that entry for why Phase
7/14's "next sprint" gating resolved early) — see that entry for the
shared test-architecture gap and how it was closed; not repeated here.

### What was built

- **Migration `202608190002_issue_reports_and_attachments_bucket.sql`**:
  `issue_reports` table (`report_id, submitted_by_user_id, page,
  description, screenshot_url, status, admin_remarks, created_at,
  updated_at`) + `handle_updated_at` trigger (reused from the User
  Management module's `202608140001_user_management.sql`, already applied
  to `profiles`). RLS: any signed-in user can insert/select their own
  reports (Architecture Decision 7); `is_admin_user()` callers can select
  and update any report — no admin delete policy, reports aren't
  deletable through this module's scope. `issue-report-attachments`
  storage bucket + policies, mirroring `profile-avatars`'s setup except
  objects are also readable by `is_admin_user()` callers (an admin needs
  to view any user's attachment, unlike avatars).
- **`SupabaseIssueReportRepository`** (`lib/data/`). `updateStatus`
  notably does **not** need an Edge Function the way suspend/reactivate
  did — it doesn't call `auth.admin.signOut()` or anything else requiring
  service role, so a direct RLS-scoped write from the signed-in admin's
  own session is enough (`issue_reports_update_admin` +
  `admin_audit_log_insert_admin` both evaluate `is_admin_user()` against
  that session's real `auth.uid()`).
- **`SupabaseAdminAuditLogRepository.getAllEntries`** (added Phase 8,
  real-backed since this is the same repository class Phase 7 built) —
  no separate work needed here since one audit table already served both
  sprints' actions (Architecture Decision 5/6).
- **`admin_repository_locator.dart`**: `issueReportRepository` swapped
  alongside the four Phase 7 repositories in the same locator edit.

### Deferred / not built

Same two items noted in Phase 7's "Deferred / not built" — real
screenshot upload to `issue-report-attachments` (bucket exists, nothing
uploads to it yet) and `SystemHealthScreen`'s Sprint 3 work.

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (941 tests) passes.

**Checkpoint reached**: both Sprint 1 (PB-01–PB-05, PB-10) and Sprint 2
(PB-06–PB-10) now run against the real Supabase backend end-to-end, not
mocks. Phase 15 onward (Sprint 3 — AI & System Monitoring) is still
genuinely unbuilt and, per `ADMIN_MODULE_IMPLEMENTATION_PLAN.md`'s own
numbering, the next phase in sequence.

---

## Phase 15 — Recon & Contracts (Sprint 3) (complete)

### Open Decisions — resolved with the plan's recommended defaults

7. **"Database connectivity status" / "API availability" while mock-first**
   — recommended default taken: `SystemHealthScreen` (Phase 19) will show
   **"N/A — mock backend in use"** for any indicator with no real
   infrastructure behind it, rather than fabricating a fake "healthy"
   status. The Gemini AI key check is real and buildable now (`.env`'s
   `GEMINI_API_KEY` set or not) — that's the one indicator Phase 19 can
   check honestly today.
8. **`SystemErrorLog` severity levels** — recommended default taken: a
   four-value `ErrorSeverity` enum (`info, warning, error, fatal`),
   matching common logging-framework convention.

### Entities defined (`lib/models/`)

- `SystemErrorLog` (`system_error_log.dart`) — `logId`, `module`,
  `severity` (`ErrorSeverity`), `message`, `stackTrace` (nullable),
  `createdAt`. `fromJson`/`toJson` included for the eventual Phase 21
  Supabase swap.
- `AiRequestLog` (`ai_request_log.dart`) — `logId`, `userId`, `requestType`
  (`AiRequestType { dailyAdvice, foodDetection, tripSummary }`), `status`
  (`AiRequestStatus { succeeded, failed }`), `executionTimeMs`,
  `errorMessage` (nullable), `createdAt`. `fromJson`/`toJson` included.

### Repository interfaces defined (`lib/data/`, no implementations)

- `SystemErrorLogRepository` — `recordError(entry)`, `getAllErrors({module,
  severity})`
- `AiRequestLogRepository` — `recordRequest(entry)`, `getAllRequests({status})`,
  `getFailedRequests()`

### AI locator recon

Confirmed the current shape of all three locators Phase 18 will wrap —
each is a single top-level `final <Service>` resolved by a private
`_resolve...()` function that checks `dotenv.env['GEMINI_API_KEY']` and
falls back to a `Mock...Service`:

- `lib/features/journal/ai/daily_advice_locator.dart` → `dailyAdviceService`
  (`DailyAdviceService`)
- `lib/features/journal/ai/food_detection_locator.dart` →
  `foodDetectionService` (`FoodDetectionService`)
- `lib/features/trip/ai/trip_summary_locator.dart` → `tripSummaryService`
  (`TripSummaryService`)

All three are plain top-level finals, not classes/functions taking a
repository — Phase 18's logging decorator will need to replace each final
with one that wraps the resolved service instance, timing calls and
writing to `AiRequestLogRepository` before delegating. None of the three
services currently exposes a shared interface beyond their own file's
abstract class, so the decorator will need one wrapper type per service
(or a generic wrapper parameterized over the call), not a single shared
decorator class — revisit at Phase 18 once the wrapping shape is chosen.

### Files touched (Phase 15)

- `lib/models/system_error_log.dart` (new)
- `lib/models/ai_request_log.dart` (new)
- `lib/data/system_error_log_repository.dart` (new)
- `lib/data/ai_request_log_repository.dart` (new)
- `docs/admin/PROGRESS.md` (this file)

### Verification

- `flutter analyze` — no issues found.

### Definition of Done

- [x] `SystemErrorLog`, `AiRequestLog` defined
- [x] `SystemErrorLogRepository`, `AiRequestLogRepository` defined, no
      implementations yet
- [x] Code compiles

---

## Phase 16 — Mock Repositories (Sprint 3) (complete)

### What was built

- **`MockSystemErrorLogRepository`** — seeded with 5 sample errors spanning
  every `ErrorSeverity` value and 4 different modules (`journal`, `trip`,
  `auth`, `health`). Same `_logCounter`/`nextLogId()` pattern as
  `MockAdminAuditLogRepository`.
- **`MockAiRequestLogRepository`** — seeded with 6 sample requests covering
  all three `AiRequestType` values with a mix of succeeded/failed status.
  `getFailedRequests()` delegates to `getAllRequests(status: failed)` rather
  than duplicating the filter/sort logic.
- **`admin_repository_locator.dart`**: both new repositories wired as
  top-level `final`s backed by their mocks — **not** lazy getters like the
  rest of the locator's entries. Unlike the Supabase-backed repositories
  (stateless — a fresh client wrapper per call is fine), these mocks hold
  in-memory state that must persist across every read/write for the app's
  lifetime, so a single shared instance is required. This will need
  revisiting at Phase 21 once real `Supabase*` implementations exist — at
  that point they can move back to lazy getters like every other entry in
  this file.

### Deferred / not built

`AdminTestHarness` (`test/support/admin_test_harness.dart`) was **not**
extended with these two repositories yet — there are no controllers to
wire them into until Phase 17/18 build `SystemErrorLogScreen` and
`AiRequestMonitoringScreen`. Revisit then.

### Files touched (Phase 16)

- `lib/data/mock_system_error_log_repository.dart` (new)
- `lib/data/mock_ai_request_log_repository.dart` (new)
- `lib/data/admin_repository_locator.dart` (modified — two new top-level
  `final` repositories)
- `test/mock_system_error_log_repository_test.dart` (new)
- `test/mock_ai_request_log_repository_test.dart` (new)
- `docs/admin/PROGRESS.md` (this file)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (954 tests) passes, including 13 net-new
  tests from this phase; no regressions.

### Definition of Done

- [x] Both mocks implemented and unit-testable
- [x] Locator wires them; still the one place mock vs. real is decided

---

## Phase 17 — PB-11: Monitor System Error Logs (mock) (complete)

### What was built

- **`error_reporting.dart`** (`lib/`, new — not under `lib/features/admin/`)
  — `reportSystemError(error, stackTrace, {severity})`, the global error
  hook per Architecture Decision 9. Extracted to its own top-level function,
  rather than an inline closure in `main()`, specifically so a test can call
  it directly and assert against `systemErrorLogRepository` without needing
  to actually crash something inside a running app. Fire-and-forget/
  best-effort — a logging failure must never take down the error handler
  itself, mirroring `AdminAuthController`'s best-effort access-attempt
  write (Sprint 1, post-Phase-3).
  - `module` is always `'app'` — a truly global hook has no reliable way to
    know which feature module raised a given error; a per-module tag would
    need per-feature instrumentation, out of scope for one global hook.
  - `logId` is a client-generated `Uuid().v4()` (already a dependency, used
    the same way for trip/entry/meal ids elsewhere), not
    `MockSystemErrorLogRepository.nextLogId()` — unlike Sprint 1/2's
    audit-log callers, which hold a concretely-typed `Mock*` reference and
    can call its counter, `error_reporting.dart` only ever sees the
    interface-typed `systemErrorLogRepository` global, and a client-generated
    id works identically once Phase 21 swaps in a real repository, so no
    later rework is needed here.
- **`main.dart` wiring** (cross-module — the app's entry point, not
  `lib/features/admin/`, flagged here per this plan's established
  discipline for cross-module touches):
  - `FlutterError.onError` — framework/rendering errors, still calls
    `FlutterError.presentError` first so existing debug-mode behavior
    (red screen, console output) is unchanged. Recorded as
    `ErrorSeverity.error` — the app typically keeps running after one of
    these, unlike an uncaught async error.
  - `runZonedGuarded` wraps `runApp` — catches uncaught errors in async code
    outside the widget tree's build/layout/paint path, which would
    otherwise crash the isolate. Recorded as `ErrorSeverity.fatal` (the
    function's default), since nothing else already caught it.
- **`SystemErrorLogController`** (`lib/features/admin/controller/`, new) —
  loads via `SystemErrorLogRepository.getAllErrors`, exposes
  loading/error/data plus module/severity filters. Mirrors
  `AuditLogController`'s plain `ChangeNotifier` convention. Also derives
  `availableModules` (the distinct set of modules seen, for the module
  filter's dropdown choices) from one unfiltered fetch the first time
  `load()` runs, since `SystemErrorLogRepository` has no separate
  "list distinct modules" method.
- **`SystemErrorLogScreen`** (`lib/features/admin/screens/`, new) —
  mirrors `AuditLogScreen`'s layout: a filter bar (severity `ChoiceChip`s +
  a module dropdown) above a `ListView` of card-style tiles, not a plain
  text dump — each tile shows a severity icon/color, the module, a relative
  timestamp, and the message; tapping an entry that has a stack trace opens
  it in a dialog (`SelectableText`, monospace) rather than inlining a long
  trace into the list. Reached from `AdminDashboardScreen`'s app bar
  (`admin-system-errors`, mirrors the existing "Audit log"/"Issue reports"
  icon-button entry points).
- **`errorSeverityLabel`** added to `admin_format_utils.dart`, shared for
  reuse by Phase 20's monitoring report; severity icon/color stayed local
  to `system_error_log_screen.dart` (mirrors
  `admin_issue_report_list_screen.dart`'s own `_statusIcon`/`_statusColor`
  precedent) since no second screen needs them yet.
- **`AdminTestHarness`** gained a sixth override
  (`systemErrorLogControllerProvider`) plus an exposed
  `systemErrorLogRepository`/`systemErrorLogController`, mirroring the
  other five. Noted in its doc comment as the one exception to "seeded
  identically to the real locator's defaults" — Sprint 3's two repositories
  stay mock-backed permanently (Phase 21 is a later sprint), so there's no
  Supabase counterpart to match seed data against.

### No database changes

Phase 17 is UI/mock-only, per the plan (Phase 21, a later sprint, is where
`system_error_logs` gets a real table). Nothing in `supabase/` was touched.

### Files touched (Phase 17)

- `lib/error_reporting.dart` (new)
- `lib/main.dart` (modified — cross-module: `FlutterError.onError` +
  `runZonedGuarded` wiring)
- `lib/features/admin/controller/system_error_log_controller.dart` (new)
- `lib/features/admin/screens/system_error_log_screen.dart` (new)
- `lib/features/admin/screens/admin_dashboard_screen.dart` (modified —
  "System error log" app bar action)
- `lib/features/admin/admin_format_utils.dart` (modified — `errorSeverityLabel`)
- `test/support/admin_test_harness.dart` (modified — sixth provider override)
- `test/error_reporting_test.dart` (new, 2 tests)
- `test/system_error_log_controller_test.dart` (new, 10 tests)
- `test/system_error_log_screen_test.dart` (new, 10 tests)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (1157 tests) passes, including the 22 new
  Phase 17 tests; no regressions.

### Definition of Done

- [x] An error thrown anywhere in the app (mock-triggerable for testing)
      appears in the log — `reportSystemError` is directly callable from a
      test, exactly for this
- [x] Filtering by module and by severity both demonstrably narrow results,
      and compose together

### Next phase (Phase 18) should start with

The logging decorator wrapping the three AI locators
(`daily_advice_locator.dart`, `food_detection_locator.dart`,
`trip_summary_locator.dart` — Journal/Trip module files, another
cross-module touch to flag) plus `AiRequestMonitoringScreen` and the
failed-requests/retry view.

---

## Phase 18 — PB-12 + PB-13: AI Request Monitoring (mock) (complete)

### What was built

- **`lib/data/ai_request_logging.dart`** (new, data-layer — mirrors
  `error_reporting.dart`'s placement) — `recordAiRequest({requestType,
  status, executionTimeMs, errorMessage})`, the shared recording helper the
  three per-service decorators below all funnel through (id generation via
  `Uuid().v4()`, current-user resolution, fire-and-forget write), so that
  logic isn't tripled across three files. `userId` resolves from
  `Supabase.instance.client.auth.currentUser` — best-effort, wrapped in its
  own try/catch (falls back to `'unknown'`) since none of the three AI
  service interfaces take a `userId` parameter, and this stays safe to
  exercise in a test, which never calls `Supabase.initialize()`.
- **Per-locator logging decorators** (cross-module — Journal/Trip module
  files, not `lib/features/admin/`, flagged here per this plan's
  established discipline):
  - `daily_advice_locator.dart`, `food_detection_locator.dart`,
    `trip_summary_locator.dart` each gained a private
    `_Logging*Service` class implementing that file's own service
    interface, wrapping the existing resolved instance, timing the call
    with a `Stopwatch`, and calling `recordAiRequest` on success or failure
    (rethrowing after recording a failure, so the wrapped call's own
    error-handling at the UI layer is unaffected).
  - **Deviation from the plan's literal wording**: "wrapping … the three
    AI locators" could read as replacing each locator's existing exported
    symbol (`dailyAdviceService` etc.) with the decorator outright. Not
    done that way — `daily_advice_locator_test.dart` and
    `food_detection_locator_test.dart` (Phase 15-era, already shipped)
    assert `dailyAdviceService is MockDailyAdviceService` /
    `foodDetectionService is MockFoodDetectionService` in the no-key case,
    which a decorator wrapping and hiding the underlying type would break.
    Each locator instead exports a **second** symbol —
    `loggedDailyAdviceService`, `loggedFoodDetectionService`,
    `loggedTripSummaryService` — and production call sites
    (`journal_controller.dart`'s provider, `health_log_form.dart`,
    `trip_view_screen.dart`; also cross-module, same three files the plan
    itself names) were switched to the `logged*` symbol instead of the raw
    one. The raw symbols are otherwise untouched. Per the plan's own
    instruction ("trust the repo, note the conflict, proceed with the more
    sensible option").
- **`AiRequestMonitoringController`/`AiRequestMonitoringScreen`** (PB-12,
  `lib/features/admin/`) — mirrors `SystemErrorLogController`/
  `SystemErrorLogScreen`'s shape: status filter (`ChoiceChip`s: All /
  Succeeded / Failed) above a card-tile `ListView` (type, status icon/
  color, execution time, relative time). View-only — no retry buttons
  here; reached from `AdminDashboardScreen`'s app bar
  (`admin-ai-requests`).
- **`FailedAiRequestsController`/`FailedAiRequestsScreen`** (PB-13,
  `lib/features/admin/`) — a **separate** screen, not a filtered view
  layered onto the PB-12 screen above, matching the precedent already set
  by `AiRequestLogRepository.getFailedRequests`'s own doc comment (Phase
  15): "exposed separately since PB-13 is its own backlog item with its
  own screen". Loads only failed entries; each tile shows the error
  message and a per-row Retry button (a per-`logId` `Set` tracks which
  row has a retry in flight, so one retry doesn't disable every button on
  the screen). Reached from `AiRequestMonitoringScreen`'s app bar
  (`admin-ai-requests-failed`).
- **`ai_request_retry.dart`** (`lib/features/admin/`, new) —
  `retryAiRequest(AiRequestType)`, PB-13's retry action (Architecture
  Decision 10). **Deviation, flagged explicitly**: Architecture Decision
  10 names two acceptable designs — store original call params on
  `AiRequestLog` "if feasible", or "just 'try the action again from the UI
  that triggered it'". Storing real params wasn't attempted: the three
  services' inputs (meals/steps/mood; an image file; a trip + its journal
  entries) belong to whichever user made the original request, not to a
  monitoring log an admin reads, and would need `AiRequestLog` to grow a
  bespoke payload shape per request type. Instead, retry re-invokes the
  same request type's `logged*Service` against a small, fixed,
  synthetic payload (empty meals/neutral mood; a placeholder image path;
  a synthetic one-entry trip) — this demonstrates *whether the AI
  capability itself is currently working* (a network/quota/API-key issue
  reproduces; a request-specific data issue doesn't), not a replay of the
  original request. `FailedAiRequestsScreen`'s post-retry `SnackBar`
  states this plainly ("a representative test request") rather than
  implying the original request was reproduced. The retry is recorded as
  its own new `AiRequestLog` entry via the same `logged*Service` path real
  calls use — it does not mutate the original failed entry, which is why
  that entry stays visible in `FailedAiRequestsScreen` after a retry.
- **`aiRequestTypeLabel`/`aiRequestStatusLabel`** added to
  `admin_format_utils.dart`, shared between the two new screens (and,
  per Phase 20's plan, its monitoring report).
- **`AdminTestHarness`** gained its seventh and eighth overrides
  (`aiRequestMonitoringControllerProvider`, `failedAiRequestsControllerProvider`)
  plus an exposed `aiRequestLogRepository`, mirroring Phase 17's
  `systemErrorLogRepository` addition — same "not seeded identically to
  the real locator" exception noted in its doc comment.

### No database changes

Phase 18 is UI/mock-only, per the plan (Phase 21, a later sprint, is where
`ai_request_logs` gets a real table). Nothing in `supabase/` was touched.

### Files touched (Phase 18)

- `lib/data/ai_request_logging.dart` (new)
- `lib/features/journal/ai/daily_advice_locator.dart` (modified — cross-module:
  `_LoggingDailyAdviceService` + `loggedDailyAdviceService`)
- `lib/features/journal/ai/food_detection_locator.dart` (modified —
  cross-module: `_LoggingFoodDetectionService` + `loggedFoodDetectionService`)
- `lib/features/trip/ai/trip_summary_locator.dart` (modified — cross-module:
  `_LoggingTripSummaryService` + `loggedTripSummaryService`)
- `lib/features/journal/controller/journal_controller.dart` (modified —
  cross-module: provider now injects `loggedDailyAdviceService`)
- `lib/features/journal/widgets/health_log_form.dart` (modified —
  cross-module: calls `loggedFoodDetectionService`)
- `lib/features/trip/trip_view_screen.dart` (modified — cross-module: calls
  `loggedTripSummaryService`)
- `lib/features/admin/ai_request_retry.dart` (new)
- `lib/features/admin/controller/ai_request_monitoring_controller.dart` (new)
- `lib/features/admin/controller/failed_ai_requests_controller.dart` (new)
- `lib/features/admin/screens/ai_request_monitoring_screen.dart` (new)
- `lib/features/admin/screens/failed_ai_requests_screen.dart` (new)
- `lib/features/admin/screens/admin_dashboard_screen.dart` (modified —
  "AI request monitoring" app bar action)
- `lib/features/admin/admin_format_utils.dart` (modified —
  `aiRequestTypeLabel`, `aiRequestStatusLabel`)
- `test/support/admin_test_harness.dart` (modified — seventh/eighth
  provider overrides)
- `test/ai_request_retry_test.dart` (new, 3 tests)
- `test/ai_request_monitoring_controller_test.dart` (new, 6 tests)
- `test/ai_request_monitoring_screen_test.dart` (new, 8 tests)
- `test/failed_ai_requests_controller_test.dart` (new, 5 tests)
- `test/failed_ai_requests_screen_test.dart` (new, 6 tests)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (1185 tests) passes, including the 28 new
  Phase 18 tests; no regressions in Journal/Trip module tests despite the
  three cross-module call-site changes.

### Definition of Done

- [x] A real (mock) AI call appears in the log with status and timing —
      confirmed by `ai_request_retry_test.dart` exercising all three
      `logged*Service`s end to end against the shared repository
- [x] Failed requests are visibly distinguishable and individually
      retryable — `FailedAiRequestsScreen`'s per-row Retry button

### Next phase (Phase 19) should start with

`SystemHealthScreen` (PB-14) — per Open Decision 7, a real check for
`GEMINI_API_KEY` configuration, "N/A — mock backend in use" placeholders
for database/API availability until real infrastructure exists. No new
repository needed; this reads `dotenv.env['GEMINI_API_KEY']` directly,
same as the three AI locators already do.

---

## Phase 19 — PB-14: System Health Dashboard (mock) (complete)

### What was built

- **`SystemHealthScreen`** (`lib/features/admin/screens/`, new) — three
  indicator cards:
  - **Gemini AI** — the one *real* check, per Open Decision 7: `dotenv.isInitialized
    ? dotenv.env['GEMINI_API_KEY'] : null`, the same expression the three AI
    locators already evaluate. Shows "Configured"/"Not configured", never a
    fabricated "Healthy".
  - **Database Connectivity** and **Backend API** — both show **"N/A"**
    with a "Mock backend in use — no live \[connectivity/availability\]
    check is performed for this indicator yet" detail line. **Deliberately
    not upgraded to a real Supabase ping**, even though Phase 7 (real
    backend) already exists for most of this module by this point in the
    session — the plan's own Phase 21 outline explicitly scopes "an actual
    lightweight Supabase query for DB connectivity" to Phase 21 (a later
    sprint), not Phase 19, so this isn't a stale assumption left over from
    before Phase 7 landed; it's a deliberate phase boundary restated in the
    plan even after describing Phase 7. No conflict to flag here — followed
    as written.
  - No controller/repository — every indicator is either a synchronous
    `dotenv` read or a fixed placeholder, so there's no loading/error state
    to manage, unlike every other admin screen so far.
- **Mid-batch redesign: `SystemMonitoringScreen`** (`lib/features/admin/screens/`,
  new) — **not a numbered phase of its own**, but built alongside Phase 19
  because Phase 19 is what made it necessary. Phases 17 and 18 each added
  their own `AdminDashboardScreen` app bar icon (`admin-system-errors`,
  `admin-ai-requests`), following Sprint 1/2's one-icon-per-screen
  precedent. Adding Phase 19's `SystemHealthScreen` as a fourth — with
  Phase 20's `MonitoringReportScreen` still to come as a likely fifth —
  would have pushed the app bar past what the team's explicit design bar
  for this batch ("clean, organized… don't leave anything displayed just
  as sentence", 2026-08-26) can reasonably hold. `SystemMonitoringScreen`
  replaces those two icons with one (`admin-monitoring`) and presents all
  three Sprint 3 monitoring screens as tappable cards (icon, title,
  one-line description, chevron) — the same card language
  `AdminDashboardScreen`'s `_DashboardStatCard` and `AdminUserListScreen`'s
  results already use, not a plain list of links. Phase 20's report screen
  gets its own card here too, rather than a sixth dashboard icon.
- **`AdminDashboardScreen`**: `admin-system-errors` and `admin-ai-requests`
  icons removed; replaced with the single `admin-monitoring` icon →
  `SystemMonitoringScreen`. No test referenced either removed key by its
  exact string (confirmed by search before removing them), so nothing
  else needed updating for the removal itself.

### No database changes

Phase 19 is UI-only — no repository, no mock, no migration. Nothing in
`supabase/` was touched.

### Files touched (Phase 19)

- `lib/features/admin/screens/system_health_screen.dart` (new)
- `lib/features/admin/screens/system_monitoring_screen.dart` (new)
- `lib/features/admin/screens/admin_dashboard_screen.dart` (modified —
  two icons replaced with one)
- `test/system_health_screen_test.dart` (new, 3 tests)
- `test/system_monitoring_screen_test.dart` (new, 4 tests)
- `test/admin_dashboard_screen_test.dart` (modified — added a test for the
  new Monitoring action)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (1193 tests) passes, including the 8 new/
  changed Phase 19 tests; no regressions.

### Definition of Done

- [x] Screen renders without fabricating a misleading "healthy" status for
      anything not actually checked — Database Connectivity/Backend API
      show "N/A", not "Connected"/"Healthy" (asserted directly by test)

### Next phase (Phase 20) should start with

`MonitoringReportScreen` (PB-15) — a date-range picker, a summary drawing
on Phases 17–19's data (error counts by severity, AI request counts by
status, issue counts by status from Sprint 2), PDF export via the existing
`printing`-based pattern, and a plain-formatter CSV export (no new
dependency). Gets its own card on `SystemMonitoringScreen` alongside the
three built so far, per that screen's own doc comment.

---

## Phase 20 — PB-15: Generate System Monitoring Reports (mock) (complete)

### What was built

- **`MonitoringReport`** (`lib/features/admin/monitoring_report.dart`, new)
  — a plain computed struct (`errorCountsBySeverity`,
  `aiRequestCountsByStatus`, `issueCountsByStatus`, plus `total*` getters),
  deliberately **not** a `lib/models/` entity — nothing here is persisted;
  it's assembled fresh by the controller each time.
- **`MonitoringReportController`** (new) — draws on
  `SystemErrorLogRepository`, `AiRequestLogRepository`, and
  `IssueReportRepository` (Sprint 2's, read-only here). None of the three
  support a date-range parameter on their own `getAll*` methods, so this
  fetches everything from each and filters to `startDate`/`endDate`
  itself — same composition style `AuditLogController` already uses for
  data its own repository doesn't filter for it. Auto-generates an
  all-time report on screen open, then regenerates on every date-range
  change (no separate "Apply"/"Generate" step) — kept consistent with
  every other admin filter screen's auto-reload-on-change convention
  rather than introducing a new confirm-step pattern nowhere else in this
  module uses it.
- **`MonitoringReportScreen`** (new) — a date-range picker (mirrors
  `AuditLogScreen`'s `showDateRangePicker` usage) above three report-section
  cards (label + count rows + a bold Total row, not a plain text dump),
  plus Export PDF / Export CSV actions.
- **PDF export** (`lib/features/admin/pdf/monitoring_report_pdf.dart`,
  Architecture Decision 11) — built the same way `journal_pdf_export.dart`
  builds its documents (a `pw.Document`, returned as bytes, shared via
  `Printing.sharePdf` — no second PDF-building convention introduced).
- **CSV export** (`lib/features/admin/monitoring_report_csv.dart`) — a
  plain `StringBuffer` formatter, no new dependency, per the plan. No
  CSV-escaping logic needed: every value written (severity/status labels,
  "Total", counts) is a fixed label or an integer, never free text that
  could contain a comma or quote.
- **CSV delivery, deliberately not a new dependency either**: `share_plus`
  (already a dependency, used by the trip-publishing feature's Share Link)
  offers `Share.shareXFiles`, which shares raw bytes as a file — reused for
  the CSV rather than reaching for a file-saving package just for this one
  export.
- **Mid-batch follow-through**: `SystemMonitoringScreen` gained its fourth
  card (`admin-monitoring-report`), exactly as that screen's Phase 19 doc
  comment said it would — no new dashboard app bar icon.

### No database changes

Phase 20 is UI-only — no repository, no mock, no migration. It reads from
the same three repositories Phases 8/16 already built; nothing in
`supabase/` was touched.

### Files touched (Phase 20)

- `lib/features/admin/monitoring_report.dart` (new)
- `lib/features/admin/controller/monitoring_report_controller.dart` (new)
- `lib/features/admin/screens/monitoring_report_screen.dart` (new)
- `lib/features/admin/pdf/monitoring_report_pdf.dart` (new)
- `lib/features/admin/monitoring_report_csv.dart` (new)
- `lib/features/admin/screens/system_monitoring_screen.dart` (modified —
  fourth card)
- `test/support/admin_test_harness.dart` (modified — ninth provider
  override, using the harness's existing mock `issueReportRepository`)
- `test/monitoring_report_controller_test.dart` (new, 7 tests)
- `test/monitoring_report_pdf_test.dart` (new, 8 tests)
- `test/monitoring_report_csv_test.dart` (new, 4 tests)
- `test/monitoring_report_screen_test.dart` (new, 6 tests)
- `test/system_monitoring_screen_test.dart` (modified — added the fourth
  card's coverage)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (1218 tests) passes, including the 26 new/
  changed Phase 20 tests; no regressions.

### Definition of Done

- [x] A generated report reflects the current mock data accurately —
      `monitoring_report_controller_test.dart` verifies exact counts by
      severity/status and correct date-range narrowing
- [x] Both PDF and CSV export produce a downloadable file —
      `monitoring_report_pdf_test.dart`/`monitoring_report_csv_test.dart`
      verify the actual bytes/content built; the screen wires both to
      `Printing.sharePdf`/`Share.shareXFiles`

**Sprint 3 complete.** PB-11 through PB-15 all work end-to-end against
mocks — the same checkpoint shape Sprint 1 and Sprint 2 each reached before
their own real-backend phase. Phase 21 (real backend for
`system_error_logs`/`ai_request_logs`, plus `SystemHealthScreen`'s real
checks) is out of scope for this sprint and explicitly deferred to a later
sprint per the plan's own outline.

---

## Phase 21 — Real Backend (Sprint 3) (complete)

### What was built

- **Migration** (`202608260002_system_error_and_ai_request_logs.sql`)
  — `system_error_logs` and `ai_request_logs` tables. Write path: direct
  RLS-scoped client inserts, per the Phase 7 precedent (Edge Functions are
  only for operations needing `auth.admin.signOut()` or similar
  service-role-only work — neither table needs that).
  - `system_error_logs` has **no `user_id` column at all** — an uncaught
    error isn't "about" a specific user, and `main.dart`'s hook has no
    reliable way to attribute one regardless (it can fire before sign-in
    resolves). Insert policy is `to authenticated, with check (true)`: any
    signed-in session, no ownership check, since there's no owner column
    to check against. **Known, accepted gap**: an error occurring before
    anyone is signed in has no session to insert under and is silently
    dropped — consistent with the fire-and-forget philosophy the hook
    already used.
  - `ai_request_logs.user_id` is **`text`, not `uuid references
    auth.users(id)`** — the Dart-side resolver falls back to the literal
    string `'unknown'` when no session is resolved, which isn't a valid
    `auth.users` id and would violate a real foreign key. Insert policy is
    `auth.uid()::text = user_id` (mirrors `admin_access_attempt_log`'s
    "insert about yourself only" policy) — an entry with the `'unknown'`
    placeholder is rejected and silently dropped, same gap as above. In
    practice both AI-locator decorators only ever fire from already-
    authenticated feature screens, so this is a theoretical safety net,
    not an expected occurrence.
  - **Deferred, flagged**: no `supabase/tests/*.sql` pgTAP file was written
    for these two tables' RLS, unlike every other admin-module migration.
    This session has no Supabase CLI/local Postgres to run one against, so
    writing one blind — unable to verify it actually passes — risked
    shipping a broken test that looks like coverage but isn't. Recorded
    here as a real gap, not silently skipped: whoever next has a local
    Supabase environment should add
    `supabase/tests/system_error_and_ai_request_logs_test.sql` mirroring
    `trip_summary_permissions_test.sql`'s shape before trusting these two
    policies in production.
- **`SupabaseSystemErrorLogRepository`, `SupabaseAiRequestLogRepository`**
  (`lib/data/`, new) — mirror `SupabaseAdminAccessAttemptLogRepository`'s
  shape exactly (a private `_fromRow` mapper method, not a separate
  `*_supabase_mapper.dart` file — that's the pattern the *other* modules
  use; every admin-module Supabase repo keeps its mapping inline).
- **`admin_repository_locator.dart`**: `systemErrorLogRepository` and
  `aiRequestLogRepository` swapped from top-level `final`s (mock) to lazy
  getters (Supabase) — exactly the move Phase 16's own doc comment said
  would happen here.
- **Two real bugs found and fixed** — both were latent in the Phase 17/18
  code, invisible while the locator was mock-backed, and only surfaced
  once `systemErrorLogRepository`/`aiRequestLogRepository` became lazy
  getters that can throw on resolution:
  - `recordAiRequest` (`ai_request_logging.dart`) resolved
    `aiRequestLogRepository` (now a throwing getter) *outside* its
    protective `try`/`catchError` — a synchronous throw there propagated
    straight out of the function, landing back in the calling
    `_Logging*Service`'s own `try` block. **Consequence**: a *successful*
    AI call was being misreported as failed whenever the repository
    getter threw (e.g. any plain test), because the resulting exception
    was caught by the wrapper's `catch` clause instead of being an
    invisible logging failure. Fixed by moving the repository resolution
    inside its own `try`/`catch`.
  - `reportSystemError` (`error_reporting.dart`) had the identical shape
    of bug against `systemErrorLogRepository`. This one is more serious
    than the AI-request case: `main.dart` wires this function directly
    into `FlutterError.onError`, which is set up *before*
    `Supabase.initialize()` runs — a framework error during that window
    would have thrown a second time from inside the error handler itself.
    Same fix.
  - Also found and fixed the same shape of bug in the two new **health
    check helpers themselves**, mid-implementation:
    `checkSupabaseConnectivity` resolved `Supabase.instance.client`
    outside its own `try` block, so the exact same "not initialized"
    throw it was meant to catch instead propagated past it, uncaught,
    into `SystemHealthScreen`'s `initState` callback. Fixed identically.
  - Recorded together here because they're one lesson: **a lazy getter
    that can throw must be resolved *inside* the `try` block that's
    supposed to guard it, not before it** — a mistake easy to make once
    and then copy-paste three more times, which is exactly what happened
    across Phases 17/18/21 before Phase 21's real backend exposed it.
- **`SystemHealthScreen` real checks** (`lib/features/admin/screens/`,
  rewritten) — StatelessWidget → StatefulWidget:
  - **Gemini AI**: still shows Configured/Not-configured on load (the
    Phase 19 check, unchanged) — plus a new **"Test Connection" button**,
    shown only when configured, calling
    [`checkGeminiReachability`](../../lib/features/admin/gemini_reachability.dart)
    on tap. **Deliberately on-demand, never automatic**: this app has
    already hit Gemini free-tier quota exhaustion twice in real use (see
    `gemini_model.dart`'s doc comment) — spending a real API call every
    time this screen opens, just to show a status chip, would work
    against that lesson. `checkGeminiReachability` calls `ListModels`, not
    `generateContent` — a metadata call, not a generation request, so
    even the on-demand check doesn't compete with the app's own AI-feature
    quota.
  - **Supabase Connectivity**: a real, automatic check on open
    ([`checkSupabaseConnectivity`](../../lib/features/admin/supabase_connectivity.dart)
    — a cheap `profiles` read, RLS-satisfied by the same `is_admin_user()`
    policy that let this admin reach the screen at all) plus a manual
    re-check button.
  - **Deviation, flagged**: Phase 19's three indicators (Gemini AI,
    Database Connectivity, Backend API) are now **two**. This app has no
    backend distinct from Supabase to test separately — the original
    proposal's "Node.js / Python FastAPI" line (`CLAUDE.md`'s Tech Stack
    table) was aspirational and never built. Testing "Backend API" as its
    own indicator would just be re-running the same PostgREST query under
    a different label. Per the plan's own instruction ("trust the repo,
    note the conflict, proceed with the more sensible option").
- **`AdminTestHarness`** doc comment updated — its four Sprint-3
  controllers are still exceptions to "seeded identically to the real
  locator's defaults," but the *reason* changed: it's no longer "the real
  locator has no Supabase counterpart" (Phase 21 gave it one), it's that a
  real `system_error_logs`/`ai_request_logs` table starts empty for every
  account, so there's no fixed default-seed count to mirror the way the
  other five mocks mirror a real table's starting rows.

### Cascading test fixes (Phase 21's real cost)

Five test files touched the real, shared `systemErrorLogRepository`/
`aiRequestLogRepository` globals directly — safe while they were
mock-backed singletons, unsafe the moment they became live Supabase
getters:

- `error_reporting_test.dart` — `reportSystemError` gained an optional
  `repository` parameter (a test seam, defaults to the real global) so
  the test can inject a `MockSystemErrorLogRepository` instead.
- `ai_request_retry_test.dart` — `retryAiRequest` has **no** injection
  seam (its whole point is exercising the exact production `logged*Service`
  call path), so this couldn't be fixed the same way. Rewritten to assert
  only that each call `completes` without throwing — it can no longer
  assert a written log entry, since that write now targets a real
  Supabase table this session can't reach.
- `failed_ai_requests_controller_test.dart` — switched from the real
  global to a locally-constructed `MockAiRequestLogRepository`. The
  "retry leaves the original entry" test's assertion changed to match:
  since `retry()` always writes through the real global regardless of
  which repository the controller itself holds, a retry's outcome no
  longer appears in *that same controller's* own list the way it did
  pre-Phase-21 — what's still true and still tested is that retry doesn't
  mutate the original entry.
- `ai_request_monitoring_screen_test.dart` — one test (navigating to
  `FailedAiRequestsScreen`) needed a `failedAiRequestsControllerProvider`
  override added alongside the existing one, since that screen reads a
  second provider on build.
- `system_health_screen_test.dart` — fully rewritten for the two-indicator
  layout; the Gemini "Test Connection" button is asserted to exist but
  **never tapped** in any test, to avoid making a real network call to
  Google's API during test runs.

Two new test files for the two new pure-function health checks:
`gemini_reachability_test.dart` (using `package:http/testing.dart`'s
`MockClient` — no real network call) and `supabase_connectivity_test.dart`
(asserts the "not initialized" path returns `false` rather than throwing).

### No database changes beyond this phase's own migration

The one migration above is the only `supabase/` change in Phase 21 — no
other table, policy, or function was touched.

### Files touched (Phase 21)

- `supabase/migrations/202608260002_system_error_and_ai_request_logs.sql` (new)
- `lib/data/supabase_system_error_log_repository.dart` (new)
- `lib/data/supabase_ai_request_log_repository.dart` (new)
- `lib/data/admin_repository_locator.dart` (modified — two repositories
  swapped from mock finals to Supabase-backed lazy getters)
- `lib/data/ai_request_logging.dart` (modified — sync-throw bug fix)
- `lib/error_reporting.dart` (modified — sync-throw bug fix + `repository`
  test-seam parameter)
- `lib/features/admin/gemini_reachability.dart` (new)
- `lib/features/admin/supabase_connectivity.dart` (new)
- `lib/features/admin/screens/system_health_screen.dart` (rewritten —
  StatefulWidget, two real checks)
- `test/support/admin_test_harness.dart` (modified — doc comment only)
- `test/error_reporting_test.dart` (modified — injected repository, no
  longer touches the real global)
- `test/ai_request_retry_test.dart` (modified — asserts completion, not a
  written entry)
- `test/failed_ai_requests_controller_test.dart` (modified — local mock
  repository, adjusted retry assertion)
- `test/ai_request_monitoring_screen_test.dart` (modified — second
  provider override)
- `test/system_health_screen_test.dart` (rewritten for the two-indicator
  layout)
- `test/gemini_reachability_test.dart` (new, 4 tests)
- `test/supabase_connectivity_test.dart` (new, 1 test)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (1226 tests) passes; no regressions, despite
  the five-file test cascade above.

### Definition of Done

- [x] `system_error_logs`, `ai_request_logs` migrated, RLS-scoped
      (pgTAP coverage flagged as a follow-up — see "Deferred, flagged" above)
- [x] The `main.dart` error hook and the three AI-locator wrappers write to
      the real tables via direct RLS-scoped client inserts
- [x] `SystemHealthScreen`'s Gemini indicator does a real reachability
      check (on-demand); Supabase connectivity is checked for real,
      automatically
- [x] `admin_repository_locator.dart` resolves both repositories to their
      `Supabase*` implementations

**Sprint 3 complete against the real backend.** PB-11 through PB-15 now
run end-to-end against Supabase, matching Sprint 1 (Phase 7) and Sprint 2
(Phase 14)'s own checkpoints. No further phases are defined in
`ADMIN_MODULE_IMPLEMENTATION_PLAN.md` beyond this one.

## Identity-model gap: an admin-role profile could still sign in as a traveler (found and fixed 2026-08-26)

### What was found

Decision 1's identity model (2026-08-12, above) says admin accounts are
**dedicated** — always a separate `Profile` row from any traveler account
the same person might have — so `AuthGate` (traveler) and `AdminGate`
(admin) are "two independent, non-overlapping entry points, since no
single sign-in can ever resolve to both."

That guarantee only ever held by *provisioning convention*, not by
anything enforced in code. Manually testing the admin flow against a
personal Google account that was already a real, in-use traveler account
(`profiles.role` flipped `user` → `admin` in place, rather than a fresh
dedicated admin profile being created) surfaced the gap directly: that
account stayed fully signed in on the traveler `HomeScreen` — journal
entries, health logging, everything — *while also* passing the Admin
Portal's `role == admin` check. `AuthController.status`
(`lib/features/auth/controller/auth_controller.dart`) never once consulted
`Profile.role`; it only ever branched on `isSuspended` / `isDeactivated` /
`profileCompleted`. So the "never both" promise was true only as long as
whoever created an admin account did it correctly — a single bad
provisioning step (or, later, a real backend role edit) broke it silently.

### What was fixed

Cross-module note: `auth_controller.dart` and `auth_gate.dart` belong to
the User Management module, not this one — flagging here per the plan's
own instruction to document conflicts rather than silently resolve them,
same as Decision 2's `AccountStatus.suspended` addition above. The change
is narrow (one extra branch, checked first, plus one new screen) and
directly enforces this module's own confirmed identity-model decision, so
it was made now rather than left as a written-down risk.

- `AuthStatus` gained `adminAccount`.
- `AuthController.status` now checks `profile.role == UserRole.admin`
  before anything else (including `isSuspended`/`isDeactivated`) and
  returns `adminAccount` — a categorical redirect off the traveler side
  entirely, not just another traveler account state, so it takes priority
  over what the profile's other fields say.
- New `AdminAccountScreen` (`lib/features/auth/screens/admin_account_screen.dart`,
  modelled on `SuspendedScreen`): explains the account is registered as an
  administrator and offers a "Sign out" button — the way back to
  `LoginScreen`, from which the Admin Portal is reachable via the existing
  hidden logo-tap entry.
- `AuthGate` routes `AuthStatus.adminAccount` to `AdminAccountScreen`.

### Tests added

- `test/auth_controller_test.dart` — an admin-role profile (both mutated
  mid-session and already-admin at sign-in time) resolves to
  `adminAccount`, not `authenticated`; and `adminAccount` wins even when
  the same profile is also `suspended`, confirming the priority ordering.
- `test/admin_account_screen_test.dart` (mirrors `suspended_screen_test.dart`) —
  `AuthGate` shows `AdminAccountScreen` (not `HomeScreen`) for an
  admin-role sign-in, and "Sign out" returns to `LoginScreen`.

### Verification

- `flutter analyze` — no issues found.
- `flutter test` — full suite (1234 tests) passes; no regressions.

### Not done here

Provisioning a *correct* dedicated admin account (the actual fix for the
account that surfaced this) is a database-side task, not a code change —
sign in once with the new account via the Admin Portal (never the
traveler login) so `handle_new_user` creates its `auth.users`/`profiles`
row, then set `role = 'admin'` on that row directly, before ever using it
as a traveler. The existing personal test account should have its `role`
reverted to `user` and stay a traveler-only account.

---

## `AdminGate` back-navigation guard — leaked the route underneath, then trapped rejected sign-ins (found and fixed 2026-08-26)

### What was found

Two related gaps in how `AdminGate` behaves as a *pushed* route, both only
visible once actually driven through `Navigator` rather than pumped in
isolation:

1. **No back-navigation guard at all.** `AdminGate` is reached via
   `Navigator.push` from the traveler `LoginScreen`'s hidden 3-tap logo
   gesture (Phase 2) — that route stays alive underneath. Because
   `adminAuthRepository` is an alias for the shared `authRepository`
   (Phase 7's Architecture Decision 2, not a second auth system), a
   successful admin sign-in shares the exact same Supabase session as the
   traveler side. Popping back out (hardware back / edge-swipe) after
   signing in would silently surface whatever the traveler `AuthGate` now
   resolves to underneath — usually `HomeScreen`, not the `LoginScreen` the
   admin portal was opened from a moment earlier.
2. **A rejected (non-admin) sign-in left the account signed in.** Before
   this fix, a rejection only set `AdminAuthController.error` and moved
   `status` to `unauthorized` — the real account stayed fully signed in,
   both the shared Supabase session and (since `AuthRepository` wraps one
   shared `GoogleSignIn` instance) Google's own cached "currently selected
   account". That second part actively broke the *next* sign-in attempt:
   `GoogleSignIn` generally reuses whichever account is already cached
   instead of showing the picker again, so retrying with the real admin
   account right after a rejected one could silently re-select the same
   wrong account. It also meant gap 1's guard, if applied naively, would
   have blocked back-navigation for `unauthorized` too — trapping the user
   on `AdminLoginScreen`, which has no sign-out affordance of its own, only
   "Sign in with Google", so "Log out to leave the admin portal" would be
   an instruction with no way to follow it.

### What was fixed

- **`AdminAuthController._rejectAndSignOut(session, message, reason)`**
  (new, replaces the inline `_error = …; await _recordAttempt(...)` in both
  rejection branches) — records the attempt first (must happen *before*
  signing out: `admin_access_attempt_log_insert_own`'s RLS check needs
  `auth.uid()` to still be the rejected account), then fully signs out
  (`_authRepository.signOut()`, clearing both Google's cache and the
  Supabase session) and clears `_session`/`_profile` — so `status` derives
  back to `signedOut`, not `unauthorized`, by the time the next build sees
  it. The message is stashed in a new one-shot `_pendingRejectionMessage`
  (`hasPendingRejection` getter, `consumePendingRejection()` — throws if
  called with nothing pending, mirrors `Queue.removeFirst`'s contract) for
  `AdminGate` to relay after popping itself, rather than leaving the
  now-signed-out account sitting on `AdminLoginScreen` for the user to
  notice the error and back out of manually.
- **`AdminGate.build`** — checks `controller.hasPendingRejection` first;
  if set, consumes it, captures the `Navigator`/`ScaffoldMessenger`
  *states* (not `context` — by the time the post-frame callback runs this
  widget's own route has popped and `context` is no longer valid, but
  these `State` objects live above the `Navigator` and stay mounted
  regardless), then in a post-frame callback pops itself and shows the
  rejection message as a `SnackBar` on the traveler screen underneath.
  One-shot specifically so a later rebuild (anything else this widget
  watches changing) doesn't pop a second time.
- **`AdminGate` wrapped in `PopScope`** — `canPop: status !=
  AdminAuthStatus.authenticated`. A blocked pop shows a `SnackBar`, "Log
  out to leave the admin portal." Deliberately **only** blocks
  `authenticated`, not `unauthorized` — per gap 2 above, a rejected attempt
  now signs itself out and pops automatically before this guard would ever
  see `unauthorized` on a real build anyway, and `authenticated` is the one
  status with a real "Log out" button (`AdminDashboardScreen`'s) for the
  message to point at.

### Files touched

- `lib/features/admin/admin_gate.dart` (modified — `PopScope` guard +
  pending-rejection consumption)
- `lib/features/admin/controller/admin_auth_controller.dart` (modified —
  `_rejectAndSignOut`, `hasPendingRejection`, `consumePendingRejection()`)
- `test/admin_gate_back_navigation_test.dart` (new, 4 tests — back blocked
  once authenticated; back allowed again after logout; back allowed before
  any sign-in attempt; a rejected sign-in auto-pops and relays the message
  as a `SnackBar` on the screen underneath)
- `test/admin_auth_controller_test.dart` (modified — the three rejection
  tests now assert `status == signedOut` (not `unauthorized`), `session`/
  `profile` cleared, and `hasPendingRejection`/`consumePendingRejection()`
  instead of just `error`/`status`)

### Verification

- `flutter analyze` — no issues found.
- `flutter test` (targeted: `admin_gate_back_navigation_test.dart`,
  `admin_auth_controller_test.dart`, `admin_account_screen_test.dart`,
  `auth_controller_test.dart`) — 53 tests pass, no regressions.