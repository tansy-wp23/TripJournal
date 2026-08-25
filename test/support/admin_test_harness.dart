import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tripjournal/data/mock_admin_access_attempt_log_repository.dart';
import 'package:tripjournal/data/mock_admin_account_actions_repository.dart';
import 'package:tripjournal/data/mock_admin_audit_log_repository.dart';
import 'package:tripjournal/data/mock_admin_dashboard_repository.dart';
import 'package:tripjournal/data/mock_admin_user_directory_repository.dart';
import 'package:tripjournal/data/mock_admin_user_store.dart';
import 'package:tripjournal/data/mock_auth_repository.dart';
import 'package:tripjournal/data/mock_issue_report_repository.dart';
import 'package:tripjournal/data/mock_ai_request_log_repository.dart';
import 'package:tripjournal/data/mock_system_error_log_repository.dart';
import 'package:tripjournal/features/admin/controller/admin_auth_controller.dart';
import 'package:tripjournal/features/admin/controller/admin_dashboard_controller.dart';
import 'package:tripjournal/features/admin/controller/admin_user_detail_controller.dart';
import 'package:tripjournal/features/admin/controller/admin_user_management_controller.dart';
import 'package:tripjournal/features/admin/controller/ai_request_monitoring_controller.dart';
import 'package:tripjournal/features/admin/controller/audit_log_controller.dart';
import 'package:tripjournal/features/admin/controller/failed_ai_requests_controller.dart';
import 'package:tripjournal/features/admin/controller/issue_report_detail_controller.dart';
import 'package:tripjournal/features/admin/controller/issue_report_management_controller.dart';
import 'package:tripjournal/features/admin/controller/monitoring_report_controller.dart';
import 'package:tripjournal/features/admin/controller/system_error_log_controller.dart';

/// Owns the mock-admin resources used by an admin widget test.
///
/// Mirrors `AuthTestHarness` (`test/support/auth_test_harness.dart`) and
/// exists for the same reason: since Phase 7/14/21
/// (`ADMIN_MODULE_IMPLEMENTATION_PLAN.md`) wired `admin_repository_locator.dart`
/// to the real Supabase implementations, admin widget tests can no longer
/// rely on the locator's globals resolving to mocks — a bare
/// `ProviderScope(child: ...)` would try to reach a live Supabase instance.
/// [wrap] overrides every one of the module's nine top-level
/// `ChangeNotifierProvider`s with controllers built from a single shared
/// [MockAdminUserStore] (seeded identically to what the real locator's
/// mocks used to provide by default), so existing assertions about
/// "default seed counts" keep holding. [systemErrorLogController],
/// [aiRequestMonitoringController], [failedAiRequestsController], and
/// [monitoringReportController] are the exceptions to the "seeded
/// identically" part — since Phase 21 the real locator backs
/// `systemErrorLogRepository`/`aiRequestLogRepository` with
/// `system_error_logs`/`ai_request_logs` tables that start empty for every
/// real account, so there's no fixed default-seed count to match here the
/// way the other five repositories' mocks mirror a real table's starting
/// rows; [monitoringReportController] draws on those two plus
/// [issueReportRepository] (the harness's mock, not
/// the real locator's Supabase-backed one).
///
/// `AdminUserDetailScreen` / `IssueReportDetailScreen` / `ReportIssueButton`
/// aren't reachable through provider overrides at all — Phase 4/10 chose to
/// construct their controllers locally per-instance rather than resolve
/// them from a global provider (see those screens' own doc comments), so
/// they take a test-only `controller`/repository constructor override
/// instead. Use this harness's exposed repositories
/// ([userDirectoryRepository], [auditLogRepository], [accountActionsRepository],
/// [issueReportRepository], [accessAttemptLogRepository]) to build the
/// matching controller/repository for those three widgets directly.
final class AdminTestHarness {
  AdminTestHarness()
    : userStore = MockAdminUserStore(),
      auditLogRepository = MockAdminAuditLogRepository(),
      accessAttemptLogRepository = MockAdminAccessAttemptLogRepository(),
      systemErrorLogRepository = MockSystemErrorLogRepository(),
      aiRequestLogRepository = MockAiRequestLogRepository() {
    userDirectoryRepository = MockAdminUserDirectoryRepository(userStore);
    dashboardRepository = MockAdminDashboardRepository(userStore);
    accountActionsRepository = MockAdminAccountActionsRepository(
      store: userStore,
      auditLogRepository: auditLogRepository,
    );
    issueReportRepository = MockIssueReportRepository(
      auditLogRepository: auditLogRepository,
    );
    authRepository = MockAuthRepository(
      mockUserId: 'admin-001',
      mockEmail: 'admin@tripjournal.dev',
    );

    authController = AdminAuthController(
      authRepository,
      userDirectoryRepository,
      accessAttemptLogRepository,
    );
    dashboardController = AdminDashboardController(
      dashboardRepository,
      accessAttemptLogRepository,
    );
    userManagementController = AdminUserManagementController(
      userDirectoryRepository,
    );
    auditLogController = AuditLogController(
      auditLogRepository,
      userDirectoryRepository,
      issueReportRepository,
    );
    issueReportManagementController = IssueReportManagementController(
      issueReportRepository,
    );
    systemErrorLogController = SystemErrorLogController(systemErrorLogRepository);
    aiRequestMonitoringController = AiRequestMonitoringController(aiRequestLogRepository);
    failedAiRequestsController = FailedAiRequestsController(aiRequestLogRepository);
    monitoringReportController = MonitoringReportController(
      systemErrorLogRepository,
      aiRequestLogRepository,
      issueReportRepository,
    );
  }

  final MockAdminUserStore userStore;
  final MockAdminAuditLogRepository auditLogRepository;
  final MockAdminAccessAttemptLogRepository accessAttemptLogRepository;
  final MockSystemErrorLogRepository systemErrorLogRepository;
  final MockAiRequestLogRepository aiRequestLogRepository;
  late final MockAdminUserDirectoryRepository userDirectoryRepository;
  late final MockAdminDashboardRepository dashboardRepository;
  late final MockAdminAccountActionsRepository accountActionsRepository;
  late final MockIssueReportRepository issueReportRepository;
  late final MockAuthRepository authRepository;

  late final AdminAuthController authController;
  late final AdminDashboardController dashboardController;
  late final AdminUserManagementController userManagementController;
  late final AuditLogController auditLogController;
  late final IssueReportManagementController issueReportManagementController;
  late final SystemErrorLogController systemErrorLogController;
  late final AiRequestMonitoringController aiRequestMonitoringController;
  late final FailedAiRequestsController failedAiRequestsController;
  late final MonitoringReportController monitoringReportController;

  /// A ready-to-use [AdminUserDetailController], built from this harness's
  /// shared mocks — pass to `AdminUserDetailScreen(controller: ...)`.
  AdminUserDetailController userDetailController() => AdminUserDetailController(
    userDirectoryRepository,
    auditLogRepository,
    accessAttemptLogRepository,
  );

  /// A ready-to-use [IssueReportDetailController] — pass to
  /// `IssueReportDetailScreen(controller: ...)`.
  IssueReportDetailController issueReportDetailController() =>
      IssueReportDetailController(
        issueReportRepository,
        userDirectoryRepository,
        auditLogRepository,
      );

  /// All five provider overrides, exposed separately from [wrap] so a
  /// caller needing extra `MaterialApp` setup (e.g.
  /// `responsive_layout_test.dart`'s text-scaling `builder`) can build its
  /// own `ProviderScope` around the same overrides instead of duplicating
  /// this list.
  // Riverpod's own `Override` type isn't part of its public API surface
  // (and would collide with `dart:core`'s unrelated `Override` — the
  // `@override` annotation class — if named explicitly), so this is left
  // inferred rather than spelled out, the same way `ProviderScope(overrides:
  // [...])` call sites never name it either.
  // ignore: strict_top_level_inference
  get overrides => [
    adminAuthControllerProvider.overrideWith(
      (ref) => authController,
      disposeNotifier: false,
    ),
    adminDashboardControllerProvider.overrideWith(
      (ref) => dashboardController,
      disposeNotifier: false,
    ),
    adminUserManagementControllerProvider.overrideWith(
      (ref) => userManagementController,
      disposeNotifier: false,
    ),
    auditLogControllerProvider.overrideWith(
      (ref) => auditLogController,
      disposeNotifier: false,
    ),
    issueReportManagementControllerProvider.overrideWith(
      (ref) => issueReportManagementController,
      disposeNotifier: false,
    ),
    systemErrorLogControllerProvider.overrideWith(
      (ref) => systemErrorLogController,
      disposeNotifier: false,
    ),
    aiRequestMonitoringControllerProvider.overrideWith(
      (ref) => aiRequestMonitoringController,
      disposeNotifier: false,
    ),
    failedAiRequestsControllerProvider.overrideWith(
      (ref) => failedAiRequestsController,
      disposeNotifier: false,
    ),
    monitoringReportControllerProvider.overrideWith(
      (ref) => monitoringReportController,
      disposeNotifier: false,
    ),
  ];

  Widget wrap(Widget home) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: home),
  );

  Future<void> signIn() => authController.signInWithGoogle();

  void dispose() {
    authController.dispose();
    dashboardController.dispose();
    userManagementController.dispose();
    auditLogController.dispose();
    issueReportManagementController.dispose();
    systemErrorLogController.dispose();
    aiRequestMonitoringController.dispose();
    failedAiRequestsController.dispose();
    monitoringReportController.dispose();
  }
}
