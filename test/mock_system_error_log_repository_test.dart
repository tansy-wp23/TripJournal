import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_system_error_log_repository.dart';
import 'package:tripjournal/models/system_error_log.dart';

void main() {
  late MockSystemErrorLogRepository repository;

  setUp(() {
    // Empty seed — tests control exactly what entries exist, mirroring
    // MockAdminAuditLogRepository's tests.
    repository = MockSystemErrorLogRepository(seed: []);
  });

  group('MockSystemErrorLogRepository', () {
    test('nextLogId returns unique ids on successive calls', () {
      final ids = {for (var i = 0; i < 5; i++) repository.nextLogId()};

      expect(ids, hasLength(5));
    });

    test('recordError then getAllErrors returns the entry', () async {
      final entry = SystemErrorLog(
        logId: repository.nextLogId(),
        module: 'journal',
        severity: ErrorSeverity.error,
        message: 'Upload failed.',
        createdAt: DateTime.now(),
      );

      await repository.recordError(entry);
      final all = await repository.getAllErrors();

      expect(all, hasLength(1));
      expect(all.single.module, 'journal');
      expect(all.single.severity, ErrorSeverity.error);
    });

    test('getAllErrors returns newest first', () async {
      final older = DateTime.now().subtract(const Duration(hours: 1));
      final newer = DateTime.now();

      await repository.recordError(SystemErrorLog(
        logId: repository.nextLogId(),
        module: 'journal',
        severity: ErrorSeverity.info,
        message: 'Older',
        createdAt: older,
      ));
      await repository.recordError(SystemErrorLog(
        logId: repository.nextLogId(),
        module: 'journal',
        severity: ErrorSeverity.info,
        message: 'Newer',
        createdAt: newer,
      ));

      final all = await repository.getAllErrors();

      expect(all.first.message, 'Newer');
      expect(all.last.message, 'Older');
    });

    group('filtering', () {
      setUp(() async {
        await repository.recordError(SystemErrorLog(
          logId: repository.nextLogId(),
          module: 'journal',
          severity: ErrorSeverity.warning,
          message: 'Journal warning',
          createdAt: DateTime(2026, 1, 1),
        ));
        await repository.recordError(SystemErrorLog(
          logId: repository.nextLogId(),
          module: 'trip',
          severity: ErrorSeverity.error,
          message: 'Trip error',
          createdAt: DateTime(2026, 1, 2),
        ));
        await repository.recordError(SystemErrorLog(
          logId: repository.nextLogId(),
          module: 'journal',
          severity: ErrorSeverity.fatal,
          message: 'Journal fatal',
          createdAt: DateTime(2026, 1, 3),
        ));
      });

      test('with no filters, returns every entry newest first', () async {
        final all = await repository.getAllErrors();

        expect(all, hasLength(3));
        expect(all.first.message, 'Journal fatal');
        expect(all.last.message, 'Journal warning');
      });

      test('module narrows to that module', () async {
        final journalOnly = await repository.getAllErrors(module: 'journal');

        expect(journalOnly, hasLength(2));
        expect(journalOnly.every((e) => e.module == 'journal'), isTrue);
      });

      test('severity narrows to that severity', () async {
        final errorsOnly =
            await repository.getAllErrors(severity: ErrorSeverity.error);

        expect(errorsOnly, hasLength(1));
        expect(errorsOnly.single.message, 'Trip error');
      });

      test('filters compose together', () async {
        final result = await repository.getAllErrors(
          module: 'journal',
          severity: ErrorSeverity.fatal,
        );

        expect(result, hasLength(1));
        expect(result.single.message, 'Journal fatal');
      });
    });
  });
}
