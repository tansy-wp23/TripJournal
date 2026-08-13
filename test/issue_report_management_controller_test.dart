import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/issue_report_repository.dart';
import 'package:tripjournal/data/mock_admin_audit_log_repository.dart';
import 'package:tripjournal/data/mock_issue_report_repository.dart';
import 'package:tripjournal/features/admin/controller/issue_report_management_controller.dart';
import 'package:tripjournal/models/issue_report.dart';

void main() {
  group('IssueReportManagementController', () {
    test('initial state has no reports, not loading, no error, no filter',
        () {
      final controller = IssueReportManagementController(
        MockIssueReportRepository(auditLogRepository: MockAdminAuditLogRepository()),
      );

      expect(controller.reports, isEmpty);
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
      expect(controller.statusFilter, isNull);
    });

    test('load populates reports matching the default seed', () async {
      final controller = IssueReportManagementController(
        MockIssueReportRepository(auditLogRepository: MockAdminAuditLogRepository()),
      );

      await controller.load();

      expect(controller.error, isNull);
      expect(controller.reports, hasLength(4));
    });

    test('setStatusFilter narrows the loaded reports', () async {
      final controller = IssueReportManagementController(
        MockIssueReportRepository(auditLogRepository: MockAdminAuditLogRepository()),
      );
      await controller.load();

      await controller.setStatusFilter(IssueReportStatus.resolved);

      expect(controller.statusFilter, IssueReportStatus.resolved);
      expect(controller.reports, isNotEmpty);
      expect(
        controller.reports.every((r) => r.status == IssueReportStatus.resolved),
        isTrue,
      );
    });

    test('clearing the filter (passing null) restores the full list',
        () async {
      final controller = IssueReportManagementController(
        MockIssueReportRepository(auditLogRepository: MockAdminAuditLogRepository()),
      );
      await controller.setStatusFilter(IssueReportStatus.open);
      final filteredCount = controller.reports.length;

      await controller.setStatusFilter(null);

      expect(controller.statusFilter, isNull);
      expect(controller.reports.length, greaterThanOrEqualTo(filteredCount));
      expect(controller.reports, hasLength(4));
    });

    test('loading is true during load, false after', () async {
      final controller = IssueReportManagementController(
        MockIssueReportRepository(auditLogRepository: MockAdminAuditLogRepository()),
      );

      final future = controller.load();
      expect(controller.loading, isTrue);
      await future;
      expect(controller.loading, isFalse);
    });

    test('a failing repository sets error and leaves reports empty',
        () async {
      final controller = IssueReportManagementController(_FailingIssueReportRepository());

      await controller.load();

      expect(controller.reports, isEmpty);
      expect(controller.error, isNotNull);
      expect(controller.loading, isFalse);
    });

    test('retrying after a failure can succeed and clears the error',
        () async {
      final repository = _FlakyIssueReportRepository();
      final controller = IssueReportManagementController(repository);

      await controller.load();
      expect(controller.error, isNotNull);
      expect(controller.reports, isEmpty);

      repository.shouldFail = false;
      await controller.load();

      expect(controller.error, isNull);
      expect(controller.reports, isNotEmpty);
    });
  });
}

class _FailingIssueReportRepository implements IssueReportRepository {
  @override
  Future<void> submitReport({
    required String userId,
    required String page,
    required String description,
    String? screenshotUrl,
  }) async {}

  @override
  Future<List<IssueReport>> getAllReports({IssueReportStatus? statusFilter}) async {
    throw Exception('mock backend unreachable');
  }

  @override
  Future<IssueReport?> getReportById(String reportId) async => null;

  @override
  Future<void> updateStatus({
    required String adminUserId,
    required String reportId,
    required IssueReportStatus status,
    String? remarks,
  }) async {}
}

class _FlakyIssueReportRepository implements IssueReportRepository {
  bool shouldFail = true;

  @override
  Future<void> submitReport({
    required String userId,
    required String page,
    required String description,
    String? screenshotUrl,
  }) async {}

  @override
  Future<List<IssueReport>> getAllReports({IssueReportStatus? statusFilter}) async {
    if (shouldFail) throw Exception('mock backend unreachable');
    final now = DateTime.now();
    return [
      IssueReport(
        reportId: 'issue-flaky-1',
        submittedByUserId: 'user-101',
        page: 'HomeScreen',
        description: 'Recovered report',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  @override
  Future<IssueReport?> getReportById(String reportId) async => null;

  @override
  Future<void> updateStatus({
    required String adminUserId,
    required String reportId,
    required IssueReportStatus status,
    String? remarks,
  }) async {}
}
