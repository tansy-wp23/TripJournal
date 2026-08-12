import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_admin_access_attempt_log_repository.dart';
import 'package:tripjournal/data/mock_admin_audit_log_repository.dart';
import 'package:tripjournal/data/mock_admin_user_directory_repository.dart';
import 'package:tripjournal/data/mock_admin_user_store.dart';
import 'package:tripjournal/features/admin/controller/admin_user_detail_controller.dart';
import 'package:tripjournal/models/admin_access_attempt_log.dart';
import 'package:tripjournal/models/admin_audit_log.dart';
import 'package:tripjournal/models/profile.dart';

void main() {
  late MockAdminUserStore store;
  late MockAdminUserDirectoryRepository directoryRepository;
  late MockAdminAuditLogRepository auditLogRepository;
  late MockAdminAccessAttemptLogRepository accessAttemptLogRepository;
  late AdminUserDetailController controller;

  setUp(() {
    store = MockAdminUserStore();
    directoryRepository = MockAdminUserDirectoryRepository(store);
    auditLogRepository = MockAdminAuditLogRepository();
    accessAttemptLogRepository = MockAdminAccessAttemptLogRepository();
    controller = AdminUserDetailController(
      directoryRepository,
      auditLogRepository,
      accessAttemptLogRepository,
    );
  });

  group('AdminUserDetailController', () {
    test('initial state has no profile, not loading, no error', () {
      expect(controller.profile, isNull);
      expect(controller.auditHistory, isEmpty);
      expect(controller.accessAttempts, isEmpty);
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
    });

    test('load fetches the profile for a known user id', () async {
      await controller.load('user-101');

      expect(controller.profile, isNotNull);
      expect(controller.profile!.displayName, 'Alice Tan');
      expect(controller.error, isNull);
    });

    test('load with an unknown user id sets an error and leaves profile null',
        () async {
      await controller.load('nonexistent-999');

      expect(controller.profile, isNull);
      expect(controller.error, isNotNull);
    });

    test('load also fetches audit history for that user', () async {
      await auditLogRepository.recordAction(AdminAuditLog(
        logId: auditLogRepository.nextLogId(),
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.user,
        targetId: 'user-101',
        action: AdminAction.suspend,
        reason: 'Reported for spam',
        createdAt: DateTime.now(),
      ));

      await controller.load('user-101');

      expect(controller.auditHistory, hasLength(1));
      expect(controller.auditHistory.single.action, AdminAction.suspend);
      expect(controller.auditHistory.single.reason, 'Reported for spam');
    });

    test('load also fetches access-attempt history for that user', () async {
      await accessAttemptLogRepository.recordAttempt(AdminAccessAttemptLog(
        logId: accessAttemptLogRepository.nextLogId(),
        attemptedUserId: 'user-101',
        attemptedEmail: 'alice.tan@example.com',
        reason: AdminAccessAttemptReason.notAnAdmin,
        createdAt: DateTime.now(),
      ));

      await controller.load('user-101');

      expect(controller.accessAttempts, hasLength(1));
      expect(controller.accessAttempts.single.reason, AdminAccessAttemptReason.notAnAdmin);
    });

    test('audit/access-attempt history only includes entries for this user',
        () async {
      await auditLogRepository.recordAction(AdminAuditLog(
        logId: auditLogRepository.nextLogId(),
        adminUserId: 'admin-001',
        targetType: AdminAuditTargetType.user,
        targetId: 'user-102',
        action: AdminAction.suspend,
        createdAt: DateTime.now(),
      ));

      await controller.load('user-101');

      expect(controller.auditHistory, isEmpty);
    });

    test('load can be called again to refresh and reflects the latest '
        'status (e.g. after a future suspend/reactivate action)', () async {
      await controller.load('user-101');
      expect(controller.profile!.isActive, isTrue);

      final index = store.profiles.indexWhere((p) => p.userID == 'user-101');
      store.profiles[index] =
          store.profiles[index].copyWith(status: AccountStatus.suspended);

      await controller.load('user-101');

      expect(controller.profile!.isSuspended, isTrue);
    });

    test('loading is true during load, false after', () async {
      final future = controller.load('user-101');
      expect(controller.loading, isTrue);
      await future;
      expect(controller.loading, isFalse);
    });
  });
}
