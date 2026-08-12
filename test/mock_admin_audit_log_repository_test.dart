import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_admin_audit_log_repository.dart';
import 'package:tripjournal/models/admin_audit_log.dart';

void main() {
  late MockAdminAuditLogRepository repository;

  setUp(() {
    repository = MockAdminAuditLogRepository();
  });

  group('MockAdminAuditLogRepository', () {
    test('nextLogId returns unique ids on successive calls', () {
      final ids = {for (var i = 0; i < 5; i++) repository.nextLogId()};

      expect(ids, hasLength(5));
    });

    test('recordAction then getHistoryForTarget returns the entry', () async {
      final entry = AdminAuditLog(
        logId: repository.nextLogId(),
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.user,
        targetId: 'user-101',
        action: AdminAction.suspend,
        reason: 'Reported for spam',
        createdAt: DateTime.now(),
      );

      await repository.recordAction(entry);
      final history = await repository.getHistoryForTarget(
        targetType: AdminAuditTargetType.user,
        targetId: 'user-101',
      );

      expect(history, hasLength(1));
      expect(history.single.action, AdminAction.suspend);
      expect(history.single.reason, 'Reported for spam');
    });

    test('getHistoryForTarget only returns entries for that exact target',
        () async {
      await repository.recordAction(AdminAuditLog(
        logId: repository.nextLogId(),
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.user,
        targetId: 'user-101',
        action: AdminAction.suspend,
        createdAt: DateTime.now(),
      ));
      await repository.recordAction(AdminAuditLog(
        logId: repository.nextLogId(),
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.user,
        targetId: 'user-102',
        action: AdminAction.suspend,
        createdAt: DateTime.now(),
      ));

      final history = await repository.getHistoryForTarget(
        targetType: AdminAuditTargetType.user,
        targetId: 'user-102',
      );

      expect(history, hasLength(1));
      expect(history.single.targetId, 'user-102');
    });

    test('getHistoryForTarget distinguishes target types with the same id',
        () async {
      // A user id and an issue-report id could coincidentally collide;
      // targetType must disambiguate them.
      await repository.recordAction(AdminAuditLog(
        logId: repository.nextLogId(),
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.user,
        targetId: 'shared-id-1',
        action: AdminAction.suspend,
        createdAt: DateTime.now(),
      ));
      await repository.recordAction(AdminAuditLog(
        logId: repository.nextLogId(),
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.issueReport,
        targetId: 'shared-id-1',
        action: AdminAction.issueMarkResolved,
        createdAt: DateTime.now(),
      ));

      final userHistory = await repository.getHistoryForTarget(
        targetType: AdminAuditTargetType.user,
        targetId: 'shared-id-1',
      );
      final issueHistory = await repository.getHistoryForTarget(
        targetType: AdminAuditTargetType.issueReport,
        targetId: 'shared-id-1',
      );

      expect(userHistory, hasLength(1));
      expect(userHistory.single.action, AdminAction.suspend);
      expect(issueHistory, hasLength(1));
      expect(issueHistory.single.action, AdminAction.issueMarkResolved);
    });

    test('getHistoryForTarget returns newest first', () async {
      final older = DateTime.now().subtract(const Duration(days: 1));
      final newer = DateTime.now();

      await repository.recordAction(AdminAuditLog(
        logId: repository.nextLogId(),
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.user,
        targetId: 'user-101',
        action: AdminAction.suspend,
        createdAt: older,
      ));
      await repository.recordAction(AdminAuditLog(
        logId: repository.nextLogId(),
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.user,
        targetId: 'user-101',
        action: AdminAction.reactivate,
        createdAt: newer,
      ));

      final history = await repository.getHistoryForTarget(
        targetType: AdminAuditTargetType.user,
        targetId: 'user-101',
      );

      expect(history.first.action, AdminAction.reactivate);
      expect(history.last.action, AdminAction.suspend);
    });

    group('getAllEntries', () {
      setUp(() async {
        await repository.recordAction(AdminAuditLog(
          logId: repository.nextLogId(),
          adminUserId: 'admin-001',
          targetType: AdminAuditTargetType.user,
          targetId: 'user-101',
          action: AdminAction.suspend,
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
          adminUserId: 'admin-001',
          targetType: AdminAuditTargetType.issueReport,
          targetId: 'issue-1',
          action: AdminAction.issueMarkResolved,
          createdAt: DateTime(2026, 1, 3),
        ));
      });

      test('with no filters, returns every entry newest first', () async {
        final all = await repository.getAllEntries();

        expect(all, hasLength(3));
        expect(all.first.action, AdminAction.issueMarkResolved);
        expect(all.last.action, AdminAction.suspend);
      });

      test('targetTypeFilter narrows to that target type', () async {
        final userOnly =
            await repository.getAllEntries(targetTypeFilter: AdminAuditTargetType.user);

        expect(userOnly, hasLength(2));
        expect(userOnly.every((e) => e.targetType == AdminAuditTargetType.user), isTrue);
      });

      test('actionFilter narrows to that action', () async {
        final suspendOnly = await repository.getAllEntries(actionFilter: AdminAction.suspend);

        expect(suspendOnly, hasLength(1));
        expect(suspendOnly.single.action, AdminAction.suspend);
      });

      test('startDate/endDate narrow to that window', () async {
        final windowed = await repository.getAllEntries(
          startDate: DateTime(2026, 1, 2),
          endDate: DateTime(2026, 1, 2, 23, 59),
        );

        expect(windowed, hasLength(1));
        expect(windowed.single.action, AdminAction.reactivate);
      });

      test('filters compose together', () async {
        final result = await repository.getAllEntries(
          targetTypeFilter: AdminAuditTargetType.user,
          actionFilter: AdminAction.reactivate,
        );

        expect(result, hasLength(1));
        expect(result.single.targetId, 'user-101');
      });
    });
  });
}
