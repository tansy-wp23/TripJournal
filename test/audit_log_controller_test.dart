import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/admin_audit_log_repository.dart';
import 'package:tripjournal/data/admin_user_directory_repository.dart';
import 'package:tripjournal/data/issue_report_repository.dart';
import 'package:tripjournal/data/mock_admin_audit_log_repository.dart';
import 'package:tripjournal/data/mock_admin_user_directory_repository.dart';
import 'package:tripjournal/data/mock_admin_user_store.dart';
import 'package:tripjournal/data/mock_issue_report_repository.dart';
import 'package:tripjournal/features/admin/controller/audit_log_controller.dart';
import 'package:tripjournal/models/admin_audit_log.dart';
import 'package:tripjournal/models/profile.dart';

void main() {
  late MockAdminAuditLogRepository repository;

  // Builds a controller against the default seeded MockAdminUserStore
  // (admin-001 "Admin Account", user-101 "Alice Tan", …) and
  // MockIssueReportRepository (issue-001 … issue-004) unless overridden —
  // real-looking name resolution without every test having to seed its own.
  AuditLogController buildController(
    AdminAuditLogRepository auditLogRepository, {
    AdminUserDirectoryRepository? userDirectoryRepository,
    IssueReportRepository? issueReportRepository,
  }) {
    return AuditLogController(
      auditLogRepository,
      userDirectoryRepository ?? MockAdminUserDirectoryRepository(MockAdminUserStore()),
      issueReportRepository ?? MockIssueReportRepository(auditLogRepository: MockAdminAuditLogRepository()),
    );
  }

  Future<void> seedThreeEntries() async {
    await repository.recordAction(AdminAuditLog(
      logId: repository.nextLogId(),
      adminUserId: 'admin-001',
      targetType: AdminAuditTargetType.user,
      targetId: 'user-101',
      action: AdminAction.suspend,
      reason: 'Reported for spam',
      createdAt: DateTime(2026, 1, 1),
    ));
    await repository.recordAction(AdminAuditLog(
      logId: repository.nextLogId(),
      adminUserId: 'admin-001',
      targetType: AdminAuditTargetType.user,
      targetId: 'user-101',
      action: AdminAction.reactivate,
      createdAt: DateTime(2026, 1, 2),
    ));
    await repository.recordAction(AdminAuditLog(
      logId: repository.nextLogId(),
      adminUserId: 'admin-002',
      targetType: AdminAuditTargetType.issueReport,
      targetId: 'issue-1',
      action: AdminAction.issueMarkResolved,
      createdAt: DateTime(2026, 1, 3),
    ));
  }

  setUp(() {
    repository = MockAdminAuditLogRepository();
  });

  group('AuditLogController', () {
    test('initial state has no entries, not loading, no error, no filters',
        () {
      final controller = buildController(repository);

      expect(controller.entries, isEmpty);
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
      expect(controller.targetTypeFilter, isNull);
      expect(controller.actionFilter, isNull);
      expect(controller.startDate, isNull);
      expect(controller.endDate, isNull);
      expect(controller.hasActiveFilter, isFalse);
    });

    test('load populates every recorded entry, newest first', () async {
      await seedThreeEntries();
      final controller = buildController(repository);

      await controller.load();

      expect(controller.error, isNull);
      expect(controller.entries, hasLength(3));
      expect(controller.entries.first.action, AdminAction.issueMarkResolved);
    });

    test('setTargetTypeFilter narrows to that target type and sets '
        'hasActiveFilter', () async {
      await seedThreeEntries();
      final controller = buildController(repository);
      await controller.load();

      await controller.setTargetTypeFilter(AdminAuditTargetType.user);

      expect(controller.targetTypeFilter, AdminAuditTargetType.user);
      expect(controller.hasActiveFilter, isTrue);
      expect(
        controller.entries.every((e) => e.targetType == AdminAuditTargetType.user),
        isTrue,
      );
      expect(controller.entries, hasLength(2));
    });

    test('switching target type drops an action filter that no longer '
        'applies to it', () async {
      await seedThreeEntries();
      final controller = buildController(repository);
      await controller.setTargetTypeFilter(AdminAuditTargetType.issueReport);
      await controller.setActionFilter(AdminAction.issueMarkResolved);
      expect(controller.actionFilter, AdminAction.issueMarkResolved);

      await controller.setTargetTypeFilter(AdminAuditTargetType.user);

      expect(controller.actionFilter, isNull);
      expect(controller.entries.every((e) => e.targetType == AdminAuditTargetType.user), isTrue);
    });

    test('setActionFilter narrows to that action', () async {
      await seedThreeEntries();
      final controller = buildController(repository);
      await controller.load();

      await controller.setActionFilter(AdminAction.suspend);

      expect(controller.entries, hasLength(1));
      expect(controller.entries.single.action, AdminAction.suspend);
    });

    test('setDateRange narrows to that window', () async {
      await seedThreeEntries();
      final controller = buildController(repository);
      await controller.load();

      await controller.setDateRange(start: DateTime(2026, 1, 2), end: DateTime(2026, 1, 2, 23, 59));

      expect(controller.entries, hasLength(1));
      expect(controller.entries.single.action, AdminAction.reactivate);
    });

    test('clearFilters resets every filter and reloads the full list',
        () async {
      await seedThreeEntries();
      final controller = buildController(repository);
      await controller.setTargetTypeFilter(AdminAuditTargetType.user);
      await controller.setActionFilter(AdminAction.suspend);

      await controller.clearFilters();

      expect(controller.targetTypeFilter, isNull);
      expect(controller.actionFilter, isNull);
      expect(controller.startDate, isNull);
      expect(controller.endDate, isNull);
      expect(controller.hasActiveFilter, isFalse);
      expect(controller.entries, hasLength(3));
    });

    test('loading is true during load, false after', () async {
      final controller = buildController(repository);

      final future = controller.load();
      expect(controller.loading, isTrue);
      await future;
      expect(controller.loading, isFalse);
    });

    test('a failing repository sets error and leaves entries empty',
        () async {
      final controller = buildController(_FailingAuditLogRepository());

      await controller.load();

      expect(controller.entries, isEmpty);
      expect(controller.error, isNotNull);
      expect(controller.loading, isFalse);
    });

    test('retrying after a failure can succeed and clears the error',
        () async {
      final flaky = _FlakyAuditLogRepository();
      final controller = buildController(flaky);

      await controller.load();
      expect(controller.error, isNotNull);
      expect(controller.entries, isEmpty);

      flaky.shouldFail = false;
      await controller.load();

      expect(controller.error, isNull);
      expect(controller.entries, isNotEmpty);
    });

    group('label resolution', () {
      test('adminLabel resolves a known admin to their display name',
          () async {
        await repository.recordAction(AdminAuditLog(
          logId: repository.nextLogId(),
          adminUserId: 'admin-001', // seeded as "Admin Account"
          targetType: AdminAuditTargetType.user,
          targetId: 'user-101',
          action: AdminAction.suspend,
          createdAt: DateTime.now(),
        ));
        final controller = buildController(repository);
        await controller.load();

        expect(controller.adminLabel('admin-001'), 'Admin Account');
      });

      test('adminLabel falls back to the raw id for an unresolvable admin',
          () async {
        await repository.recordAction(AdminAuditLog(
          logId: repository.nextLogId(),
          adminUserId: 'admin-since-deleted',
          targetType: AdminAuditTargetType.user,
          targetId: 'user-101',
          action: AdminAction.suspend,
          createdAt: DateTime.now(),
        ));
        final controller = buildController(repository);
        await controller.load();

        expect(controller.adminLabel('admin-since-deleted'), 'admin-since-deleted');
      });

      test('targetLabel resolves a known user target to their display name',
          () async {
        await repository.recordAction(AdminAuditLog(
          logId: repository.nextLogId(),
          adminUserId: 'admin-001',
          targetType: AdminAuditTargetType.user,
          targetId: 'user-101', // seeded as "Alice Tan"
          action: AdminAction.suspend,
          createdAt: DateTime.now(),
        ));
        final controller = buildController(repository);
        await controller.load();

        expect(controller.targetLabel(controller.entries.single), 'Alice Tan');
      });

      test('targetLabel resolves a known issue-report target to its '
          'description', () async {
        final issueRepository = MockIssueReportRepository(
          auditLogRepository: MockAdminAuditLogRepository(),
        );
        await repository.recordAction(AdminAuditLog(
          logId: repository.nextLogId(),
          adminUserId: 'admin-001',
          targetType: AdminAuditTargetType.issueReport,
          targetId: 'issue-001',
          action: AdminAction.issueMarkResolved,
          createdAt: DateTime.now(),
        ));
        final controller = buildController(repository, issueReportRepository: issueRepository);
        await controller.load();

        expect(
          controller.targetLabel(controller.entries.single),
          'Cover photo fails to upload when offline.',
        );
      });

      test('targetLabel falls back to the raw id when the target no longer '
          'resolves', () async {
        await repository.recordAction(AdminAuditLog(
          logId: repository.nextLogId(),
          adminUserId: 'admin-001',
          targetType: AdminAuditTargetType.issueReport,
          targetId: 'issue-since-deleted',
          action: AdminAction.issueMarkResolved,
          createdAt: DateTime.now(),
        ));
        final controller = buildController(repository);
        await controller.load();

        expect(controller.targetLabel(controller.entries.single), 'issue-since-deleted');
      });

      test('a naming lookup failure does not block entries from loading',
          () async {
        await seedThreeEntries();
        final controller = buildController(
          repository,
          userDirectoryRepository: _FailingUserDirectoryRepository(),
        );

        await controller.load();

        expect(controller.error, isNull);
        expect(controller.entries, hasLength(3));
        // Falls back to the raw id rather than propagating the lookup error.
        expect(controller.adminLabel('admin-001'), 'admin-001');
      });
    });
  });

  group('actionsForTargetType', () {
    test('null returns every action', () {
      expect(actionsForTargetType(null), AdminAction.values);
    });

    test('user returns only suspend/reactivate', () {
      expect(
        actionsForTargetType(AdminAuditTargetType.user),
        [AdminAction.suspend, AdminAction.reactivate],
      );
    });

    test('issueReport returns only the three issue actions', () {
      expect(
        actionsForTargetType(AdminAuditTargetType.issueReport),
        [AdminAction.issueMarkInProgress, AdminAction.issueMarkResolved, AdminAction.issueReopen],
      );
    });
  });
}

class _FailingAuditLogRepository implements AdminAuditLogRepository {
  @override
  Future<void> recordAction(AdminAuditLog entry) async {}

  @override
  Future<List<AdminAuditLog>> getHistoryForTarget({
    required AdminAuditTargetType targetType,
    required String targetId,
  }) async =>
      [];

  @override
  Future<List<AdminAuditLog>> getAllEntries({
    AdminAuditTargetType? targetTypeFilter,
    AdminAction? actionFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    throw Exception('mock backend unreachable');
  }
}

class _FlakyAuditLogRepository implements AdminAuditLogRepository {
  bool shouldFail = true;

  @override
  Future<void> recordAction(AdminAuditLog entry) async {}

  @override
  Future<List<AdminAuditLog>> getHistoryForTarget({
    required AdminAuditTargetType targetType,
    required String targetId,
  }) async =>
      [];

  @override
  Future<List<AdminAuditLog>> getAllEntries({
    AdminAuditTargetType? targetTypeFilter,
    AdminAction? actionFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (shouldFail) throw Exception('mock backend unreachable');
    return [
      AdminAuditLog(
        logId: 'audit-flaky-1',
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.user,
        targetId: 'user-101',
        action: AdminAction.suspend,
        createdAt: DateTime.now(),
      ),
    ];
  }
}

class _FailingUserDirectoryRepository implements AdminUserDirectoryRepository {
  @override
  Future<List<Profile>> searchUsers({String? query}) async => [];

  @override
  Future<Profile?> getUserById(String userId) async {
    throw Exception('mock backend unreachable');
  }
}
