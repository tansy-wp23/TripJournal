import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/ai_request_log_repository.dart';
import 'package:tripjournal/data/mock_ai_request_log_repository.dart';
import 'package:tripjournal/features/admin/controller/failed_ai_requests_controller.dart';
import 'package:tripjournal/models/ai_request_log.dart';

void main() {
  // Built against a fresh, local `MockAiRequestLogRepository` — not the
  // real, shared `aiRequestLogRepository` global (Phase 21: genuinely
  // Supabase-backed, unsafe to touch from a plain test). `retry` itself is
  // hardcoded to write through the real global regardless of which
  // repository this controller was constructed with (see
  // `ai_request_retry_test.dart`'s doc comment) — so a retry's outcome no
  // longer shows up in *this* controller's own list the way it did
  // pre-Phase-21; what's still true, and still tested below, is that the
  // original failed entry is untouched by calling retry (retry records a
  // new entry elsewhere, it never mutates the old one).
  late MockAiRequestLogRepository repository;

  setUp(() {
    repository = MockAiRequestLogRepository(seed: []);
  });

  group('FailedAiRequestsController', () {
    test('initial state has no entries, not loading, no error', () {
      final controller = FailedAiRequestsController(repository);

      expect(controller.entries, isEmpty);
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
    });

    test('load surfaces a seeded failed entry, ignoring succeeded ones', () async {
      await repository.recordRequest(AiRequestLog(
        logId: repository.nextLogId(),
        userId: 'user-201',
        requestType: AiRequestType.dailyAdvice,
        status: AiRequestStatus.failed,
        executionTimeMs: 500,
        errorMessage: 'load-test failure',
        createdAt: DateTime.now(),
      ));
      await repository.recordRequest(AiRequestLog(
        logId: repository.nextLogId(),
        userId: 'user-201',
        requestType: AiRequestType.dailyAdvice,
        status: AiRequestStatus.succeeded,
        executionTimeMs: 500,
        createdAt: DateTime.now(),
      ));
      final controller = FailedAiRequestsController(repository);

      await controller.load();

      expect(controller.entries, hasLength(1));
      expect(controller.entries.every((e) => e.status == AiRequestStatus.failed), isTrue);
    });

    test('isRetrying is true while a retry is in flight, false after', () async {
      final entry = AiRequestLog(
        logId: repository.nextLogId(),
        userId: 'user-202',
        requestType: AiRequestType.dailyAdvice,
        status: AiRequestStatus.failed,
        executionTimeMs: 500,
        errorMessage: 'retry-flight-test failure',
        createdAt: DateTime.now(),
      );
      await repository.recordRequest(entry);
      final controller = FailedAiRequestsController(repository);
      await controller.load();

      expect(controller.isRetrying(entry.logId), isFalse);
      final future = controller.retry(entry);
      expect(controller.isRetrying(entry.logId), isTrue);
      await future;
      expect(controller.isRetrying(entry.logId), isFalse);
    });

    test('retry leaves the original failed entry in this controller\'s own '
        'list untouched (retry records a new entry elsewhere, via the real '
        'production repository — it never mutates the old one)', () async {
      final entry = AiRequestLog(
        logId: repository.nextLogId(),
        userId: 'user-203',
        requestType: AiRequestType.dailyAdvice,
        status: AiRequestStatus.failed,
        executionTimeMs: 500,
        errorMessage: 'retry-preserves-original-test failure',
        createdAt: DateTime.now(),
      );
      await repository.recordRequest(entry);
      final controller = FailedAiRequestsController(repository);
      await controller.load();

      await controller.retry(entry);

      expect(controller.entries.map((e) => e.logId), contains(entry.logId));
    });

    test('a failing repository sets error and leaves entries empty', () async {
      final controller = FailedAiRequestsController(_FailingAiRequestLogRepository());

      await controller.load();

      expect(controller.entries, isEmpty);
      expect(controller.error, isNotNull);
      expect(controller.loading, isFalse);
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
