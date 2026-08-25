import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/ai_request_log_repository.dart';
import 'package:tripjournal/data/mock_ai_request_log_repository.dart';
import 'package:tripjournal/features/admin/controller/failed_ai_requests_controller.dart';
import 'package:tripjournal/features/admin/screens/failed_ai_requests_screen.dart';
import 'package:tripjournal/models/ai_request_log.dart';

void main() {
  late MockAiRequestLogRepository repository;

  Future<void> seedOneFailedEntry() async {
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

  Future<void> pumpScreen(WidgetTester tester, FailedAiRequestsController controller) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [failedAiRequestsControllerProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(home: FailedAiRequestsScreen()),
      ),
    );
    await tester.pump(); // triggers the post-frame load callback
    await tester.pumpAndSettle();
  }

  group('FailedAiRequestsScreen', () {
    testWidgets('loads and shows every seeded failed entry with its error message',
        (tester) async {
      await seedOneFailedEntry();
      await pumpScreen(tester, FailedAiRequestsController(repository));

      expect(find.byKey(const Key('admin-failed-ai-requests-results')), findsOneWidget);
      expect(find.text('Food Detection'), findsOneWidget);
      expect(find.text('quota exceeded'), findsOneWidget);
    });

    testWidgets('a Retry button appears for each failed entry', (tester) async {
      await seedOneFailedEntry();
      final entries = await repository.getFailedRequests();
      await pumpScreen(tester, FailedAiRequestsController(repository));

      expect(
        find.byKey(Key('admin-ai-request-retry-${entries.single.logId}')),
        findsOneWidget,
      );
    });

    testWidgets('tapping Retry shows a confirmation SnackBar once it completes',
        (tester) async {
      // Doesn't assert an in-flight spinner frame: the mock AI services
      // resolve within a single microtask flush, so there's no reliable
      // frame where `pump()` observes the retry mid-flight — see
      // `FailedAiRequestsController`'s own "isRetrying is true while a
      // retry is in flight" test for that behavior, verified at the
      // controller level instead, where checking synchronously right after
      // calling `retry()` (before any `await`/`pump`) is reliable.
      await seedOneFailedEntry();
      final entries = await repository.getFailedRequests();
      await pumpScreen(tester, FailedAiRequestsController(repository));

      await tester.tap(find.byKey(Key('admin-ai-request-retry-${entries.single.logId}')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Retried Food Detection'), findsOneWidget);
    });

    testWidgets('the original failed entry is still listed after a retry', (tester) async {
      await seedOneFailedEntry();
      final entries = await repository.getFailedRequests();
      await pumpScreen(tester, FailedAiRequestsController(repository));

      await tester.tap(find.byKey(Key('admin-ai-request-retry-${entries.single.logId}')));
      await tester.pumpAndSettle();

      expect(find.text('Food Detection'), findsOneWidget);
    });

    testWidgets('no failed entries shows the empty state, not a blank list', (tester) async {
      await pumpScreen(tester, FailedAiRequestsController(repository));

      expect(find.byKey(const Key('admin-failed-ai-requests-empty-state')), findsOneWidget);
      expect(find.text('No failed AI requests recorded.'), findsOneWidget);
      expect(find.byKey(const Key('admin-failed-ai-requests-results')), findsNothing);
    });

    testWidgets('a failing repository shows an error with a retry-load button', (tester) async {
      await pumpScreen(tester, FailedAiRequestsController(_FailingAiRequestLogRepository()));

      expect(find.byKey(const Key('admin-failed-ai-requests-retry-load')), findsOneWidget);
    });
  });
}

class _FailingAiRequestLogRepository implements AiRequestLogRepository {
  @override
  Future<void> recordRequest(AiRequestLog entry) async {}

  @override
  Future<List<AiRequestLog>> getAllRequests({AiRequestStatus? status}) async => [];

  @override
  Future<List<AiRequestLog>> getFailedRequests() async {
    throw Exception('mock backend unreachable');
  }
}
