import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_ai_request_log_repository.dart';
import 'package:tripjournal/models/ai_request_log.dart';

void main() {
  late MockAiRequestLogRepository repository;

  setUp(() {
    // Empty seed — tests control exactly what entries exist, mirroring
    // MockAdminAuditLogRepository's tests.
    repository = MockAiRequestLogRepository(seed: []);
  });

  group('MockAiRequestLogRepository', () {
    test('nextLogId returns unique ids on successive calls', () {
      final ids = {for (var i = 0; i < 5; i++) repository.nextLogId()};

      expect(ids, hasLength(5));
    });

    test('recordRequest then getAllRequests returns the entry', () async {
      final entry = AiRequestLog(
        logId: repository.nextLogId(),
        userId: 'user-101',
        requestType: AiRequestType.dailyAdvice,
        status: AiRequestStatus.succeeded,
        executionTimeMs: 1200,
        createdAt: DateTime.now(),
      );

      await repository.recordRequest(entry);
      final all = await repository.getAllRequests();

      expect(all, hasLength(1));
      expect(all.single.requestType, AiRequestType.dailyAdvice);
      expect(all.single.status, AiRequestStatus.succeeded);
    });

    test('getAllRequests returns newest first', () async {
      final older = DateTime.now().subtract(const Duration(minutes: 30));
      final newer = DateTime.now();

      await repository.recordRequest(AiRequestLog(
        logId: repository.nextLogId(),
        userId: 'user-101',
        requestType: AiRequestType.dailyAdvice,
        status: AiRequestStatus.succeeded,
        executionTimeMs: 1000,
        createdAt: older,
      ));
      await repository.recordRequest(AiRequestLog(
        logId: repository.nextLogId(),
        userId: 'user-101',
        requestType: AiRequestType.dailyAdvice,
        status: AiRequestStatus.succeeded,
        executionTimeMs: 1000,
        createdAt: newer,
      ));

      final all = await repository.getAllRequests();

      expect(all.first.createdAt, newer);
      expect(all.last.createdAt, older);
    });

    group('status filtering', () {
      setUp(() async {
        await repository.recordRequest(AiRequestLog(
          logId: repository.nextLogId(),
          userId: 'user-101',
          requestType: AiRequestType.dailyAdvice,
          status: AiRequestStatus.succeeded,
          executionTimeMs: 900,
          createdAt: DateTime(2026, 1, 1),
        ));
        await repository.recordRequest(AiRequestLog(
          logId: repository.nextLogId(),
          userId: 'user-102',
          requestType: AiRequestType.foodDetection,
          status: AiRequestStatus.failed,
          executionTimeMs: 500,
          errorMessage: 'quota exceeded',
          createdAt: DateTime(2026, 1, 2),
        ));
        await repository.recordRequest(AiRequestLog(
          logId: repository.nextLogId(),
          userId: 'user-103',
          requestType: AiRequestType.tripSummary,
          status: AiRequestStatus.failed,
          executionTimeMs: 3000,
          errorMessage: 'timeout',
          createdAt: DateTime(2026, 1, 3),
        ));
      });

      test('with no filter, getAllRequests returns every entry newest first',
          () async {
        final all = await repository.getAllRequests();

        expect(all, hasLength(3));
        expect(all.first.requestType, AiRequestType.tripSummary);
      });

      test('status narrows getAllRequests to that status', () async {
        final succeededOnly =
            await repository.getAllRequests(status: AiRequestStatus.succeeded);

        expect(succeededOnly, hasLength(1));
        expect(succeededOnly.single.requestType, AiRequestType.dailyAdvice);
      });

      test('getFailedRequests returns only failed entries, newest first',
          () async {
        final failed = await repository.getFailedRequests();

        expect(failed, hasLength(2));
        expect(failed.every((e) => e.status == AiRequestStatus.failed), isTrue);
        expect(failed.first.requestType, AiRequestType.tripSummary);
        expect(failed.last.requestType, AiRequestType.foodDetection);
      });
    });
  });
}
