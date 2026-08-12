import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/issue_report_repository.dart';
import 'package:tripjournal/data/mock_admin_audit_log_repository.dart';
import 'package:tripjournal/data/mock_issue_report_repository.dart';
import 'package:tripjournal/features/admin/controller/issue_report_management_controller.dart';
import 'package:tripjournal/features/admin/screens/admin_issue_report_list_screen.dart';
import 'package:tripjournal/features/admin/screens/issue_report_detail_screen.dart';
import 'package:tripjournal/models/issue_report.dart';

void main() {
  group('AdminIssueReportListScreen', () {
    testWidgets('loads and shows every seeded report on open', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminIssueReportListScreen())),
      );
      await tester.pump(); // triggers the post-frame load callback
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-issue-list-results')), findsOneWidget);
      expect(
        find.text('Cover photo fails to upload when offline.'),
        findsOneWidget,
      );
      expect(
        find.text('Journal entry list scrolls back to top after editing.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a report opens IssueReportDetailScreen', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminIssueReportListScreen())),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cover photo fails to upload when offline.'));
      await tester.pumpAndSettle();

      expect(find.byType(IssueReportDetailScreen), findsOneWidget);
    });

    testWidgets('tapping the Resolved chip narrows to resolved reports only',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminIssueReportListScreen())),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Resolved'));
      await tester.pumpAndSettle();

      expect(
        find.text('Journal entry list scrolls back to top after editing.'),
        findsOneWidget,
      );
      expect(
        find.text('Cover photo fails to upload when offline.'),
        findsNothing,
      );
    });

    testWidgets('tapping All after a filter restores the full list',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminIssueReportListScreen())),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Resolved'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();

      expect(
        find.text('Cover photo fails to upload when offline.'),
        findsOneWidget,
      );
      expect(
        find.text('Journal entry list scrolls back to top after editing.'),
        findsOneWidget,
      );
    });

    testWidgets('no reports at all shows the empty state, not a blank list',
        (tester) async {
      final controller = IssueReportManagementController(
        MockIssueReportRepository(
          auditLogRepository: MockAdminAuditLogRepository(),
          seed: const [],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            issueReportManagementControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: AdminIssueReportListScreen()),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-issue-list-empty-state')), findsOneWidget);
      expect(find.byKey(const Key('admin-issue-list-results')), findsNothing);
    });

    testWidgets('a status filter matching nobody shows a filter-specific '
        'empty state', (tester) async {
      final now = DateTime.now();
      final controller = IssueReportManagementController(
        MockIssueReportRepository(
          auditLogRepository: MockAdminAuditLogRepository(),
          seed: [
            IssueReport(
              reportId: 'issue-only-open',
              submittedByUserId: 'user-101',
              page: 'HomeScreen',
              description: 'Only an open report exists.',
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            issueReportManagementControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: AdminIssueReportListScreen()),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Resolved'));
      await tester.pumpAndSettle();

      expect(find.text('No resolved reports.'), findsOneWidget);
    });

    testWidgets('a failing repository shows an error with a retry button',
        (tester) async {
      final controller = IssueReportManagementController(_FailingIssueReportRepository());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            issueReportManagementControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: AdminIssueReportListScreen()),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-issue-list-retry')), findsOneWidget);
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
