# Admin Module — Agentic Implementation Plan

This plan is written for an AI coding agent (e.g. Claude Code) running on a
free-tier model with a limited context window. It mirrors the structure of
`USER_MANAGEMENT_IMPLEMENTATION_PLAN.md` — small phases, one per session,
each ending with a `PROGRESS.md` entry so a fresh context window can resume
without re-reading everything. Do not skip ahead — later phases assume
earlier phases are done and merged.

Covers three sprints: **Sprint 1** (auth, dashboard, user management —
complete, see `docs/admin/PROGRESS.md`), **Sprint 2** (issue management +
audit monitoring), **Sprint 3** (AI + system monitoring). Sprint 2/3 were
added 2026-08-12, after Sprint 1 shipped — their phases continue Sprint 1's
numbering (Phase 8 onward) rather than restarting, since later phases in
each sprint assume the mock infrastructure the earlier ones built, exactly
like Sprint 1's own phases do.

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

---

# Sprint 2 — Issue Management & Audit Monitoring

## Sprint Goal (Sprint 2)

Administrators can receive, investigate, and manage system issue reports
while maintaining accountability through audit logs.

| Backlog ID | Item | Sprint Tasks |
|---|---|---|
| PB-06 *(added — see Open Decision 4)* | Submit System Issue Report | Add a "Report Issue" button to selected pages, capture page/module automatically, submit the report to the database |
| PB-07 | View System Issue Reports | Create issue report list interface, retrieve issue reports from database, display issue summary and status, integrate interface with business logic |
| PB-08 | View Issue Details | Create issue details interface, display affected page/module, display issue description and screenshot, display user and submission details |
| PB-09 | Update Issue Status | Create issue status update interface, update issue status (Open/In Progress/Resolved), save administrator remarks, record action in audit log |
| PB-10 | Monitor Audit Log | Create audit log interface, retrieve audit records, display administrator activities, implement search and filtering |

**Sprint deliverables:** in-app issue reporting, report review interface,
report status management, audit log monitoring.

## Scope (Sprint 2)

Tables/entities newly owned by this module: `IssueReport` (new — nothing in
`CLAUDE.md`'s 5-module list owns issue reporting, so it lands here per Open
Decision 4 below, since PB-07/08/09 have nothing to review without it).

`AdminAuditLog` (owned since Sprint 1) is **generalized**, not replaced —
see Architecture Decision 6. This touches Sprint 1's already-shipped code
(`AdminAuditLogRepository`, `MockAdminAuditLogRepository`,
`AdminUserDetailScreen`'s status-history section, and their tests), not
just new files — Phase 8 must update those call sites, not only add new
ones.

Out of scope: automatic screen-capture for PB-08's "screenshot" (see Open
Decision 5 — attach-from-gallery instead); real Supabase wiring (mock-first,
same as Sprint 1 — Phase 14 outlines it, doesn't build it).

## Architecture Decisions (Sprint 2 — locked, do not re-litigate mid-implementation)

6. **`AdminAuditLog` becomes target-type-generic**, replacing
   `targetUserId: String` with `targetType: AdminAuditTargetType` (`{ user,
   issueReport }`) + `targetId: String`. `AdminAction` gains three new
   values for issue transitions — `issueMarkInProgress`, `issueMarkResolved`,
   `issueReopen` — mirroring how `suspend`/`reactivate` are specific verbs,
   not a generic "statusChanged". `getHistoryForUser(userId)` is renamed
   `getHistoryForTarget({targetType, targetId})`; a new
   `getAllEntries({filters})` is added for PB-10 (nothing in Sprint 1 needed
   a global, cross-target listing — Sprint 1's screens were always scoped to
   one user). One audit table still serves everything an admin does,
   continuing Sprint 1's Architecture Decision 5 rather than starting a
   second table — team decision, 2026-08-12 (see PROGRESS.md).
7. **Issue submission is user-facing, but the model/repository live in this
   module's `lib/data`/`lib/models`** (not a new "common" folder — this repo
   has no shared/common widget or data convention; cross-module reuse of a
   single file already happens elsewhere, e.g. Sprint 1 reusing
   `lib/features/trip/widgets/stat_tile.dart`). Only the `ReportIssueButton`
   widget gets placed on non-admin screens (Journal/Trip module files) —
   flag those edits as cross-module touches the same way Sprint 1 flagged
   `lib/features/auth/screens/login_screen.dart`.
8. **`updateStatus` is a composition**, exactly like Sprint 1's
   `suspendUser`/`reactivateUser`: update `IssueReport.status` +
   `IssueReport.adminRemarks` + write an `AdminAuditLog` entry, one
   repository call, not raw table access from the UI.

## Open Decisions (Sprint 2 — confirm before Phase 10)

4. **Where does issue-report submission belong?** Team decision, 2026-08-12:
   **this module's scope** (not deferred to another module/sprint) — PB-07
   would otherwise have no data to display. Recorded here because it's a
   scope expansion beyond the original Sprint 2 backlog table, the same way
   Sprint 1 flagged `AccountStatus.suspended` as an addition beyond its own
   initial contracts.
5. **PB-08's "screenshot"** — literal automatic screen-capture (grabbing
   the actual rendered pixels at the moment of the report) is real work
   (platform-specific capture APIs, then upload) disproportionate to a
   mock-first phase. **Recommended default: let the user attach an existing
   photo via `image_picker`** (already a dependency — used for trip cover
   photos), same upload path a screenshot would need anyway. Automatic
   capture is a Phase 14 (real-backend) stretch goal, not required for
   Sprint 2's Definition of Done. Flag if the team wants true auto-capture
   before this phase starts, since it changes `ReportIssueButton`'s design.
6. **Are administrator remarks required, like a suspend reason was in
   Sprint 1?** The backlog wording ("save administrator remarks") doesn't
   say required, unlike PB-04's explicit reason field. **Recommended
   default: optional** — resolving an issue doesn't carry the same
   accountability weight as suspending a user's account (Sprint 1's reason
   requirement came from a specific team decision about penalizing
   accounts, not from a general "always require text" rule). Revisit if the
   team wants parity with Sprint 1's suspend flow.

---

## Phase 8 — Recon & Contracts (Sprint 2, no feature code)

**Goal:** lock the new/changed interfaces, including the Sprint 1
`AdminAuditLog` migration, before any UI work starts.

**Tasks:**
1. Confirm Sprint 1's `AdminAuditLogRepository`/`AdminAuditLog` still match
   `docs/admin/PROGRESS.md` — this phase changes them, so start from what's
   actually shipped, not this document's original Phase 0 description.
2. Record Open Decisions 4–6 (resolved above) in `docs/admin/PROGRESS.md`.
3. Generalize `AdminAuditLog` (`lib/models/admin_audit_log.dart`) per
   Architecture Decision 6: `targetType: AdminAuditTargetType`, `targetId:
   String` (replaces `targetUserId`), `AdminAction` gains
   `issueMarkInProgress`, `issueMarkResolved`, `issueReopen`.
4. Update every existing call site for the renamed field/method:
   `MockAdminAccountActionsRepository` (pass `targetType: user`),
   `AdminUserDetailController`/`AdminUserDetailScreen` (call
   `getHistoryForTarget` instead of `getHistoryForUser`), and their tests.
   `flutter analyze`/`flutter test` must both still pass after this step —
   this is a refactor of shipped code, not just new additions.
5. Define `IssueReport` (`lib/models/issue_report.dart`): `reportId,
   submittedByUserId, page (String), description, screenshotUrl (String?),
   status (IssueReportStatus: open, inProgress, resolved), adminRemarks
   (String?), createdAt, updatedAt`.
6. Define `IssueReportRepository` (`lib/data/issue_report_repository.dart`,
   no implementation yet): `submitReport({userId, page, description,
   screenshotUrl})`, `getAllReports({IssueReportStatus? statusFilter})`,
   `getReportById(reportId)`, `updateStatus({adminUserId, reportId, status,
   String? remarks})` (composition, per Architecture Decision 8).
7. Add `AdminAuditLogRepository.getAllEntries({AdminAuditTargetType?
   targetTypeFilter, AdminAction? actionFilter, DateTimeRange? range})` for
   PB-10 — Sprint 1 never needed a global listing.

**Definition of Done:**
- [ ] `AdminAuditLog` generalized; all Sprint 1 call sites updated; existing
      Sprint 1 tests still pass unmodified in behavior (renamed API, same
      guarantees)
- [ ] `IssueReport`, `IssueReportRepository` defined
- [ ] `AdminAuditLogRepository.getAllEntries` defined
- [ ] Code compiles, `flutter analyze` clean

---

## Phase 9 — Mock Repositories (Sprint 2)

**Tasks:**
1. `MockIssueReportRepository` — in-memory list seeded with 3–5 sample
   reports spanning all three statuses and a couple of different `page`
   values, mirroring `MockAdminUserStore`'s seeding approach so Phase 10's
   list screen has something to show immediately.
2. Update `MockAdminAuditLogRepository` for the generalized shape
   (`getHistoryForTarget`, `getAllEntries`) — same file, extended, not
   replaced (still the single shared instance suspend/reactivate already
   write to).
3. Wire `IssueReportRepository` into `admin_repository_locator.dart`.

**Definition of Done:**
- [ ] `MockIssueReportRepository` implemented and unit-testable
- [ ] `MockAdminAuditLogRepository`'s existing (Sprint 1) tests still pass
      against the generalized shape
- [ ] Locator wires the new mock; still the one place mock vs. real is
      decided

---

## Phase 10 — PB-06 (added) + PB-07: Submit + View Issue Reports (mock)

**Tasks:**
1. `ReportIssueButton` (`lib/features/admin/widgets/`) — per Open Decision
   5, opens a form: description text field + optional `image_picker`
   attachment. `page`/module is passed in by the caller (each screen that
   places the button knows its own name), not inferred automatically —
   there's no route-introspection convention in this codebase to infer it
   from.
2. Place `ReportIssueButton` on a **small, representative set** of screens
   (e.g. `HomeScreen`, `TripViewScreen`) — the backlog says "selected
   pages", not every screen; picking 2–3 is enough to prove the flow works
   end-to-end. These are cross-module file edits (Journal/Trip module
   screens) — flag them in `PROGRESS.md` the same way Sprint 1 flagged
   editing `login_screen.dart`.
3. `AdminIssueReportListScreen` (`lib/features/admin/screens/`) — status
   badges, tap to open detail (Phase 11). Empty state when no reports
   exist, matching `AdminUserListScreen`'s precedent.
4. `IssueReportManagementController` — loading/error/data states, optional
   status filter.
5. Entry point on `AdminDashboardScreen`'s app bar (mirrors "Manage users"),
   since Sprint 1 already established that pattern for reaching sub-screens.

**Definition of Done:**
- [ ] Submitting a report from a traveler-facing screen creates an
      `IssueReport` an admin can see
- [ ] The list shows status per report
- [ ] Empty state has visible UI, not a blank list

---

## Phase 11 — PB-08: View Issue Details (mock)

**Tasks:**
1. `IssueReportDetailScreen` — full report: page/module, description,
   attached photo (if any), submitting user's `displayName`/`email` (fetch
   via `AdminUserDirectoryRepository.getUserById` — reuse Sprint 1's
   interface rather than duplicating a user lookup), submission timestamp.

**Definition of Done:**
- [ ] Tapping a report in Phase 10's list opens this screen with every
      field populated
- [ ] An unknown/deleted report id shows an error state with retry, not a
      crash (mirrors `AdminUserDetailScreen`'s precedent)

---

## Phase 12 — PB-09: Update Issue Status (mock)

**Tasks:**
1. Status-change control on `IssueReportDetailScreen` (e.g. three buttons
   or a segmented control for Open/In Progress/Resolved) + a remarks text
   field (optional, per Open Decision 6).
2. Calls `IssueReportRepository.updateStatus(...)` → refresh the screen →
   confirmation snackbar, mirroring Sprint 1's suspend/reactivate UX.
3. Verify the write lands in the generalized `AdminAuditLog`
   (`targetType: issueReport`) and is visible via `getHistoryForTarget`.

**Definition of Done:**
- [ ] Status change persists and is reflected immediately in the detail
      view and Phase 10's list
- [ ] An audit entry is recorded and independently verifiable via
      `AdminAuditLogRepository`

---

## Phase 13 — PB-10: Monitor Audit Log (mock)

**Tasks:**
1. `AuditLogScreen` — **global** view (every admin, every target type),
   distinct from Sprint 1's per-user history section. Uses
   `getAllEntries({filters})` from Phase 8.
2. Filtering: by target type (user/issue), action, and date range at
   minimum, per "implement search and filtering".
3. Entry point on `AdminDashboardScreen`'s app bar.

**Definition of Done:**
- [ ] Every audit entry from both Sprint 1 (suspend/reactivate) and Sprint
      2 (issue status changes) appears in one place
- [ ] At least one filter dimension demonstrably narrows the results

---

## Phase 14 — Real Backend (Sprint 2, outline only — later sprint)

Not built in Sprint 2; recorded so Phase 8's contracts don't have to change
later.

- SQL migration: `issue_reports` table.
- SQL migration: `admin_audit_log`'s shape change (`targetUserId` →
  `targetType` + `targetId`) — if Sprint 1's Phase 7 already shipped the
  original column to a real table by the time this runs, this is an `ALTER`
  + backfill, not a fresh `CREATE`. Plan the migration accordingly; don't
  assume a clean slate.
- Storage bucket for issue-report attachments, mirroring the pattern
  `tripjournal_schema.sql`'s photo columns already use (URL stored in the
  table, bytes in Storage).
- RLS: `issue_reports` readable by the submitting user (their own rows
  only) or any `role = admin` caller; `status`/`adminRemarks` writable only
  by admins.
- True automatic screen-capture for PB-08 (Open Decision 5's deferred
  stretch goal), if the team still wants it once real infrastructure
  exists.
- Swap `IssueReportRepository`/generalized `AdminAuditLogRepository` from
  `Mock*` to `Supabase*` in `admin_repository_locator.dart`.

---

# Sprint 3 — AI & System Monitoring

## Sprint Goal (Sprint 3)

Administrators can monitor AI services and system health to ensure
reliable application performance.

| Backlog ID | Item | Sprint Tasks |
|---|---|---|
| PB-11 | Monitor System Error Logs | Create system error log interface, retrieve system error records, display error details and severity, implement filtering by module and severity |
| PB-12 | Monitor AI Processing Requests | Create AI monitoring interface, retrieve AI request history, display processing status and execution time, filter AI requests by status |
| PB-13 | Monitor Failed AI Requests | Retrieve failed AI requests, display failure details, display affected user and module, implement retry or investigation workflow |
| PB-14 | View System Health Dashboard | Display service health indicators, display AI service status, display database connectivity status, display API availability |
| PB-15 | Generate System Monitoring Reports | Create report generation interface, export monitoring reports, summarise AI/error/issue statistics, download report in PDF/CSV format |

**Sprint deliverables:** system error monitoring, AI request monitoring,
failed AI request handling, a system health dashboard, exportable
monitoring reports.

## Scope (Sprint 3)

Tables/entities newly owned by this module: `SystemErrorLog`,
`AiRequestLog` (both new).

**Capture mechanisms live partly outside this module's files** — see
Architecture Decision 9. This sprint cannot be built purely inside
`lib/features/admin/` the way Sprint 1 mostly was; expect edits to
`main.dart` and the Journal/Trip modules' AI locator files.

Out of scope / constrained by mock-first status: PB-14's "database
connectivity status" has nothing real to check yet — Sprint 1's own Phase 7
(real Supabase backend for the *admin* module itself) isn't built, let
alone a general apphealth check. See Open Decision 7.

## Architecture Decisions (Sprint 3 — locked, do not re-litigate mid-implementation)

9. **Error/AI-request capture happens at existing call sites, via a thin
   wrapper, not a rewrite of the AI services themselves.** `SystemErrorLog`
   entries are written from one global hook in `main.dart`
   (`runZonedGuarded` + `FlutterError.onError`), not scattered `try/catch`
   blocks added throughout the app. `AiRequestLog` entries are written by
   wrapping each of the three existing AI locators
   (`daily_advice_locator.dart`, `food_detection_locator.dart`,
   `trip_summary_locator.dart`) with a logging decorator that times the
   call and records status before delegating to the real
   `GeminiXService`/`MockXService` — the underlying service classes
   themselves are untouched.
10. **PB-13's "retry" re-invokes the same underlying AI call**, it isn't a
    new retry-queue/backoff system — `AiRequestLog` already has enough
    (type, original params if feasible to store, or just "try the action
    again from the UI that triggered it") to satisfy "retry or
    investigation workflow" without new infrastructure.
11. **PB-15 reuses the existing PDF export pattern**
    (`lib/features/journal/pdf/journal_pdf_export.dart`, built on the
    `printing` package, already a dependency) rather than adding a new PDF
    library. CSV export is a plain string-building function — no new
    dependency needed.

## Open Decisions (Sprint 3 — confirm before Phase 19)

7. **What can "database connectivity status" and "API availability"
   actually mean while the app is still mock-first?** Recommended default:
   `SystemHealthScreen` shows **"N/A — mock backend in use"** for any
   indicator with no real infrastructure behind it yet (database
   connectivity chief among them), rather than fabricating a fake "green"
   status that would be actively misleading. The Gemini AI key check *is*
   real and buildable now (`GEMINI_API_KEY` set in `.env` or not). Revisit
   once Sprint 1's Phase 7 (or a later real-backend phase) actually gives
   this module something to ping.
8. **Severity levels for `SystemErrorLog`.** Not specified in the backlog
   wording beyond "severity". Recommended default: a four-value enum
   (`info, warning, error, fatal`), matching common logging-framework
   convention and giving PB-11's "filter by severity" something meaningful
   to filter on without over-engineering a bespoke scale.

---

## Phase 15 — Recon & Contracts (Sprint 3, no feature code)

**Tasks:**
1. Record Open Decisions 7–8 (resolved above) in `docs/admin/PROGRESS.md`.
2. Define `SystemErrorLog` (`lib/models/system_error_log.dart`): `logId,
   module (String), severity (ErrorSeverity: info, warning, error, fatal),
   message, stackTrace (String?), createdAt`.
3. Define `AiRequestLog` (`lib/models/ai_request_log.dart`): `logId,
   userId, requestType (AiRequestType: dailyAdvice, foodDetection,
   tripSummary), status (AiRequestStatus: succeeded, failed),
   executionTimeMs (int), errorMessage (String?), createdAt`.
4. Define `SystemErrorLogRepository` (`recordError`, `getAllErrors({module,
   severity})`) and `AiRequestLogRepository` (`recordRequest`,
   `getAllRequests({status})`, `getFailedRequests()`) in `lib/data/` — no
   implementations yet.
5. Confirm the three AI locator files' current shape
   (`daily_advice_locator.dart`, `food_detection_locator.dart`,
   `trip_summary_locator.dart`) — Phase 18 wraps them, so start from what's
   actually there, not assumptions.

**Definition of Done:**
- [ ] `SystemErrorLog`, `AiRequestLog` defined
- [ ] `SystemErrorLogRepository`, `AiRequestLogRepository` defined, no
      implementations yet
- [ ] Code compiles

---

## Phase 16 — Mock Repositories (Sprint 3)

**Tasks:**
1. `MockSystemErrorLogRepository` — seeded with a handful of sample errors
   across different modules/severities.
2. `MockAiRequestLogRepository` — seeded with a mix of succeeded/failed
   sample requests across all three `AiRequestType` values.
3. Wire both into `admin_repository_locator.dart`.

**Definition of Done:**
- [ ] Both mocks implemented and unit-testable
- [ ] Locator wires them; still the one place mock vs. real is decided

---

## Phase 17 — PB-11: Monitor System Error Logs (mock)

**Tasks:**
1. Global error hook in `main.dart` per Architecture Decision 9 — writes to
   `SystemErrorLogRepository`. This is a cross-module touch (core app
   entry point, not `lib/features/admin/`) — flag it in `PROGRESS.md`.
2. `SystemErrorLogScreen` — list with severity badges, filter by
   module/severity.

**Definition of Done:**
- [ ] An error thrown anywhere in the app (mock-triggerable for testing)
      appears in the log
- [ ] Filtering by module and by severity both demonstrably narrow results

---

## Phase 18 — PB-12 + PB-13: AI Request Monitoring (mock)

**Tasks:**
1. Logging decorator wrapping each of the three AI locators, per
   Architecture Decision 9 — records type, status, execution time. Cross-
   module touch (Journal/Trip module files) — flag in `PROGRESS.md`.
2. `AiRequestMonitoringScreen` — status + execution time per request,
   filter by status.
3. Failed-requests view (filtered `AiRequestLog` list) + a retry action per
   Architecture Decision 10.

**Definition of Done:**
- [ ] A real (mock) AI call appears in the log with status and timing
- [ ] Failed requests are visibly distinguishable and individually
      retryable

---

## Phase 19 — PB-14: System Health Dashboard (mock)

**Tasks:**
1. `SystemHealthScreen` — per Open Decision 7: real check for Gemini key
   configuration; "N/A — mock backend in use" placeholders for
   database/API availability until real infrastructure exists.

**Definition of Done:**
- [ ] Screen renders without fabricating a misleading "healthy" status for
      anything not actually checked

---

## Phase 20 — PB-15: Generate System Monitoring Reports (mock)

**Tasks:**
1. `MonitoringReportScreen` — pick a date range, generate a summary from
   Phases 17–19's data (error counts by severity, AI request counts by
   status, issue counts by status from Sprint 2).
2. PDF export via the existing `printing`-based pattern (Architecture
   Decision 11); CSV export via a plain formatter, no new dependency.

**Definition of Done:**
- [ ] A generated report reflects the current mock data accurately
- [ ] Both PDF and CSV export produce a downloadable file

---

## Phase 21 — Real Backend (Sprint 3, outline only — later sprint)

Not built in Sprint 3; recorded so Phase 15's contracts don't have to
change later.

- SQL migrations: `system_error_logs`, `ai_request_logs`.
- The `main.dart` error hook and the three AI-locator wrappers need to
  write to the real tables, service-role or RLS-scoped as appropriate —
  design the actual write path (client-direct vs. Edge Function) once
  Sprint 1's Phase 7 establishes the real-backend pattern this module
  should follow.
- `SystemHealthScreen`'s real checks: an actual lightweight Supabase query
  for DB connectivity, an actual Gemini API reachability check (not just
  "is a key configured") — only meaningful once Sprint 1's Phase 7 exists.
- Swap both new repositories from `Mock*` to `Supabase*` in
  `admin_repository_locator.dart`.

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
- **Phase 8's `AdminAuditLog` generalization is a refactor of shipped
  Sprint 1 code, not purely additive** — every existing call site
  (`MockAdminAccountActionsRepository`, `AdminUserDetailScreen`, their
  tests) must be updated in the same phase, or the module stops compiling.
  Budget real time for this, don't treat it as a quick rename.
- **Sprint 3 is not self-contained inside `lib/features/admin/`.** The
  error hook (`main.dart`) and the AI-logging wrappers (Journal/Trip
  modules' locator files) are genuine cross-module edits, more so than
  anything in Sprint 1 or 2 — flag each one explicitly in `PROGRESS.md`,
  same discipline as every other cross-module change in this plan.
- **Open Decision 7 (mock-first health checks)**: resist the temptation to
  make `SystemHealthScreen` show green/healthy for things that were never
  actually checked, just to make the screen look complete. An honest
  "N/A — mock backend in use" is correct; a fabricated "Connected" is not.
- **Backlog ID collision, not introduced by this plan**: Sprint 1 already
  uses **PB-10** for "Logout Administrator"; the Sprint 2 backlog table
  (as given to this plan) independently assigns **PB-10** to "Monitor Audit
  Log" — two unrelated features sharing one id. This plan keeps both ids as
  given rather than silently renumbering either (renumbering could
  desynchronize this document from whatever tracker/spreadsheet the team
  is using), but every reference to "PB-10" from here on must specify which
  sprint, or say the feature name, not the bare id. Worth fixing at the
  source (the team's backlog tracker) when convenient.

## Traceability Reference

| Sprint Item | Phase |
|---|---|
| PB-01 | Phase 2 (mock) / Phase 7 (real) |
| PB-02 | Phase 3 (mock) / Phase 7 (real) |
| PB-03 | Phase 4 (mock) / Phase 7 (real) |
| PB-04 | Phase 5 (mock) / Phase 7 (real) |
| PB-05 | Phase 5 (mock) / Phase 7 (real) |
| PB-10 | Phase 6 (mock) / Phase 7 (real) |
| PB-06 *(Sprint 2, added)* | Phase 10 (mock) / Phase 14 (real) |
| PB-07 *(Sprint 2)* | Phase 10 (mock) / Phase 14 (real) |
| PB-08 *(Sprint 2)* | Phase 11 (mock) / Phase 14 (real) |
| PB-09 *(Sprint 2)* | Phase 12 (mock) / Phase 14 (real) |
| PB-10 *(Sprint 2 — distinct item, reused ID)* | Phase 13 (mock) / Phase 14 (real) |
| PB-11 *(Sprint 3)* | Phase 17 (mock) / Phase 21 (real) |
| PB-12 *(Sprint 3)* | Phase 18 (mock) / Phase 21 (real) |
| PB-13 *(Sprint 3)* | Phase 18 (mock) / Phase 21 (real) |
| PB-14 *(Sprint 3)* | Phase 19 (mock) / Phase 21 (real) |
| PB-15 *(Sprint 3)* | Phase 20 (mock) / Phase 21 (real) |