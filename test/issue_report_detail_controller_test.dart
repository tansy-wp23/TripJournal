import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_admin_audit_log_repository.dart';
import 'package:tripjournal/data/mock_admin_user_directory_repository.dart';
import 'package:tripjournal/data/mock_admin_user_store.dart';
import 'package:tripjournal/data/mock_issue_report_repository.dart';
import 'package:tripjournal/features/admin/controller/issue_report_detail_controller.dart';
import 'package:tripjournal/models/admin_audit_log.dart';
import 'package:tripjournal/models/issue_report.dart';

void main() {
  late MockAdminUserStore userStore;
  late MockAdminUserDirectoryRepository userDirectoryRepository;
  late MockAdminAuditLogRepository auditLogRepository;
  late MockIssueReportRepository issueReportRepository;
  late IssueReportDetailController controller;

  setUp(() {
    userStore = MockAdminUserStore();
    userDirectoryRepository = MockAdminUserDirectoryRepository(userStore);
    auditLogRepository = MockAdminAuditLogRepository();
    issueReportRepository =
        MockIssueReportRepository(auditLogRepository: auditLogRepository);
    controller = IssueReportDetailController(
      issueReportRepository,
      userDirectoryRepository,
      auditLogRepository,
    );
  });

  group('IssueReportDetailController', () {
    test('initial state has no report, no submitter, no history, not '
        'loading, no error', () {
      expect(controller.report, isNull);
      expect(controller.submitter, isNull);
      expect(controller.statusHistory, isEmpty);
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
    });

    test('load fetches the report for a known report id', () async {
      await controller.load('issue-001');

      expect(controller.report, isNotNull);
      expect(controller.report!.page, 'TripViewScreen');
      expect(controller.error, isNull);
    });

    test('load with an unknown report id sets an error and leaves report '
        'null', () async {
      await controller.load('nonexistent-999');

      expect(controller.report, isNull);
      expect(controller.error, isNotNull);
    });

    test('load also fetches the submitting user\'s profile', () async {
      await controller.load('issue-001'); // seeded submittedByUserId: user-101

      expect(controller.submitter, isNotNull);
      expect(controller.submitter!.displayName, 'Alice Tan');
    });

    test('a submitter id with no matching profile leaves submitter null, '
        'not an error', () async {
      await issueReportRepository.submitReport(
        userId: 'deleted-user-999',
        page: 'HomeScreen',
        description: 'Filed by an account that no longer exists.',
      );
      final reportId = (await issueReportRepository.getAllReports())
          .firstWhere((r) => r.submittedByUserId == 'deleted-user-999')
          .reportId;

      await controller.load(reportId);

      expect(controller.report, isNotNull);
      expect(controller.submitter, isNull);
      expect(controller.error, isNull);
    });

    test('load also fetches status history scoped to this report', () async {
      await auditLogRepository.recordAction(AdminAuditLog(
        logId: auditLogRepository.nextLogId(),
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.issueReport,
        targetId: 'issue-001',
        action: AdminAction.issueMarkInProgress,
        reason: 'Looking into it',
        createdAt: DateTime.now(),
      ));

      await controller.load('issue-001');

      expect(controller.statusHistory, hasLength(1));
      expect(controller.statusHistory.single.action, AdminAction.issueMarkInProgress);
      expect(controller.statusHistory.single.reason, 'Looking into it');
    });

    test('status history only includes entries for this report', () async {
      await auditLogRepository.recordAction(AdminAuditLog(
        logId: auditLogRepository.nextLogId(),
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.issueReport,
        targetId: 'issue-002',
        action: AdminAction.issueMarkResolved,
        createdAt: DateTime.now(),
      ));
      await auditLogRepository.recordAction(AdminAuditLog(
        logId: auditLogRepository.nextLogId(),
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.user,
        targetId: 'issue-001', // same string id, different targetType — must not match
        action: AdminAction.suspend,
        createdAt: DateTime.now(),
      ));

      await controller.load('issue-001');

      expect(controller.statusHistory, isEmpty);
    });

    test('load can be called again to refresh and reflects the latest '
        'status', () async {
      await controller.load('issue-001');
      expect(controller.report!.status, IssueReportStatus.open);

      await issueReportRepository.updateStatus(
        adminUserId: 'admin-001',
        reportId: 'issue-001',
        status: IssueReportStatus.inProgress,
      );
      await controller.load('issue-001');

      expect(controller.report!.status, IssueReportStatus.inProgress);
    });

    test('loading is true during load, false after', () async {
      final future = controller.load('issue-001');
      expect(controller.loading, isTrue);
      await future;
      expect(controller.loading, isFalse);
    });
  });
}
