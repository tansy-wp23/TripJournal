import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_system_error_log_repository.dart';
import 'package:tripjournal/data/system_error_log_repository.dart';
import 'package:tripjournal/error_reporting.dart';
import 'package:tripjournal/models/system_error_log.dart';

void main() {
  group('reportSystemError', () {
    // `systemErrorLogRepository` (the real, admin_repository_locator.dart
    // global) is Supabase-backed since Phase 21 and can no longer be
    // touched from a plain test — every call now goes through the
    // `repository` override parameter instead, injecting a
    // `MockSystemErrorLogRepository` directly.
    late MockSystemErrorLogRepository repository;

    setUp(() {
      repository = MockSystemErrorLogRepository(seed: []);
    });

    test('records an entry with the given message, stack trace, and severity',
        () async {
      final error = Exception('boom');
      final stack = StackTrace.current;

      reportSystemError(error, stack, severity: ErrorSeverity.error, repository: repository);
      // recordError's Future resolves after one microtask hop — flush it.
      await Future<void>.delayed(Duration.zero);

      final entries = await repository.getAllErrors();
      final recorded = entries.single;
      expect(recorded.message, error.toString());
      expect(recorded.severity, ErrorSeverity.error);
      expect(recorded.stackTrace, stack.toString());
      expect(recorded.module, 'app');
    });

    test('defaults to fatal severity when none is given', () async {
      final error = Exception('unhandled-async-error');

      reportSystemError(error, null, repository: repository);
      await Future<void>.delayed(Duration.zero);

      final entries = await repository.getAllErrors();
      final recorded = entries.single;
      expect(recorded.severity, ErrorSeverity.fatal);
      expect(recorded.stackTrace, isNull);
    });

    test('a logging failure (e.g. the repository throwing) never propagates '
        'out of the error handler itself', () {
      expect(
        () => reportSystemError(
          Exception('boom'),
          null,
          repository: _FailingSystemErrorLogRepository(),
        ),
        returnsNormally,
      );
    });
  });
}

class _FailingSystemErrorLogRepository implements SystemErrorLogRepository {
  @override
  Future<void> recordError(SystemErrorLog entry) {
    throw Exception('backend unreachable');
  }

  @override
  Future<List<SystemErrorLog>> getAllErrors({String? module, ErrorSeverity? severity}) async => [];
}
