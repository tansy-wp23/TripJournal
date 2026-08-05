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

1. **Credential mechanism** — default taken: administrators authenticate via
   the existing `AuthRepository.signInWithGoogle()` + a `Profile.role ==
   admin` check. No new auth repository was added in this phase. If the
   team instead wants separate staff email+password credentials, Phase 2
   needs to fork before the login screen is built, not after.
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