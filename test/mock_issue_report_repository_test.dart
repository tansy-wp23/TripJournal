import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_admin_audit_log_repository.dart';
import 'package:tripjournal/data/mock_issue_report_repository.dart';
import 'package:tripjournal/models/admin_audit_log.dart';
import 'package:tripjournal/models/issue_report.dart';

void main() {
  late MockAdminAuditLogRepository auditLogRepository;
  late MockIssueReportRepository repository;

  setUp(() {
    auditLogRepository = MockAdminAuditLogRepository();
    repository = MockIssueReportRepository(
      auditLogRepository: auditLogRepository,
    );
  });

  group('MockIssueReportRepository', () {
    test('seeds sample reports spanning all three statuses', () async {
      final reports = await repository.getAllReports();

      expect(reports, hasLength(4));
      expect(
        reports.map((r) => r.status).toSet(),
        {
          IssueReportStatus.open,
          IssueReportStatus.inProgress,
          IssueReportStatus.resolved,
        },
      );
    });

    test('getAllReports returns newest first', () async {
      final reports = await repository.getAllReports();

      for (var i = 0; i < reports.length - 1; i++) {
        expect(
          reports[i].createdAt.isAfter(reports[i + 1].createdAt) ||
              reports[i].createdAt.isAtSameMomentAs(reports[i + 1].createdAt),
          isTrue,
        );
      }
    });

    test('getAllReports narrows by statusFilter', () async {
      final resolved = await repository.getAllReports(
        statusFilter: IssueReportStatus.resolved,
      );

      expect(resolved, isNotEmpty);
      expect(resolved.every((r) => r.status == IssueReportStatus.resolved),
          isTrue);
    });

    test('getReportById returns a matching report', () async {
      final report = await repository.getReportById('issue-001');

      expect(report, isNotNull);
      expect(report!.reportId, 'issue-001');
    });

    test('getReportById returns null for an unknown id', () async {
      final report = await repository.getReportById('does-not-exist');

      expect(report, isNull);
    });

    test('submitReport adds a new open report visible in getAllReports',
        () async {
      await repository.submitReport(
        userId: 'user-105',
        page: 'HomeScreen',
        description: 'Sign-out button does nothing on first tap.',
      );

      final reports = await repository.getAllReports();
      final submitted =
          reports.where((r) => r.description.contains('Sign-out button'));
      expect(submitted, hasLength(1));
      expect(submitted.single.status, IssueReportStatus.open);
      expect(submitted.single.submittedByUserId, 'user-105');
    });

    test('updateStatus updates the report and records an audit entry',
        () async {
      await repository.updateStatus(
        adminUserId: 'admin-001',
        reportId: 'issue-001',
        status: IssueReportStatus.inProgress,
        remarks: 'Looking into it.',
      );

      final report = await repository.getReportById('issue-001');
      expect(report!.status, IssueReportStatus.inProgress);
      expect(report.adminRemarks, 'Looking into it.');

      final history = await auditLogRepository.getHistoryForTarget(
        targetType: AdminAuditTargetType.issueReport,
        targetId: 'issue-001',
      );
      expect(history, hasLength(1));
      expect(history.single.action, AdminAction.issueMarkInProgress);
      expect(history.single.adminUserId, 'admin-001');
      expect(history.single.reason, 'Looking into it.');
    });

    test('updateStatus without remarks keeps the existing remarks',
        () async {
      await repository.updateStatus(
        adminUserId: 'admin-001',
        reportId: 'issue-002', // seeded with adminRemarks already set
        status: IssueReportStatus.resolved,
      );

      final report = await repository.getReportById('issue-002');
      expect(report!.status, IssueReportStatus.resolved);
      expect(report.adminRemarks, isNotNull);
    });

    test('updateStatus maps each target status to its own AdminAction',
        () async {
      await repository.updateStatus(
        adminUserId: 'admin-001',
        reportId: 'issue-003', // seeded as resolved
        status: IssueReportStatus.open,
      );

      final history = await auditLogRepository.getHistoryForTarget(
        targetType: AdminAuditTargetType.issueReport,
        targetId: 'issue-003',
      );
      expect(history.single.action, AdminAction.issueReopen);
    });

    test('updateStatus throws for an unknown report id', () async {
      expect(
        () => repository.updateStatus(
          adminUserId: 'admin-001',
          reportId: 'does-not-exist',
          status: IssueReportStatus.resolved,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
