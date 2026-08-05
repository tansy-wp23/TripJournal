import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_admin_dashboard_repository.dart';
import 'package:tripjournal/data/mock_admin_user_store.dart';
import 'package:tripjournal/models/profile.dart';

void main() {
  group('MockAdminDashboardRepository', () {
    test('getDashboardStats counts match the seeded store', () async {
      final store = MockAdminUserStore();
      final repository = MockAdminDashboardRepository(store);

      final stats = await repository.getDashboardStats();

      expect(stats.totalUsers, store.profiles.length);
      expect(stats.suspendedUsers, 1);
      expect(stats.deactivatedUsers, 1);
      expect(stats.adminUsers, 1);
      expect(
        stats.activeUsers,
        store.profiles.length -
            stats.suspendedUsers -
            stats.deactivatedUsers,
      );
    });

    test('getDashboardStats reflects a status change made directly on the '
        'shared store', () async {
      final store = MockAdminUserStore();
      final repository = MockAdminDashboardRepository(store);

      final before = await repository.getDashboardStats();

      final index = store.profiles.indexWhere((p) => p.userID == 'user-101');
      store.profiles[index] =
          store.profiles[index].copyWith(status: AccountStatus.suspended);

      final after = await repository.getDashboardStats();

      expect(after.suspendedUsers, before.suspendedUsers + 1);
      expect(after.activeUsers, before.activeUsers - 1);
      expect(after.totalUsers, before.totalUsers);
    });
  });
}