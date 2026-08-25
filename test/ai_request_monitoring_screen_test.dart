import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/ai_request_log_repository.dart';
import 'package:tripjournal/data/mock_ai_request_log_repository.dart';
import 'package:tripjournal/features/admin/controller/ai_request_monitoring_controller.dart';
import 'package:tripjournal/features/admin/controller/failed_ai_requests_controller.dart';
import 'package:tripjournal/features/admin/screens/ai_request_monitoring_screen.dart';
import 'package:tripjournal/features/admin/screens/failed_ai_requests_screen.dart';
import 'package:tripjournal/models/ai_request_log.dart';

void main() {
  late MockAiRequestLogRepository repository;

  Future<void> seedTwoEntries() async {
    await repository.recordRequest(AiRequestLog(
      logId: repository.nextLogId(),
      userId: 'user-101',
      requestType: AiRequestType.dailyAdvice,
      status: AiRequestStatus.succeeded,
      executionTimeMs: 1200,
      createdAt: DateTime(2026, 1, 1),
    ));
    await repository.recordRequest(AiRequestLog(
      logId: repository.nextLogId(),
      userId: 'user-102',
      requestType: AiRequestType.foodDetection,
      status: AiRequestStatus.failed,
      executionTimeMs: 900,
      errorMessage: 'quota exceeded',
      createdAt: DateTime(2026, 1, 2),
    ));
  }

  setUp(() {
    repository = MockAiRequestLogRepository(seed: []);
  });

  Future<void> pumpScreen(WidgetTester tester, AiRequestMonitoringController controller) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiRequestMonitoringControllerProvider.overrideWith((ref) => controller),
          // FailedAiRequestsScreen (reached via the app bar action tested
          // below) reads this provider on build — without an override its
          // default resolves against the real, Supabase-backed
          // `aiRequestLogRepository` global (Phase 21), which throws
          // outside a running app.
          failedAiRequestsControllerProvider.overrideWith(
            (ref) => FailedAiRequestsController(MockAiRequestLogRepository(seed: [])),
          ),
        ],
        child: const MaterialApp(home: AiRequestMonitoringScreen()),
      ),
    );
    await tester.pump(); // triggers the post-frame load callback
    await tester.pumpAndSettle();
  }

  group('AiRequestMonitoringScreen', () {
    testWidgets('loads and shows every seeded entry', (tester) async {
      await seedTwoEntries();
      await pumpScreen(tester, AiRequestMonitoringController(repository));

      expect(find.byKey(const Key('admin-ai-requests-results')), findsOneWidget);
      expect(find.text('Daily Advice'), findsOneWidget);
      expect(find.text('Food Detection'), findsOneWidget);
    });

    testWidgets('tapping the Failed status chip narrows to failed entries', (tester) async {
      await seedTwoEntries();
      await pumpScreen(tester, AiRequestMonitoringController(repository));

      await tester.tap(find.byKey(const Key('admin-ai-requests-status-failed')));
      await tester.pumpAndSettle();

      expect(find.text('Food Detection'), findsOneWidget);
      expect(find.text('Daily Advice'), findsNothing);
    });

    testWidgets('tapping All statuses after a filter restores the full list', (tester) async {
      await seedTwoEntries();
      await pumpScreen(tester, AiRequestMonitoringController(repository));

      await tester.tap(find.byKey(const Key('admin-ai-requests-status-failed')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'All statuses'));
      await tester.pumpAndSettle();

      expect(find.text('Daily Advice'), findsOneWidget);
      expect(find.text('Food Detection'), findsOneWidget);
    });

    testWidgets('the clear-filters action appears only once a filter is active, and resets it',
        (tester) async {
      await seedTwoEntries();
      await pumpScreen(tester, AiRequestMonitoringController(repository));

      expect(find.byKey(const Key('admin-ai-requests-clear-filters')), findsNothing);

      await tester.tap(find.byKey(const Key('admin-ai-requests-status-failed')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin-ai-requests-clear-filters')), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin-ai-requests-clear-filters')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-ai-requests-clear-filters')), findsNothing);
      expect(find.text('Daily Advice'), findsOneWidget);
    });

    testWidgets('the failed-requests action navigates to FailedAiRequestsScreen', (tester) async {
      await pumpScreen(tester, AiRequestMonitoringController(repository));

      await tester.tap(find.byKey(const Key('admin-ai-requests-failed')));
      await tester.pumpAndSettle();

      expect(find.byType(FailedAiRequestsScreen), findsOneWidget);
    });

    testWidgets('no entries at all shows the empty state, not a blank list', (tester) async {
      await pumpScreen(tester, AiRequestMonitoringController(repository));

      expect(find.byKey(const Key('admin-ai-requests-empty-state')), findsOneWidget);
      expect(find.text('No AI requests have been recorded.'), findsOneWidget);
      expect(find.byKey(const Key('admin-ai-requests-results')), findsNothing);
    });

    testWidgets('a filter matching nobody shows a filter-specific empty state', (tester) async {
      await repository.recordRequest(AiRequestLog(
        logId: repository.nextLogId(),
        userId: 'user-101',
        requestType: AiRequestType.dailyAdvice,
        status: AiRequestStatus.succeeded,
        executionTimeMs: 500,
        createdAt: DateTime.now(),
      ));
      await pumpScreen(tester, AiRequestMonitoringController(repository));

      await tester.tap(find.byKey(const Key('admin-ai-requests-status-failed')));
      await tester.pumpAndSettle();

      expect(find.text('No requests match this filter.'), findsOneWidget);
    });

    testWidgets('a failing repository shows an error with a retry button', (tester) async {
      await pumpScreen(tester, AiRequestMonitoringController(_FailingAiRequestLogRepository()));

      expect(find.byKey(const Key('admin-ai-requests-retry-load')), findsOneWidget);
    });
  });
}

class _FailingAiRequestLogRepository implements AiRequestLogRepository {
  @override
  Future<void> recordRequest(AiRequestLog entry) async {}

  @override
  Future<List<AiRequestLog>> getAllRequests({AiRequestStatus? status}) async {
    throw Exception('mock backend unreachable');
  }

  @override
  Future<List<AiRequestLog>> getFailedRequests() async => [];
}
