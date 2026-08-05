# Admin Module — Agentic Implementation Plan

This plan is written for an AI coding agent (e.g. Claude Code) running on a
free-tier model with a limited context window. It mirrors the structure of
`USER_MANAGEMENT_IMPLEMENTATION_PLAN.md` — small phases, one per session,
each ending with a `PROGRESS.md` entry so a fresh context window can resume
without re-reading everything. Do not skip ahead — later phases assume
earlier phases are done and merged.

## Sprint Goal (Sprint 1)

Develop the administrator authentication, dashboard, and user account
management features to enable administrators to securely access and manage
user accounts.

| Backlog ID | Item | Sprint Tasks |
|---|---|---|
| PB-01 | Authenticate Administrator | Create login UI, implement authentication logic, validate administrator credentials, verify administrator role, create administrator session |
| PB-02 | View Admin Dashboard | Create dashboard UI, retrieve dashboard statistics, display user/report summaries, integrate dashboard with business logic |
| PB-03 | Search and View User | Create user management page, implement search by username/email, display user details, integrate with database |
| PB-04 | Suspend User | Create suspension interface, validate suspension request, update account status, terminate active session, record audit log |
| PB-05 | Reactivate User | Create reactivation interface, update account status, record status history, record audit log |
| PB-10 | Logout Administrator | Implement logout functionality, clear session, redirect to login page |

**Sprint deliverables:** secure administrator login, dashboard overview,
user search and profile viewing, user suspension and reactivation,
administrator logout.

## Scope

This module is **module 4 (Admin)** from `CLAUDE.md`'s Final Module List.

Tables/entities newly owned by this module: `AdminAuditLog` (the `Audit_Log`
table that `USER_MANAGEMENT_IMPLEMENTATION_PLAN.md` explicitly left out of
scope — "Where this module needs to write an audit/error record, stub the
call... rather than building those tables here" — this module builds it).

Tables consumed, not owned (read/write via the existing interfaces, do not
redefine): `Profile` and its repository (`lib/data/profile_repository.dart`,
`lib/models/profile.dart`) plus `AuthRepository`/`AppSession` — all owned by
the User Management module. **Do not fork a parallel Profile model** — an
administrator is a `Profile` row with `role = UserRole.admin`. Any change to
`lib/models/profile.dart` (e.g. adding a status value, see Open Decision #2
below) is a cross-module change and must be coordinated with whoever owns
the User Management module before it's made, the same way that module
flagged `is_active_user()` back to this one.

Out of scope for this sprint: content moderation / user-submitted reports
(see Open Decision #3), real Supabase wiring (mock-first, per `CLAUDE.md`'s
Development Approach — real backend is a later phase/sprint, outlined but
not built here).

## Architecture Decisions (locked — do not re-litigate mid-implementation)

1. **Mock-first**, same convention as the rest of the app: every screen and
   controller depends on a repository **interface**; mocks are built first,
   real Supabase wiring lands later, one file changes to swap
   (`admin_repository_locator.dart`, mirroring `repository_locator.dart` /
   `user_management_repository_locator.dart`).
2. **No parallel admin-identity table.** Administrators authenticate through
   the same `AuthRepository`/`ProfileRepository` infrastructure the rest of
   the app already uses. "Verify administrator role" (PB-01) means checking
   `Profile.role == UserRole.admin` on the already-fetched profile, not
   maintaining a separate admin credentials store. This is why
   `lib/models/profile.dart` already carries a provisional `UserRole { user,
   admin }` — the User Management module built it in anticipation of this
   module (see `docs/user-management/PROGRESS.md`, Phase 0 deviations).
3. **Folder convention** (matches the existing repo layout, same rule the
   User Management module followed):
   ```
   lib/models/            # AdminAuditLog, AdminDashboardStats
   lib/data/               # admin repository interfaces + mock impls + locator
   lib/features/admin/     # admin screens, widgets, controllers
   docs/admin/PROGRESS.md  # phase-by-phase progress log (create in Phase 0)
   ```
4. **Session termination reuses the User Management module's privileged
   pattern**, not a new mechanism. PB-04's "terminate active session" is the
   same `auth.admin.signOut(userId)` call (service-role, Edge Function only)
   that Architecture Decision 3 of `USER_MANAGEMENT_IMPLEMENTATION_PLAN.md`
   already established for self-deactivation — this module just triggers it
   on a *different* user than the caller. No new session-revocation design
   needed, only a new caller of the existing pattern (real-backend phase).
5. **Audit logging is a single generic table**, not one table per action.
   `AdminAuditLog { logId, adminUserId, targetUserId, action, reason,
   createdAt }` with `action` an enum (`suspend`, `reactivate`, ...). PB-05's
   "record status history" is satisfied by querying this same table filtered
   to a user — it is not a second table. This is a deliberate simplification;
   revisit only if a future sprint needs audit entries for non-status
   actions with materially different shapes.

## Open Decisions — confirm before Phase 2

These are read from the sprint wording, not from an existing locked
decision elsewhere in the repo. Each has a recommended default so Phase 0/1
aren't blocked, but **flag these to the team (whoever owns the User
Management module in particular) before building the screens that depend on
them**, the same way that module's plan flagged its own open items.

1. **"Validate administrator credentials" — same Google sign-in + role
   check, or separate admin credentials?** Recommended default: reuse
   `AuthRepository.signInWithGoogle()` (Decision 2 above) — zero new auth
   infrastructure, and `Profile.role` already anticipates exactly this. If
   the team instead wants staff-issued email+password admin accounts,
   independent of the traveler-facing Google OAuth flow, that's a bigger
   fork: it adds a new `AuthRepository.signInWithEmailPassword()` (or a
   dedicated `AdminAuthRepository`) and changes what "administrator session"
   in PB-01 even means. Confirm before Phase 2 — it's cheap to redirect now,
   expensive after the login screen is built against the wrong assumption.
2. **Does "Suspend" need a status distinct from the existing
   `AccountStatus.deactivated`?** This is a correctness question, not just
   naming. The User Management module's self-service reactivation flow
   (`AccountLifecycleRepository.confirmReactivation`) lets *any* deactivated
   user reactivate themselves by signing in again and entering an emailed
   code (Architecture Decision 6 of that module). If an admin-suspended
   account is stored as plain `AccountStatus.deactivated`, a suspended user
   could sign in and self-reactivate through that existing flow, silently
   undoing the admin's action. **Recommended default: add a third value,
   `AccountStatus.suspended`, distinct from `deactivated`**, and have
   `confirmReactivation` reject `suspended` accounts (only
   `AdminAccountActionsRepository.reactivateUser` can clear that status).
   This is a change to a shared file (`lib/models/profile.dart`) owned by
   the User Management module — coordinate before Phase 5. If the team
   decides self-service reactivation bypassing a suspension is acceptable,
   document that explicitly instead of silently reusing `deactivated`.
3. **What "reports" means in PB-02's "display user/report summaries."**
   Nothing else in `CLAUDE.md` or the codebase defines a content-moderation
   "report" concept (no flagging, no reported-content table). Recommended
   default: read "report summaries" as **dashboard summary statistics**
   (total users, active/suspended counts, new signups this period) rather
   than a moderation-report feature, since no such feature exists elsewhere
   in the app. Flag this reading explicitly in the dashboard's PR — if the
   requirement actually meant user-submitted reports, that's new scope
   (new table, new module surface) that should go through the Requirements
   Lead first.

## How the Agent Should Use This Plan

- Work through phases in order, one phase per session where possible.
- At the end of every phase, append a **"Phase N complete"** entry to
  `docs/admin/PROGRESS.md` (create it in Phase 0): what was built, files
  touched, deviations and why, and what the next phase should do first.
- Do not proceed to the next phase until the current phase's Definition of
  Done is fully checked.
- Keep commits small and scoped to one task group at a time.
- If this plan conflicts with what's actually in the repo, trust the repo,
  note the conflict in `PROGRESS.md`, and proceed with the more sensible
  option.

---

## Phase 0 — Recon & Contracts (no feature code)

**Goal:** confirm what's reusable, lock the new interfaces, get the three
open decisions above answered or explicitly deferred with a documented
default.

**Tasks:**
1. Confirm `Profile.role` / `UserRole.admin` and `AccountStatus` still match
   what's described here (`lib/models/profile.dart`) — the User Management
   module owns this file and may have moved since this plan was written.
2. Record the resolution (or documented default) of Open Decisions 1–3 in
   `docs/admin/PROGRESS.md`.
3. Define new entities in `lib/models/`:
   - `AdminAuditLog { logId, adminUserId, targetUserId, action (AdminAction
     enum: suspend, reactivate), reason (String?), createdAt }`
   - `AdminDashboardStats { totalUsers, activeUsers, suspendedUsers,
     newUsersThisWeek, ... }` — keep to fields a mock can trivially compute;
     add trip/journal-count fields only if `TripRepository`/
     `JournalRepository` already expose a cheap way to get them, otherwise
     defer.
4. Define repository interfaces in `lib/data/` (no implementations yet):
   - `AdminDashboardRepository`: `Future<AdminDashboardStats>
     getDashboardStats()`
   - `AdminUserDirectoryRepository`: `Future<List<Profile>>
     searchUsers({String? query})`, `Future<Profile?> getUserById(String
     userId)` — a **multi-row** read over `Profile`, distinct from the
     single-caller `ProfileRepository` the User Management module owns.
   - `AdminAuditLogRepository`: `Future<void> recordAction(AdminAuditLog
     entry)`, `Future<List<AdminAuditLog>> getHistoryForUser(String
     userId)`
   - `AdminAccountActionsRepository`: `Future<void> suspendUser({required
     String adminUserId, required String targetUserId, String? reason})`,
     `Future<void> reactivateUser({required String adminUserId, required
     String targetUserId})` — each is a composition (update status + write
     audit log), not raw table access; real-backend phase adds the
     privileged session-termination call inside `suspendUser`.
5. Do **not** define a new auth repository yet — depends on Open Decision 1.
   If the default (reuse `AuthRepository`) is confirmed, Phase 2 adds a thin
   `AdminAuthController` on top of the existing `AuthRepository` +
   `ProfileRepository`, no new repository interface required.

**Definition of Done:**
- [ ] `docs/admin/PROGRESS.md` created with recon notes + Open Decisions 1–3
      resolved or explicitly deferred with a documented default
- [ ] `AdminAuditLog`, `AdminDashboardStats` defined
- [ ] `AdminDashboardRepository`, `AdminUserDirectoryRepository`,
      `AdminAuditLogRepository`, `AdminAccountActionsRepository` defined,
      no implementations yet
- [ ] Code compiles

---

## Phase 1 — Mock Repositories

**Goal:** in-memory fakes for all 4 new interfaces so UI work in Phases 2–6
never blocks on a backend.

**Tasks:**
1. `MockAdminUserDirectoryRepository` — seeded with a small fixed list
   (5–10) of sample `Profile` rows with varied `role`/`status`, independent
   of the single-profile `MockProfileRepository` (they model different
   personas — the admin's view of many users vs. a traveler's view of
   themselves). Search matches `displayName`/`email` substrings,
   case-insensitive.
2. `MockAdminDashboardRepository` — computes stats from the same seeded
   list (or a shared in-memory store passed to both, so suspending a user
   in Phase 5 is reflected in Phase 3's dashboard counts during manual
   testing).
3. `MockAdminAuditLogRepository` — appends to an in-memory list,
   `getHistoryForUser` filters and returns newest-first.
4. `MockAdminAccountActionsRepository` — mutates the shared seeded
   `Profile` list's status and calls into
   `MockAdminAuditLogRepository.recordAction`. "Terminate active session"
   has no real session to terminate in mock mode — record intent only
   (e.g. a `TODO(admin-module, real-backend):` comment), don't invent mock
   session infrastructure for it.
5. DI locator `lib/data/admin_repository_locator.dart`, mirroring
   `user_management_repository_locator.dart`: all four wired to mocks.

**Definition of Done:**
- [ ] All 4 mocks implemented and unit-testable
- [ ] Suspending/reactivating a user via the mock is visible in both the
      mock directory list and the mock dashboard stats
- [ ] A single locator file controls mock vs. real

---

## Phase 2 — PB-01: Authenticate Administrator (mock)

**Tasks:**
1. `AdminLoginScreen` (`lib/features/admin/screens/`) — per Open Decision 1's
   resolution. If reusing Google sign-in: a single sign-in button plus a
   distinct "Admin Portal" heading so it's visually clear this isn't the
   traveler login.
2. `AdminAuthController` (`lib/features/admin/controller/`, `ChangeNotifier`,
   mirroring `AuthController`) — calls the sign-in flow, fetches the
   profile, and branches:
   - no profile / `role != admin` → `AdminAuthStatus.unauthorized` (show an
     error, do not grant dashboard access — this is "verify administrator
     role")
   - `role == admin` → `AdminAuthStatus.authenticated` ("create
     administrator session" — for the reuse default this is just the
     existing `AppSession`, scoped by the role check, not a new session
     object)
3. `AdminGate` (`lib/features/admin/auth/`, mirroring `AuthGate`) — routes
   between `AdminLoginScreen` and `AdminDashboardScreen` on
   `AdminAuthController.status`.

**Definition of Done:**
- [ ] A `role = admin` profile reaches the dashboard
- [ ] A `role = user` profile is rejected with a visible message, not routed
      into the admin dashboard
- [ ] Manual test steps documented in `PROGRESS.md`

---

## Phase 3 — PB-02: View Admin Dashboard (mock)

**Tasks:**
1. `AdminDashboardScreen` — stat tiles for `AdminDashboardStats` (reuse the
   existing `StatTile` widget pattern from
   `lib/features/trip/widgets/stat_tile.dart` if it fits).
2. `AdminDashboardController` — calls
   `AdminDashboardRepository.getDashboardStats()`, exposes loading/error/
   data states.
3. Wire into `AdminGate` as the authenticated landing screen.

**Definition of Done:**
- [ ] Dashboard renders all fields of `AdminDashboardStats` against the mock
- [ ] Loading and error states both have visible UI (not just a blank
      screen)

---

## Phase 4 — PB-03: Search and View User (mock)

**Tasks:**
1. `AdminUserListScreen` — search field (username/email substring, reuse
   `JournalSearchBar`'s pattern from
   `lib/features/trip/widgets/journal_search_bar.dart` if it fits) over
   `AdminUserDirectoryRepository.searchUsers()`.
2. `AdminUserDetailScreen` — full `Profile` detail view for one user
   (`getUserById`), plus entry points to Phase 5's suspend/reactivate
   actions and Phase 5's audit history (`getHistoryForUser`).
3. `AdminUserManagementController` — search debouncing, empty-state
   ("no users match") handling.

**Definition of Done:**
- [ ] Search by partial username or email returns matching seeded users
- [ ] Selecting a user shows their full detail view
- [ ] Empty search results show a visible empty state, not a blank list

---

## Phase 5 — PB-04 + PB-05: Suspend / Reactivate User (mock)

**Tasks:**
1. `SuspendConfirmationDialog` (`lib/features/admin/widgets/`, mirroring
   `delete_trip_confirmation_dialog.dart`'s `Future<bool> show...` pattern) —
   confirms intent, optionally captures a `reason` string.
2. Suspend action on `AdminUserDetailScreen`: confirm →
   `AdminAccountActionsRepository.suspendUser(...)` → on success, refresh
   the detail view and show the updated status + a toast/snackbar.
   "Validate suspension request" — reject suspending an already-suspended
   user or an admin account (don't let an admin suspend another admin
   through this screen without a distinct confirmation, or block it
   entirely — decide and note in `PROGRESS.md`).
3. Reactivate action, same pattern, calling `reactivateUser(...)`.
4. Audit history section on `AdminUserDetailScreen` (from
   `getHistoryForUser`) — this is what satisfies PB-05's "record status
   history" without a second table (Architecture Decision 5).
5. If Open Decision 2 resolved to adding `AccountStatus.suspended`: verify
   (with a test, since this crosses into the User Management module's code)
   that `AccountLifecycleRepository.confirmReactivation` rejects a
   `suspended` profile.

**Definition of Done:**
- [ ] Suspend flow: confirm → status updates → audit log entry recorded →
      visible in the audit history section
- [ ] Reactivate flow: same, in reverse
- [ ] Both actions are cancellable before confirmation with no side effects
- [ ] If Open Decision 2's recommended default was taken: a suspended user
      cannot self-reactivate via the existing OTP flow (cross-module test)

---

## Phase 6 — PB-10: Logout Administrator (mock)

**Tasks:**
1. Logout button (e.g. in `AdminDashboardScreen`'s app bar) calling the
   same `AuthRepository.signOut()` used by the traveler-facing logout —
   driven by `AdminAuthController`/`AdminGate`'s state, not a manual
   redirect, mirroring how `AuthGate` handles the traveler logout.
2. Confirm it clears `AdminAuthController` state and returns to
   `AdminLoginScreen`.

**Definition of Done:**
- [ ] Logout returns the admin to `AdminLoginScreen`
- [ ] No stale admin state (profile/session) survives the logout

**Checkpoint:** at this point Sprint 1 works end-to-end against mocks —
matches the "good point to demo/review before touching real infrastructure"
checkpoint the User Management module used after its own mock phase.

---

## Phase 7 — Real Backend (outline only — next sprint)

Not built in Sprint 1; recorded here so Phase 0's contracts don't have to
change later.

- SQL migration for `admin_audit_log` (`logId`, `adminUserId`,
  `targetUserId`, `action`, `reason`, `createdAt`), FK `adminUserId`/
  `targetUserId` → `auth.users.id`.
- If Open Decision 2 added `AccountStatus.suspended`: migration touches the
  shared `Profile`/`profiles` table — coordinate with the User Management
  module owner, don't ship independently.
- RLS: `admin_audit_log` readable/writable only by rows where the caller's
  own `Profile.role = admin` (needs the same kind of Postgres helper as
  `is_active_user()` from the User Management module's Phase 8 — consider
  reusing that pattern, e.g. `is_admin_user()`).
- Edge Function `admin-suspend-user` (service role): verify caller is
  admin → set target `Profile.status` → `auth.admin.signOut(targetUserId)`
  → insert `admin_audit_log` row. `admin-reactivate-user`: same shape,
  minus the sign-out call.
- `AdminDashboardRepository`/`AdminUserDirectoryRepository` real
  implementations: RLS-protected reads scoped to `role = admin` callers.
- Swap `admin_repository_locator.dart` from `Mock*` to `Supabase*`, one line
  each, re-run Phases 2–6's manual test steps against the real backend.

---

## Known Issues / Risks

- **Open Decision 1 (credential mechanism) is the single biggest fork in
  this plan.** Confirm it before writing `AdminLoginScreen` — reworking a
  built screen from Google-OAuth-reuse to a separate credentials system (or
  vice versa) touches the controller, the screen, and possibly
  `AuthRepository`'s interface.
- **Open Decision 2 (suspended vs. deactivated) is a real correctness gap,
  not a style choice** — see the explanation above. If deferred past Phase
  5 without a documented decision, the suspend feature can be silently
  bypassed by the existing self-service reactivation flow.
- **Cross-module coordination**: any change to `lib/models/profile.dart`,
  `lib/data/profile_repository.dart`, `lib/data/account_lifecycle_repository.dart`,
  or `docs/user-management/PROGRESS.md`-documented architecture must be
  flagged to whoever owns the User Management module before merging — this
  plan should not silently fork that module's files.

## Traceability Reference

| Sprint Item | Phase |
|---|---|
| PB-01 | Phase 2 (mock) / Phase 7 (real) |
| PB-02 | Phase 3 (mock) / Phase 7 (real) |
| PB-03 | Phase 4 (mock) / Phase 7 (real) |
| PB-04 | Phase 5 (mock) / Phase 7 (real) |
| PB-05 | Phase 5 (mock) / Phase 7 (real) |
| PB-10 | Phase 6 (mock) / Phase 7 (real) |