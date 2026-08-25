import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_admin_audit_log_repository.dart';
import 'package:tripjournal/data/mock_ai_request_log_repository.dart';
import 'package:tripjournal/data/mock_issue_report_repository.dart';
import 'package:tripjournal/data/mock_system_error_log_repository.dart';
import 'package:tripjournal/data/system_error_log_repository.dart';
import 'package:tripjournal/features/admin/controller/monitoring_report_controller.dart';
import 'package:tripjournal/models/ai_request_log.dart';
import 'package:tripjournal/models/issue_report.dart';
import 'package:tripjournal/models/system_error_log.dart';

void main() {
  late MockSystemErrorLogRepository errorRepository;
  late MockAiRequestLogRepository aiRepository;
  late MockIssueReportRepository issueRepository;

  MonitoringReportController buildController() => MonitoringReportController(
        errorRepository,
        aiRepository,
        issueRepository,
      );

  Future<void> seedData() async {
    await errorRepository.recordError(SystemErrorLog(
      logId: 'err-1',
      module: 'journal',
      severity: ErrorSeverity.warning,
      message: 'in range',
      createdAt: DateTime(2026, 1, 15),
    ));
    await errorRepository.recordError(SystemErrorLog(
      logId: 'err-2',
      module: 'journal',
      severity: ErrorSeverity.fatal,
      message: 'out of range',
      createdAt: DateTime(2026, 3, 1),
    ));
    await aiRepository.recordRequest(AiRequestLog(
      logId: 'ai-1',
      userId: 'user-101',
      requestType: AiRequestType.dailyAdvice,
      status: AiRequestStatus.succeeded,
      executionTimeMs: 100,
      createdAt: DateTime(2026, 1, 20),
    ));
    await aiRepository.recordRequest(AiRequestLog(
      logId: 'ai-2',
      userId: 'user-101',
      requestType: AiRequestType.foodDetection,
      status: AiRequestStatus.failed,
      executionTimeMs: 100,
      createdAt: DateTime(2026, 3, 1),
    ));
    await issueRepository.submitReport(
      userId: 'user-101',
      page: 'TripViewScreen',
      description: 'in range issue',
    );
  }

  setUp(() {
    errorRepository = MockSystemErrorLogRepository(seed: []);
    aiRepository = MockAiRequestLogRepository(seed: []);
    issueRepository = MockIssueReportRepository(
      auditLogRepository: MockAdminAuditLogRepository(),
      seed: [],
    );
  });

  group('MonitoringReportController', () {
    test('initial state has no report, not loading, no error, no range', () {
      final controller = buildController();

      expect(controller.report, isNull);
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
      expect(controller.startDate, isNull);
      expect(controller.endDate, isNull);
    });

    test('generate with no range counts every entry from every source', () async {
      await seedData();
      final controller = buildController();

      await controller.generate();

      final report = controller.report!;
      expect(report.totalErrors, 2);
      expect(report.totalAiRequests, 2);
      expect(report.totalIssues, 1);
      expect(report.errorCountsBySeverity[ErrorSeverity.warning], 1);
      expect(report.errorCountsBySeverity[ErrorSeverity.fatal], 1);
      expect(report.aiRequestCountsByStatus[AiRequestStatus.succeeded], 1);
      expect(report.aiRequestCountsByStatus[AiRequestStatus.failed], 1);
      expect(report.issueCountsByStatus[IssueReportStatus.open], 1);
    });

    test('every ErrorSeverity/AiRequestStatus/IssueReportStatus value is '
        'present in the counts even at zero', () async {
      final controller = buildController();

      await controller.generate();

      final report = controller.report!;
      expect(report.errorCountsBySeverity.keys.toSet(), ErrorSeverity.values.toSet());
      expect(report.errorCountsBySeverity.values.every((c) => c == 0), isTrue);
      expect(report.aiRequestCountsByStatus.keys.toSet(), AiRequestStatus.values.toSet());
      expect(report.issueCountsByStatus.keys.toSet(), IssueReportStatus.values.toSet());
    });

    test('setDateRange narrows every source to that window', () async {
      await seedData();
      final controller = buildController();

      await controller.setDateRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 31));

      final report = controller.report!;
      expect(report.totalErrors, 1);
      expect(report.totalAiRequests, 1);
      expect(report.errorCountsBySeverity[ErrorSeverity.warning], 1);
      expect(report.errorCountsBySeverity[ErrorSeverity.fatal], 0);
      expect(controller.startDate, DateTime(2026, 1, 1));
      expect(controller.endDate, DateTime(2026, 1, 31));
    });

    test('clearing the range (both null) restores the full count', () async {
      await seedData();
      final controller = buildController();
      await controller.setDateRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 31));

      await controller.setDateRange(start: null, end: null);

      expect(controller.startDate, isNull);
      expect(controller.endDate, isNull);
      expect(controller.report!.totalErrors, 2);
    });

    test('loading is true during generate, false after', () async {
      final controller = buildController();

      final future = controller.generate();
      expect(controller.loading, isTrue);
      await future;
      expect(controller.loading, isFalse);
    });

    test('a failing repository sets error and leaves report null', () async {
      final controller = MonitoringReportController(
        _FailingSystemErrorLogRepository(),
        aiRepository,
        issueRepository,
      );

      await controller.generate();

      expect(controller.report, isNull);
      expect(controller.error, isNotNull);
      expect(controller.loading, isFalse);
    });
  });
}

class _FailingSystemErrorLogRepository implements SystemErrorLogRepository {
  @override
  Future<void> recordError(SystemErrorLog entry) async {}

  @override
  Future<List<SystemErrorLog>> getAllErrors({String? module, ErrorSeverity? severity}) async {
    throw Exception('mock backend unreachable');
  }
}
