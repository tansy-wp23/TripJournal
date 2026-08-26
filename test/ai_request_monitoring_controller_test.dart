import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/ai_request_log_repository.dart';
import 'package:tripjournal/data/mock_ai_request_log_repository.dart';
import 'package:tripjournal/features/admin/controller/ai_request_monitoring_controller.dart';
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

  group('AiRequestMonitoringController', () {
    test('initial state has no entries, not loading, no error, no filter', () {
      final controller = AiRequestMonitoringController(repository);

      expect(controller.entries, isEmpty);
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
      expect(controller.statusFilter, isNull);
      expect(controller.hasActiveFilter, isFalse);
    });

    test('load populates every recorded entry, newest first', () async {
      await seedTwoEntries();
      final controller = AiRequestMonitoringController(repository);

      await controller.load();

      expect(controller.error, isNull);
      expect(controller.entries, hasLength(2));
      expect(controller.entries.first.requestType, AiRequestType.foodDetection);
    });

    test('setStatusFilter narrows to that status and sets hasActiveFilter', () async {
      await seedTwoEntries();
      final controller = AiRequestMonitoringController(repository);
      await controller.load();

      await controller.setStatusFilter(AiRequestStatus.failed);

      expect(controller.statusFilter, AiRequestStatus.failed);
      expect(controller.hasActiveFilter, isTrue);
      expect(controller.entries, hasLength(1));
      expect(controller.entries.single.status, AiRequestStatus.failed);
    });

    test('clearFilters resets the filter and reloads the full list', () async {
      await seedTwoEntries();
      final controller = AiRequestMonitoringController(repository);
      await controller.setStatusFilter(AiRequestStatus.failed);

      await controller.clearFilters();

      expect(controller.statusFilter, isNull);
      expect(controller.hasActiveFilter, isFalse);
      expect(controller.entries, hasLength(2));
    });

    test('loading is true during load, false after', () async {
      final controller = AiRequestMonitoringController(repository);

      final future = controller.load();
      expect(controller.loading, isTrue);
      await future;
      expect(controller.loading, isFalse);
    });

    test('a failing repository sets error and leaves entries empty', () async {
      final controller = AiRequestMonitoringController(_FailingAiRequestLogRepository());

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
  Future<List<AiRequestLog>> getAllRequests({AiRequestStatus? status}) async {
    throw Exception('mock backend unreachable');
  }

  @override
  Future<List<AiRequestLog>> getFailedRequests() async {
    throw Exception('mock backend unreachable');
  }
}
