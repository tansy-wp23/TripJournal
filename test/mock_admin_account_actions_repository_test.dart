import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_admin_account_actions_repository.dart';
import 'package:tripjournal/data/mock_admin_audit_log_repository.dart';
import 'package:tripjournal/data/mock_admin_user_store.dart';
import 'package:tripjournal/models/admin_audit_log.dart';
import 'package:tripjournal/models/profile.dart';

void main() {
  late MockAdminUserStore store;
  late MockAdminAuditLogRepository auditLogRepository;
  late MockAdminAccountActionsRepository repository;

  setUp(() {
    store = MockAdminUserStore();
    auditLogRepository = MockAdminAuditLogRepository();
    repository = MockAdminAccountActionsRepository(
      store: store,
      auditLogRepository: auditLogRepository,
    );
  });

  group('MockAdminAccountActionsRepository', () {
    test('suspendUser sets status to suspended and stamps deactivatedAt',
        () async {
      await repository.suspendUser(
        adminUserId: 'admin-001',
        targetUserId: 'user-101',
        reason: 'Reported for spam',
      );

      final profile =
          store.profiles.firstWhere((p) => p.userID == 'user-101');
      expect(profile.status, AccountStatus.suspended);
      expect(profile.deactivatedAt, isNotNull);
    });

    test('suspendUser records an audit log entry with the reason', () async {
      await repository.suspendUser(
        adminUserId: 'admin-001',
        targetUserId: 'user-101',
        reason: 'Reported for spam',
      );

      final history = await auditLogRepository.getHistoryForUser('user-101');
      expect(history, hasLength(1));
      expect(history.single.action, AdminAction.suspend);
      expect(history.single.adminUserId, 'admin-001');
      expect(history.single.reason, 'Reported for spam');
    });

    test('reactivateUser sets status back to active and clears '
        'deactivatedAt', () async {
      await repository.suspendUser(
        adminUserId: 'admin-001',
        targetUserId: 'user-101',
      );

      await repository.reactivateUser(
        adminUserId: 'admin-001',
        targetUserId: 'user-101',
      );

      final profile =
          store.profiles.firstWhere((p) => p.userID == 'user-101');
      expect(profile.status, AccountStatus.active);
      expect(profile.deactivatedAt, isNull);
    });

    test('reactivateUser records an audit log entry', () async {
      await repository.reactivateUser(
        adminUserId: 'admin-001',
        targetUserId: 'user-103', // seeded as already suspended
      );

      final history = await auditLogRepository.getHistoryForUser('user-103');
      expect(history, hasLength(1));
      expect(history.single.action, AdminAction.reactivate);
    });

    test('suspendUser throws for an unknown user id', () async {
      expect(
        () => repository.suspendUser(
          adminUserId: 'admin-001',
          targetUserId: 'does-not-exist',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('reactivateUser throws for an unknown user id', () async {
      expect(
        () => repository.reactivateUser(
          adminUserId: 'admin-001',
          targetUserId: 'does-not-exist',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}