import 'admin_account_actions_repository.dart';
import 'admin_audit_log_repository.dart';
import 'admin_dashboard_repository.dart';
import 'admin_user_directory_repository.dart';
import 'mock_admin_account_actions_repository.dart';
import 'mock_admin_audit_log_repository.dart';
import 'mock_admin_dashboard_repository.dart';
import 'mock_admin_user_directory_repository.dart';
import 'mock_admin_user_store.dart';

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