import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_admin_audit_log_repository.dart';
import 'package:tripjournal/data/mock_ai_request_log_repository.dart';
import 'package:tripjournal/data/mock_issue_report_repository.dart';
import 'package:tripjournal/data/mock_system_error_log_repository.dart';
import 'package:tripjournal/data/system_error_log_repository.dart';
import 'package:tripjournal/features/admin/controller/monitoring_report_controller.dart';
import 'package:tripjournal/features/admin/screens/monitoring_report_screen.dart';
import 'package:tripjournal/models/ai_request_log.dart';
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

  setUp(() {
    errorRepository = MockSystemErrorLogRepository(seed: []);
    aiRepository = MockAiRequestLogRepository(seed: []);
    issueRepository = MockIssueReportRepository(
      auditLogRepository: MockAdminAuditLogRepository(),
      seed: [],
    );
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    MonitoringReportController controller,
  ) async {
    // Three report-section cards plus the export button row run taller than
    // flutter_test's default 800x600 surface — without this, the export
    // buttons (last in the list) sit outside the built/cached extent and
    // `find.byKey` can't locate them, same class of issue
    // `pdf_export_button_test.dart` and `trip_view_screen_test.dart` size
    // their own test viewports around.
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monitoringReportControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: MonitoringReportScreen()),
      ),
    );
    await tester.pump(); // triggers the post-frame generate callback
    await tester.pumpAndSettle();
  }

  group('MonitoringReportScreen', () {
    testWidgets('auto-generates an all-time report on open and shows every '
        'section with its total', (tester) async {
      await errorRepository.recordError(
        SystemErrorLog(
          logId: 'err-1',
          module: 'journal',
          severity: ErrorSeverity.warning,
          message: 'seeded',
          createdAt: DateTime.now(),
        ),
      );
      await aiRepository.recordRequest(
        AiRequestLog(
          logId: 'ai-1',
          userId: 'user-101',
          requestType: AiRequestType.dailyAdvice,
          status: AiRequestStatus.succeeded,
          executionTimeMs: 100,
          createdAt: DateTime.now(),
        ),
      );
      await pumpScreen(tester, buildController());

      expect(
        find.byKey(const Key('admin-monitoring-report-body')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('admin-monitoring-report-errors')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('admin-monitoring-report-ai-requests')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('admin-monitoring-report-issues')),
        findsOneWidget,
      );
      expect(find.text('All time'), findsOneWidget);
    });

    testWidgets('the date range clear icon only appears once a range is set', (
      tester,
    ) async {
      final controller = buildController();
      await pumpScreen(tester, controller);

      expect(
        find.byKey(const Key('admin-monitoring-report-date-range-clear')),
        findsNothing,
      );

      await controller.setDateRange(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 31),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('admin-monitoring-report-date-range-clear')),
        findsOneWidget,
      );
      expect(find.text('Clear date'), findsOneWidget);
      expect(find.textContaining('–'), findsOneWidget);
    });

    testWidgets('tapping the clear icon resets the range back to "All time"', (
      tester,
    ) async {
      final controller = buildController();
      await pumpScreen(tester, controller);
      await controller.setDateRange(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 31),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('admin-monitoring-report-date-range-clear')),
      );
      await tester.pumpAndSettle();

      expect(find.text('All time'), findsOneWidget);
      expect(
        find.byKey(const Key('admin-monitoring-report-date-range-clear')),
        findsNothing,
      );
    });

    testWidgets('tapping Export PDF builds the document without throwing '
        '(does not pumpAndSettle afterward — Printing.sharePdf needs a real '
        'platform channel unavailable under flutter_test, same reasoning as '
        'pdf_export_button_test.dart; and unlike that screen\'s PDFs, this '
        'one has no real file I/O, so it resolves within the same pump — no '
        'reliable frame shows the loading dialog mid-flight, so this checks '
        'the durable outcome, no error SnackBar, instead)', (tester) async {
      await pumpScreen(tester, buildController());

      await tester.tap(
        find.byKey(const Key('admin-monitoring-report-export-pdf')),
      );
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('tapping Export CSV builds the file without throwing (same '
        'reasoning as the PDF export test above)', (tester) async {
      await pumpScreen(tester, buildController());

      await tester.tap(
        find.byKey(const Key('admin-monitoring-report-export-csv')),
      );
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failing repository shows an error with a retry button', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        MonitoringReportController(
          _FailingSystemErrorLogRepository(),
          aiRepository,
          issueRepository,
        ),
      );

      expect(
        find.byKey(const Key('admin-monitoring-report-retry')),
        findsOneWidget,
      );
    });
  });
}

class _FailingSystemErrorLogRepository implements SystemErrorLogRepository {
  @override
  Future<void> recordError(SystemErrorLog entry) async {}

  @override
  Future<List<SystemErrorLog>> getAllErrors({
    String? module,
    ErrorSeverity? severity,
  }) async {
    throw Exception('mock backend unreachable');
  }
}
