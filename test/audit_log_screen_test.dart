import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/admin_audit_log_repository.dart';
import 'package:tripjournal/data/mock_admin_access_attempt_log_repository.dart';
import 'package:tripjournal/data/mock_admin_account_actions_repository.dart';
import 'package:tripjournal/data/mock_admin_audit_log_repository.dart';
import 'package:tripjournal/data/mock_admin_user_directory_repository.dart';
import 'package:tripjournal/data/mock_admin_user_store.dart';
import 'package:tripjournal/data/mock_issue_report_repository.dart';
import 'package:tripjournal/features/admin/controller/admin_user_detail_controller.dart';
import 'package:tripjournal/features/admin/controller/audit_log_controller.dart';
import 'package:tripjournal/features/admin/controller/issue_report_detail_controller.dart';
import 'package:tripjournal/features/admin/screens/admin_user_detail_screen.dart';
import 'package:tripjournal/features/admin/screens/audit_log_screen.dart';
import 'package:tripjournal/features/admin/screens/issue_report_detail_screen.dart';
import 'package:tripjournal/models/admin_audit_log.dart';

void main() {
  late MockAdminAuditLogRepository repository;

  // Against the default seeded MockAdminUserStore/MockIssueReportRepository
  // — same real-looking names ("Alice Tan", "Admin Account") every other
  // admin screen's tests already resolve against. Shared instances (not
  // built fresh inside AuditLogController) so a test that also navigates
  // into AdminUserDetailScreen/IssueReportDetailScreen can hand those
  // pushed screens the exact same seeded data via
  // AuditLogScreen's builder-override params.
  final userDirectoryRepository = MockAdminUserDirectoryRepository(MockAdminUserStore());
  final issueReportRepository =
      MockIssueReportRepository(auditLogRepository: MockAdminAuditLogRepository());

  AuditLogController buildController(AdminAuditLogRepository auditLogRepository) {
    return AuditLogController(
      auditLogRepository,
      userDirectoryRepository,
      issueReportRepository,
    );
  }

  Future<void> seedThreeEntries() async {
    await repository.recordAction(AdminAuditLog(
      logId: repository.nextLogId(),
      adminUserId: 'admin-001',
      targetType: AdminAuditTargetType.user,
      targetId: 'user-101',
      action: AdminAction.suspend,
      reason: 'Reported for spam',
      createdAt: DateTime(2026, 1, 1),
    ));
    await repository.recordAction(AdminAuditLog(
      logId: repository.nextLogId(),
      adminUserId: 'admin-001',
      targetType: AdminAuditTargetType.user,
      targetId: 'user-101',
      action: AdminAction.reactivate,
      createdAt: DateTime(2026, 1, 2),
    ));
    await repository.recordAction(AdminAuditLog(
      logId: repository.nextLogId(),
      adminUserId: 'admin-002',
      targetType: AdminAuditTargetType.issueReport,
      targetId: 'issue-1',
      action: AdminAction.issueMarkResolved,
      createdAt: DateTime(2026, 1, 3),
    ));
  }

  setUp(() {
    repository = MockAdminAuditLogRepository();
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    AuditLogController controller, {
    bool withNavigationTargets = false,
  }) async {
    // withNavigationTargets wires AuditLogScreen's builder overrides so
    // tapping into AdminUserDetailScreen/IssueReportDetailScreen resolves
    // against this same repository, rather than the real (Phase 7/14)
    // Supabase-backed global — see AdminDashboardScreen's
    // userDetailScreenBuilder doc comment for why the override exists.
    final auditLogRepositoryForDetail = MockAdminAuditLogRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [auditLogControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          home: withNavigationTargets
              ? AuditLogScreen(
                  userDetailScreenBuilder: (userId) => AdminUserDetailScreen(
                    userId: userId,
                    controller: AdminUserDetailController(
                      userDirectoryRepository,
                      auditLogRepositoryForDetail,
                      MockAdminAccessAttemptLogRepository(),
                    ),
                    accountActionsRepository: MockAdminAccountActionsRepository(
                      store: MockAdminUserStore(),
                      auditLogRepository: auditLogRepositoryForDetail,
                    ),
                  ),
                  issueDetailScreenBuilder: (reportId) => IssueReportDetailScreen(
                    reportId: reportId,
                    controller: IssueReportDetailController(
                      issueReportRepository,
                      userDirectoryRepository,
                      auditLogRepositoryForDetail,
                    ),
                    issueReportRepositoryOverride: issueReportRepository,
                  ),
                )
              : const AuditLogScreen(),
        ),
      ),
    );
    await tester.pump(); // triggers the post-frame load callback
    await tester.pumpAndSettle();
  }

  group('AuditLogScreen', () {
    testWidgets('loads and shows every seeded entry from both target types',
        (tester) async {
      await seedThreeEntries();
      await pumpScreen(tester, buildController(repository));

      expect(find.byKey(const Key('admin-audit-log-results')), findsOneWidget);
      expect(find.text('Suspended'), findsOneWidget);
      expect(find.text('Reactivated'), findsOneWidget);
      expect(find.text('Marked Resolved'), findsOneWidget);
    });

    testWidgets('shows the reason when one was recorded', (tester) async {
      await seedThreeEntries();
      await pumpScreen(tester, buildController(repository));

      expect(find.text('Reported for spam'), findsOneWidget);
    });

    testWidgets('tapping a user-target entry opens that user\'s detail '
        'screen', (tester) async {
      await repository.recordAction(AdminAuditLog(
        logId: repository.nextLogId(),
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.user,
        targetId: 'user-101', // seeded as Alice Tan in MockAdminUserStore
        action: AdminAction.suspend,
        createdAt: DateTime.now(),
      ));
      await pumpScreen(tester, buildController(repository), withNavigationTargets: true);

      await tester.tap(find.text('Suspended'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminUserDetailScreen), findsOneWidget);
      expect(find.text('Alice Tan'), findsOneWidget);
    });

    testWidgets('tapping an issue-report-target entry opens that report\'s '
        'detail screen', (tester) async {
      await repository.recordAction(AdminAuditLog(
        logId: repository.nextLogId(),
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.issueReport,
        targetId: 'issue-001', // seeded report in MockIssueReportRepository
        action: AdminAction.issueMarkResolved,
        createdAt: DateTime.now(),
      ));
      await pumpScreen(tester, buildController(repository), withNavigationTargets: true);

      await tester.tap(find.text('Marked Resolved'));
      await tester.pumpAndSettle();

      expect(find.byType(IssueReportDetailScreen), findsOneWidget);
    });

    testWidgets('tapping an entry whose target no longer resolves shows '
        'that screen\'s own error state, not a crash', (tester) async {
      await repository.recordAction(AdminAuditLog(
        logId: repository.nextLogId(),
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.issueReport,
        targetId: 'issue-since-deleted',
        action: AdminAction.issueMarkResolved,
        createdAt: DateTime.now(),
      ));
      await pumpScreen(tester, buildController(repository), withNavigationTargets: true);

      await tester.tap(find.text('Marked Resolved'));
      await tester.pumpAndSettle();

      expect(find.byType(IssueReportDetailScreen), findsOneWidget);
      expect(find.byKey(const Key('admin-issue-detail-retry')), findsOneWidget);
    });

    testWidgets('tapping the User target-type chip narrows to user entries',
        (tester) async {
      await seedThreeEntries();
      await pumpScreen(tester, buildController(repository));

      await tester.tap(find.byKey(const Key('admin-audit-target-type-user')));
      await tester.pumpAndSettle();

      expect(find.text('Suspended'), findsOneWidget);
      expect(find.text('Reactivated'), findsOneWidget);
      expect(find.text('Marked Resolved'), findsNothing);
    });

    testWidgets('tapping All targets after a filter restores the full list',
        (tester) async {
      await seedThreeEntries();
      await pumpScreen(tester, buildController(repository));

      await tester.tap(find.byKey(const Key('admin-audit-target-type-user')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'All targets'));
      await tester.pumpAndSettle();

      expect(find.text('Suspended'), findsOneWidget);
      expect(find.text('Marked Resolved'), findsOneWidget);
    });

    testWidgets('the clear-filters action appears only once a filter is '
        'active, and resets it', (tester) async {
      await seedThreeEntries();
      await pumpScreen(tester, buildController(repository));

      expect(find.byKey(const Key('admin-audit-log-clear-filters')), findsNothing);

      await tester.tap(find.byKey(const Key('admin-audit-target-type-user')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin-audit-log-clear-filters')), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin-audit-log-clear-filters')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-audit-log-clear-filters')), findsNothing);
      expect(find.text('Marked Resolved'), findsOneWidget);
    });

    testWidgets('no entries at all shows the empty state, not a blank list',
        (tester) async {
      await pumpScreen(tester, buildController(repository));

      expect(find.byKey(const Key('admin-audit-log-empty-state')), findsOneWidget);
      expect(find.text('No audit entries have been recorded yet.'), findsOneWidget);
      expect(find.byKey(const Key('admin-audit-log-results')), findsNothing);
    });

    testWidgets('a filter matching nobody shows a filter-specific empty '
        'state', (tester) async {
      await repository.recordAction(AdminAuditLog(
        logId: repository.nextLogId(),
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.user,
        targetId: 'user-101',
        action: AdminAction.suspend,
        createdAt: DateTime.now(),
      ));
      await pumpScreen(tester, buildController(repository));

      await tester.tap(find.byKey(const Key('admin-audit-target-type-issueReport')));
      await tester.pumpAndSettle();

      expect(find.text('No audit entries match these filters.'), findsOneWidget);
    });

    testWidgets('a failing repository shows an error with a retry button',
        (tester) async {
      await pumpScreen(tester, buildController(_FailingAuditLogRepository()));

      expect(find.byKey(const Key('admin-audit-log-retry')), findsOneWidget);
    });
  });
}

class _FailingAuditLogRepository implements AdminAuditLogRepository {
  @override
  Future<void> recordAction(AdminAuditLog entry) async {}

  @override
  Future<List<AdminAuditLog>> getHistoryForTarget({
    required AdminAuditTargetType targetType,
    required String targetId,
  }) async =>
      [];

  @override
  Future<List<AdminAuditLog>> getAllEntries({
    AdminAuditTargetType? targetTypeFilter,
    AdminAction? actionFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    throw Exception('mock backend unreachable');
  }
}
