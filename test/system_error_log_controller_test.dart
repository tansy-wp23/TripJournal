import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_system_error_log_repository.dart';
import 'package:tripjournal/data/system_error_log_repository.dart';
import 'package:tripjournal/features/admin/controller/system_error_log_controller.dart';
import 'package:tripjournal/models/system_error_log.dart';

void main() {
  late MockSystemErrorLogRepository repository;

  Future<void> seedThreeEntries() async {
    await repository.recordError(SystemErrorLog(
      logId: repository.nextLogId(),
      module: 'journal',
      severity: ErrorSeverity.warning,
      message: 'Low-confidence food detection match.',
      createdAt: DateTime(2026, 1, 1),
    ));
    await repository.recordError(SystemErrorLog(
      logId: repository.nextLogId(),
      module: 'trip',
      severity: ErrorSeverity.error,
      message: 'Trip summary generation failed.',
      stackTrace: 'GeminiException: quota exceeded',
      createdAt: DateTime(2026, 1, 2),
    ));
    await repository.recordError(SystemErrorLog(
      logId: repository.nextLogId(),
      module: 'journal',
      severity: ErrorSeverity.fatal,
      message: 'Unhandled exception saving entry.',
      createdAt: DateTime(2026, 1, 3),
    ));
  }

  setUp(() {
    repository = MockSystemErrorLogRepository(seed: []);
  });

  group('SystemErrorLogController', () {
    test('initial state has no entries, not loading, no error, no filters', () {
      final controller = SystemErrorLogController(repository);

      expect(controller.entries, isEmpty);
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
      expect(controller.moduleFilter, isNull);
      expect(controller.severityFilter, isNull);
      expect(controller.hasActiveFilter, isFalse);
    });

    test('load populates every recorded entry, newest first', () async {
      await seedThreeEntries();
      final controller = SystemErrorLogController(repository);

      await controller.load();

      expect(controller.error, isNull);
      expect(controller.entries, hasLength(3));
      expect(controller.entries.first.message, 'Unhandled exception saving entry.');
    });

    test('load also populates the distinct module list for the filter dropdown', () async {
      await seedThreeEntries();
      final controller = SystemErrorLogController(repository);

      await controller.load();

      expect(controller.availableModules, ['journal', 'trip']);
    });

    test('setModuleFilter narrows to that module and sets hasActiveFilter', () async {
      await seedThreeEntries();
      final controller = SystemErrorLogController(repository);
      await controller.load();

      await controller.setModuleFilter('journal');

      expect(controller.moduleFilter, 'journal');
      expect(controller.hasActiveFilter, isTrue);
      expect(controller.entries.every((e) => e.module == 'journal'), isTrue);
      expect(controller.entries, hasLength(2));
    });

    test('setSeverityFilter narrows to that severity', () async {
      await seedThreeEntries();
      final controller = SystemErrorLogController(repository);
      await controller.load();

      await controller.setSeverityFilter(ErrorSeverity.fatal);

      expect(controller.entries, hasLength(1));
      expect(controller.entries.single.severity, ErrorSeverity.fatal);
    });

    test('module and severity filters compose together', () async {
      await seedThreeEntries();
      final controller = SystemErrorLogController(repository);
      await controller.load();

      await controller.setModuleFilter('journal');
      await controller.setSeverityFilter(ErrorSeverity.fatal);

      expect(controller.entries, hasLength(1));
      expect(controller.entries.single.message, 'Unhandled exception saving entry.');
    });

    test('clearFilters resets every filter and reloads the full list', () async {
      await seedThreeEntries();
      final controller = SystemErrorLogController(repository);
      await controller.setModuleFilter('journal');
      await controller.setSeverityFilter(ErrorSeverity.fatal);

      await controller.clearFilters();

      expect(controller.moduleFilter, isNull);
      expect(controller.severityFilter, isNull);
      expect(controller.hasActiveFilter, isFalse);
      expect(controller.entries, hasLength(3));
    });

    test('loading is true during load, false after', () async {
      final controller = SystemErrorLogController(repository);

      final future = controller.load();
      expect(controller.loading, isTrue);
      await future;
      expect(controller.loading, isFalse);
    });

    test('a failing repository sets error and leaves entries empty', () async {
      final controller = SystemErrorLogController(_FailingSystemErrorLogRepository());

      await controller.load();

      expect(controller.entries, isEmpty);
      expect(controller.error, isNotNull);
      expect(controller.loading, isFalse);
    });

    test('retrying after a failure can succeed and clears the error', () async {
      final flaky = _FlakySystemErrorLogRepository();
      final controller = SystemErrorLogController(flaky);

      await controller.load();
      expect(controller.error, isNotNull);
      expect(controller.entries, isEmpty);

      flaky.shouldFail = false;
      await controller.load();

      expect(controller.error, isNull);
      expect(controller.entries, isNotEmpty);
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

class _FlakySystemErrorLogRepository implements SystemErrorLogRepository {
  bool shouldFail = true;

  @override
  Future<void> recordError(SystemErrorLog entry) async {}

  @override
  Future<List<SystemErrorLog>> getAllErrors({String? module, ErrorSeverity? severity}) async {
    if (shouldFail) throw Exception('mock backend unreachable');
    return [
      SystemErrorLog(
        logId: 'error-flaky-1',
        module: 'journal',
        severity: ErrorSeverity.warning,
        message: 'Recovered after retry.',
        createdAt: DateTime.now(),
      ),
    ];
  }
}
