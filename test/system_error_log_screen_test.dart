import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_system_error_log_repository.dart';
import 'package:tripjournal/data/system_error_log_repository.dart';
import 'package:tripjournal/features/admin/controller/system_error_log_controller.dart';
import 'package:tripjournal/features/admin/screens/system_error_log_screen.dart';
import 'package:tripjournal/models/system_error_log.dart';

void main() {
  late MockSystemErrorLogRepository repository;

  Future<void> seedThreeEntries() async {
    await repository.recordError(
      SystemErrorLog(
        logId: repository.nextLogId(),
        module: 'journal',
        severity: ErrorSeverity.warning,
        message: 'Low-confidence food detection match.',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repository.recordError(
      SystemErrorLog(
        logId: repository.nextLogId(),
        module: 'trip',
        severity: ErrorSeverity.error,
        message: 'Trip summary generation failed.',
        stackTrace: 'GeminiException: quota exceeded',
        createdAt: DateTime(2026, 1, 2),
      ),
    );
    await repository.recordError(
      SystemErrorLog(
        logId: repository.nextLogId(),
        module: 'journal',
        severity: ErrorSeverity.fatal,
        message: 'Unhandled exception saving entry.',
        createdAt: DateTime(2026, 1, 3),
      ),
    );
  }

  setUp(() {
    repository = MockSystemErrorLogRepository(seed: []);
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    SystemErrorLogController controller,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          systemErrorLogControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: SystemErrorLogScreen()),
      ),
    );
    await tester.pump(); // triggers the post-frame load callback
    await tester.pumpAndSettle();
  }

  group('SystemErrorLogScreen', () {
    testWidgets('loads and shows every seeded entry', (tester) async {
      await seedThreeEntries();
      await pumpScreen(tester, SystemErrorLogController(repository));

      expect(
        find.byKey(const Key('admin-system-error-results')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Low-confidence food detection match.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Trip summary generation failed.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Unhandled exception saving entry.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping the Fatal severity chip narrows to fatal entries', (
      tester,
    ) async {
      await seedThreeEntries();
      await pumpScreen(tester, SystemErrorLogController(repository));

      await tester.tap(
        find.byKey(const Key('admin-system-error-severity-fatal')),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Unhandled exception saving entry.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Trip summary generation failed.'),
        findsNothing,
      );
    });

    testWidgets(
      'tapping All severities after a filter restores the full list',
      (tester) async {
        await seedThreeEntries();
        await pumpScreen(tester, SystemErrorLogController(repository));

        await tester.tap(
          find.byKey(const Key('admin-system-error-severity-fatal')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'All severities'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Trip summary generation failed.'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Unhandled exception saving entry.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('the module filter narrows results', (tester) async {
      await seedThreeEntries();
      await pumpScreen(tester, SystemErrorLogController(repository));

      await tester.tap(
        find.byKey(const Key('admin-system-error-module-filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('trip').last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Trip summary generation failed.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Low-confidence food detection match.'),
        findsNothing,
      );
    });

    testWidgets(
      'the clear-filters action appears only once a filter is active, and resets it',
      (tester) async {
        await seedThreeEntries();
        await pumpScreen(tester, SystemErrorLogController(repository));

        expect(
          find.byKey(const Key('admin-system-error-clear-filters')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const Key('admin-system-error-severity-fatal')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('admin-system-error-clear-filters')),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Clear filters'),
          findsOneWidget,
        );
        expect(tester.widget<AppBar>(find.byType(AppBar)).actions, isEmpty);

        await tester.tap(
          find.byKey(const Key('admin-system-error-clear-filters')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('admin-system-error-clear-filters')),
          findsNothing,
        );
        expect(
          find.textContaining('Trip summary generation failed.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('tapping an entry with a stack trace opens its detail dialog', (
      tester,
    ) async {
      await seedThreeEntries();
      await pumpScreen(tester, SystemErrorLogController(repository));

      await tester.tap(find.textContaining('Trip summary generation failed.'));
      await tester.pumpAndSettle();

      expect(find.text('GeminiException: quota exceeded'), findsOneWidget);
    });

    testWidgets('an entry with no stack trace is not tappable', (tester) async {
      await seedThreeEntries();
      await pumpScreen(tester, SystemErrorLogController(repository));

      await tester.tap(
        find.textContaining('Low-confidence food detection match.'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('no entries at all shows the empty state, not a blank list', (
      tester,
    ) async {
      await pumpScreen(tester, SystemErrorLogController(repository));

      expect(
        find.byKey(const Key('admin-system-error-empty-state')),
        findsOneWidget,
      );
      expect(find.text('No errors have been recorded.'), findsOneWidget);
      expect(find.byKey(const Key('admin-system-error-results')), findsNothing);
    });

    testWidgets(
      'a filter matching nobody shows a filter-specific empty state',
      (tester) async {
        await repository.recordError(
          SystemErrorLog(
            logId: repository.nextLogId(),
            module: 'journal',
            severity: ErrorSeverity.info,
            message: 'Informational only.',
            createdAt: DateTime.now(),
          ),
        );
        await pumpScreen(tester, SystemErrorLogController(repository));

        await tester.tap(
          find.byKey(const Key('admin-system-error-severity-fatal')),
        );
        await tester.pumpAndSettle();

        expect(find.text('No errors match these filters.'), findsOneWidget);
      },
    );

    testWidgets('a failing repository shows an error with a retry button', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        SystemErrorLogController(_FailingSystemErrorLogRepository()),
      );

      expect(find.byKey(const Key('admin-system-error-retry')), findsOneWidget);
    });
  });
}

class _FailingSystemErrorLogRepository implements SystemErrorLogRepository {
  @override
  Future<void> recordError(SystemErrorLog entry) async {}

  @override
  Future<List<SystemErrorLog>> getAllErrors({
    String? module,
    ErrorSeverity? severity,
  }) async {
    throw Exception('mock backend unreachable');
  }
}
