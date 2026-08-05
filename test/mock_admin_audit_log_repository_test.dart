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

    test('recordAction then getHistoryForUser returns the entry', () async {
      final entry = AdminAuditLog(
        logId: repository.nextLogId(),
        adminUserId: 'admin-001',
        targetUserId: 'user-101',
        action: AdminAction.suspend,
        reason: 'Reported for spam',
        createdAt: DateTime.now(),
      );

      await repository.recordAction(entry);
      final history = await repository.getHistoryForUser('user-101');

      expect(history, hasLength(1));
      expect(history.single.action, AdminAction.suspend);
      expect(history.single.reason, 'Reported for spam');
    });

    test('getHistoryForUser only returns entries for that user', () async {
      await repository.recordAction(AdminAuditLog(
        logId: repository.nextLogId(),
        adminUserId: 'admin-001',
        targetUserId: 'user-101',
        action: AdminAction.suspend,
        createdAt: DateTime.now(),
      ));
      await repository.recordAction(AdminAuditLog(
        logId: repository.nextLogId(),
        adminUserId: 'admin-001',
        targetUserId: 'user-102',
        action: AdminAction.suspend,
        createdAt: DateTime.now(),
      ));

      final history = await repository.getHistoryForUser('user-102');

      expect(history, hasLength(1));
      expect(history.single.targetUserId, 'user-102');
    });

    test('getHistoryForUser returns newest first', () async {
      final older = DateTime.now().subtract(const Duration(days: 1));
      final newer = DateTime.now();

      await repository.recordAction(AdminAuditLog(
        logId: repository.nextLogId(),
        adminUserId: 'admin-001',
        targetUserId: 'user-101',
        action: AdminAction.suspend,
        createdAt: older,
      ));
      await repository.recordAction(AdminAuditLog(
        logId: repository.nextLogId(),
        adminUserId: 'admin-001',
        targetUserId: 'user-101',
        action: AdminAction.reactivate,
        createdAt: newer,
      ));

      final history = await repository.getHistoryForUser('user-101');

      expect(history.first.action, AdminAction.reactivate);
      expect(history.last.action, AdminAction.suspend);
    });
  });
}