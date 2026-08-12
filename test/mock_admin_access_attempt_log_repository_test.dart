import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_admin_access_attempt_log_repository.dart';
import 'package:tripjournal/models/admin_access_attempt_log.dart';

void main() {
  late MockAdminAccessAttemptLogRepository repository;

  setUp(() {
    repository = MockAdminAccessAttemptLogRepository();
  });

  group('MockAdminAccessAttemptLogRepository', () {
    test('nextLogId returns unique ids on successive calls', () {
      final ids = {for (var i = 0; i < 5; i++) repository.nextLogId()};

      expect(ids, hasLength(5));
    });

    test('recordAttempt then getRecentAttempts returns the entry', () async {
      final entry = AdminAccessAttemptLog(
        logId: repository.nextLogId(),
        attemptedUserId: 'user-101',
        attemptedEmail: 'alice.tan@example.com',
        reason: AdminAccessAttemptReason.notAnAdmin,
        createdAt: DateTime.now(),
      );

      await repository.recordAttempt(entry);
      final recent = await repository.getRecentAttempts();

      expect(recent, hasLength(1));
      expect(recent.single.attemptedEmail, 'alice.tan@example.com');
      expect(recent.single.reason, AdminAccessAttemptReason.notAnAdmin);
    });

    test('getRecentAttempts returns newest first and honors limit', () async {
      final older = DateTime.now().subtract(const Duration(days: 1));
      final newer = DateTime.now();

      await repository.recordAttempt(AdminAccessAttemptLog(
        logId: repository.nextLogId(),
        attemptedUserId: 'user-101',
        attemptedEmail: 'alice.tan@example.com',
        reason: AdminAccessAttemptReason.notAnAdmin,
        createdAt: older,
      ));
      await repository.recordAttempt(AdminAccessAttemptLog(
        logId: repository.nextLogId(),
        attemptedUserId: 'user-102',
        attemptedEmail: 'brandon.lee@example.com',
        reason: AdminAccessAttemptReason.notAnAdmin,
        createdAt: newer,
      ));

      final all = await repository.getRecentAttempts();
      expect(all.first.attemptedUserId, 'user-102');
      expect(all.last.attemptedUserId, 'user-101');

      final limited = await repository.getRecentAttempts(limit: 1);
      expect(limited, hasLength(1));
      expect(limited.single.attemptedUserId, 'user-102');
    });

    test('getAttemptsForUserId only returns entries for that user', () async {
      await repository.recordAttempt(AdminAccessAttemptLog(
        logId: repository.nextLogId(),
        attemptedUserId: 'user-101',
        attemptedEmail: 'alice.tan@example.com',
        reason: AdminAccessAttemptReason.notAnAdmin,
        createdAt: DateTime.now(),
      ));
      await repository.recordAttempt(AdminAccessAttemptLog(
        logId: repository.nextLogId(),
        attemptedUserId: 'user-102',
        attemptedEmail: 'brandon.lee@example.com',
        reason: AdminAccessAttemptReason.notAnAdmin,
        createdAt: DateTime.now(),
      ));

      final matches = await repository.getAttemptsForUserId('user-102');

      expect(matches, hasLength(1));
      expect(matches.single.attemptedUserId, 'user-102');
    });
  });
}
