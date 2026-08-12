import 'admin_access_attempt_log_repository.dart';
import 'admin_account_actions_repository.dart';
import 'admin_audit_log_repository.dart';
import 'admin_dashboard_repository.dart';
import 'admin_user_directory_repository.dart';
import 'auth_repository.dart';
import 'mock_admin_access_attempt_log_repository.dart';
import 'mock_admin_account_actions_repository.dart';
import 'mock_admin_audit_log_repository.dart';
import 'mock_admin_dashboard_repository.dart';
import 'mock_admin_user_directory_repository.dart';
import 'mock_admin_user_store.dart';
import 'mock_auth_repository.dart';

/// The one place the app resolves its admin repositories from — mirrors
/// `repository_locator.dart` / `user_management_repository_locator.dart` so
/// the Phase 7 swap to Supabase is a one-line change here.
///
/// All four are wired to mocks for Phases 1–6, and share a single
/// [MockAdminUserStore] so a suspend/reactivate action taken through
/// [adminAccountActionsRepository] is immediately reflected in
/// [adminUserDirectoryRepository] search results and
/// [adminDashboardRepository] counts.
final MockAdminUserStore _adminUserStore = MockAdminUserStore();

/// Sign-in for the admin flow, per Architecture Decision 2 / `PROGRESS.md`
/// Open Decision 1: same `AuthRepository` interface and `MockAuthRepository`
/// implementation the traveler flow uses — no new auth repository type.
///
/// This is a **separate instance** of that same mock class, seeded with the
/// admin persona's id/email (matching `MockAdminUserStore`'s `admin-001`
/// row) rather than the traveler flow's default `user-001`. That split only
/// exists because `MockAuthRepository` can simulate exactly one signed-in
/// persona per instance — the real Supabase Auth backend (Phase 7) is one
/// shared service for both flows, so this collapses back to a single
/// `authRepository` instance then; see `docs/admin/PROGRESS.md` Phase 2.
final AuthRepository adminAuthRepository = MockAuthRepository(
  mockUserId: 'admin-001',
  mockEmail: 'admin@tripjournal.dev',
);

final AdminUserDirectoryRepository adminUserDirectoryRepository =
    MockAdminUserDirectoryRepository(_adminUserStore);

final AdminDashboardRepository adminDashboardRepository =
    MockAdminDashboardRepository(_adminUserStore);

final AdminAuditLogRepository adminAuditLogRepository =
    MockAdminAuditLogRepository();

final AdminAccountActionsRepository adminAccountActionsRepository =
    MockAdminAccountActionsRepository(
  store: _adminUserStore,
  auditLogRepository: adminAuditLogRepository as MockAdminAuditLogRepository,
);

/// Records rejected admin sign-in attempts (`docs/admin/PROGRESS.md`,
/// post-Phase-3 addition) — a separate table from [adminAuditLogRepository],
/// see [AdminAccessAttemptLog]'s doc comment for why.
final AdminAccessAttemptLogRepository adminAccessAttemptLogRepository =
    MockAdminAccessAttemptLogRepository();