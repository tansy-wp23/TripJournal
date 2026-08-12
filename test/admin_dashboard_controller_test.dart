import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/admin_dashboard_repository.dart';
import 'package:tripjournal/data/mock_admin_access_attempt_log_repository.dart';
import 'package:tripjournal/data/mock_admin_dashboard_repository.dart';
import 'package:tripjournal/data/mock_admin_user_store.dart';
import 'package:tripjournal/features/admin/controller/admin_dashboard_controller.dart';
import 'package:tripjournal/models/admin_access_attempt_log.dart';
import 'package:tripjournal/models/admin_dashboard_stats.dart';
import 'package:tripjournal/models/profile.dart';

void main() {
  group('AdminDashboardController', () {
    test('initial state has no stats, no attempts, not loading, no error',
        () {
      final controller = AdminDashboardController(
        MockAdminDashboardRepository(MockAdminUserStore()),
        MockAdminAccessAttemptLogRepository(),
      );

      expect(controller.stats, isNull);
      expect(controller.recentAttempts, isEmpty);
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
    });

    test('loadStats populates stats matching the default seed', () async {
      final store = MockAdminUserStore();
      final controller = AdminDashboardController(
        MockAdminDashboardRepository(store),
        MockAdminAccessAttemptLogRepository(),
      );

      await controller.loadStats();

      expect(controller.error, isNull);
      expect(controller.stats, isNotNull);
      // Default seed: 1 admin, 5 travelers (3 active, 1 suspended, 1 deactivated).
      expect(controller.stats!.totalUsers, 6);
      expect(controller.stats!.adminUsers, 1);
      expect(controller.stats!.suspendedUsers, 1);
      expect(controller.stats!.deactivatedUsers, 1);
    });

    test('loadStats also populates recentAttempts from the log repository',
        () async {
      final accessAttemptLogRepository = MockAdminAccessAttemptLogRepository();
      await accessAttemptLogRepository.recordAttempt(
        AdminAccessAttemptLog(
          logId: accessAttemptLogRepository.nextLogId(),
          attemptedUserId: 'user-101',
          attemptedEmail: 'alice.tan@example.com',
          reason: AdminAccessAttemptReason.notAnAdmin,
          createdAt: DateTime.now(),
        ),
      );
      final controller = AdminDashboardController(
        MockAdminDashboardRepository(MockAdminUserStore()),
        accessAttemptLogRepository,
      );

      await controller.loadStats();

      expect(controller.recentAttempts, hasLength(1));
      expect(controller.recentAttempts.single.attemptedEmail, 'alice.tan@example.com');
    });

    test('a suspend action taken through the shared store is reflected on '
        'the next loadStats call', () async {
      final store = MockAdminUserStore();
      final controller = AdminDashboardController(
        MockAdminDashboardRepository(store),
        MockAdminAccessAttemptLogRepository(),
      );
      await controller.loadStats();
      final activeBefore = controller.stats!.activeUsers;
      final suspendedBefore = controller.stats!.suspendedUsers;

      final activeIndex = store.profiles.indexWhere((p) => p.isActive);
      store.profiles[activeIndex] =
          store.profiles[activeIndex].copyWith(status: AccountStatus.suspended);

      await controller.loadStats();

      expect(controller.stats!.activeUsers, activeBefore - 1);
      expect(controller.stats!.suspendedUsers, suspendedBefore + 1);
    });

    test('loading is true during loadStats, false after', () async {
      final controller = AdminDashboardController(
        MockAdminDashboardRepository(MockAdminUserStore()),
        MockAdminAccessAttemptLogRepository(),
      );

      final future = controller.loadStats();
      expect(controller.loading, isTrue);
      await future;
      expect(controller.loading, isFalse);
    });

    test('a failing repository sets error and leaves stats null', () async {
      final controller = AdminDashboardController(
        _FailingAdminDashboardRepository(),
        MockAdminAccessAttemptLogRepository(),
      );

      await controller.loadStats();

      expect(controller.stats, isNull);
      expect(controller.error, isNotNull);
      expect(controller.loading, isFalse);
    });

    test('retrying after a failure can succeed and clears the error',
        () async {
      final repository = _FlakyAdminDashboardRepository();
      final controller = AdminDashboardController(
        repository,
        MockAdminAccessAttemptLogRepository(),
      );

      await controller.loadStats();
      expect(controller.error, isNotNull);
      expect(controller.stats, isNull);

      repository.shouldFail = false;
      await controller.loadStats();

      expect(controller.error, isNull);
      expect(controller.stats, isNotNull);
    });
  });
}

class _FailingAdminDashboardRepository implements AdminDashboardRepository {
  @override
  Future<AdminDashboardStats> getDashboardStats() async {
    throw Exception('mock backend unreachable');
  }
}

class _FlakyAdminDashboardRepository implements AdminDashboardRepository {
  bool shouldFail = true;

  @override
  Future<AdminDashboardStats> getDashboardStats() async {
    if (shouldFail) throw Exception('mock backend unreachable');
    return const AdminDashboardStats(
      totalUsers: 1,
      activeUsers: 1,
      suspendedUsers: 0,
      deactivatedUsers: 0,
      adminUsers: 1,
      newUsersThisWeek: 0,
    );
  }
}
