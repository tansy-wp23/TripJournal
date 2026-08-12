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