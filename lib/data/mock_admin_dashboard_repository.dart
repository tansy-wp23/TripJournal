import '../models/admin_dashboard_stats.dart';
import '../models/profile.dart';
import 'admin_dashboard_repository.dart';
import 'mock_admin_user_store.dart';

/// In-memory fake of [AdminDashboardRepository], computing stats from the
/// same [MockAdminUserStore] that backs [MockAdminUserDirectoryRepository]
/// and [MockAdminAccountActionsRepository], so a suspend/reactivate action
/// is reflected in these counts on the next fetch.
class MockAdminDashboardRepository implements AdminDashboardRepository {
  final MockAdminUserStore store;

  MockAdminDashboardRepository(this.store);

  @override
  Future<AdminDashboardStats> getDashboardStats() async {
    final profiles = store.profiles;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));

    return AdminDashboardStats(
      totalUsers: profiles.length,
      activeUsers:
          profiles.where((p) => p.status == AccountStatus.active).length,
      suspendedUsers:
          profiles.where((p) => p.status == AccountStatus.suspended).length,
      deactivatedUsers:
          profiles.where((p) => p.status == AccountStatus.deactivated).length,
      adminUsers: profiles.where((p) => p.role == UserRole.admin).length,
      newUsersThisWeek:
          profiles.where((p) => p.createdAt.isAfter(weekAgo)).length,
    );
  }
}