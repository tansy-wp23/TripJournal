import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/controller/ai_request_monitoring_controller.dart';
import 'package:tripjournal/features/admin/controller/monitoring_report_controller.dart';
import 'package:tripjournal/features/admin/controller/system_error_log_controller.dart';
import 'package:tripjournal/features/admin/screens/ai_request_monitoring_screen.dart';
import 'package:tripjournal/features/admin/screens/monitoring_report_screen.dart';
import 'package:tripjournal/features/admin/screens/system_error_log_screen.dart';
import 'package:tripjournal/features/admin/screens/system_health_screen.dart';
import 'package:tripjournal/features/admin/screens/system_monitoring_screen.dart';
import 'package:tripjournal/widgets/app_navigation_tile.dart';
import 'package:tripjournal/data/mock_admin_audit_log_repository.dart';
import 'package:tripjournal/data/mock_ai_request_log_repository.dart';
import 'package:tripjournal/data/mock_issue_report_repository.dart';
import 'package:tripjournal/data/mock_system_error_log_repository.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          systemErrorLogControllerProvider.overrideWith(
            (ref) => SystemErrorLogController(
              MockSystemErrorLogRepository(seed: []),
            ),
          ),
          aiRequestMonitoringControllerProvider.overrideWith(
            (ref) => AiRequestMonitoringController(
              MockAiRequestLogRepository(seed: []),
            ),
          ),
          monitoringReportControllerProvider.overrideWith(
            (ref) => MonitoringReportController(
              MockSystemErrorLogRepository(seed: []),
              MockAiRequestLogRepository(seed: []),
              MockIssueReportRepository(
                auditLogRepository: MockAdminAuditLogRepository(),
                seed: [],
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: SystemMonitoringScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SystemMonitoringScreen', () {
    testWidgets('shows a card for each of the four monitoring screens', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('System Error Log'), findsOneWidget);
      expect(find.text('AI Request Monitoring'), findsOneWidget);
      expect(find.text('System Health'), findsOneWidget);
      expect(find.text('Monitoring Report'), findsOneWidget);
      expect(find.byType(AppNavigationTile), findsNWidgets(4));
    });

    testWidgets('tapping the System Error Log card opens that screen', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('admin-monitoring-system-errors')));
      await tester.pumpAndSettle();

      expect(find.byType(SystemErrorLogScreen), findsOneWidget);
    });

    testWidgets('tapping the AI Request Monitoring card opens that screen', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('admin-monitoring-ai-requests')));
      await tester.pumpAndSettle();

      expect(find.byType(AiRequestMonitoringScreen), findsOneWidget);
    });

    testWidgets('tapping the System Health card opens that screen', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('admin-monitoring-system-health')));
      await tester.pumpAndSettle();

      expect(find.byType(SystemHealthScreen), findsOneWidget);
    });

    testWidgets('tapping the Monitoring Report card opens that screen', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('admin-monitoring-report')));
      await tester.pumpAndSettle();

      expect(find.byType(MonitoringReportScreen), findsOneWidget);
    });
  });
}
