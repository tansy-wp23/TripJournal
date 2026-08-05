import '../models/profile.dart';

/// Shared in-memory user list backing [MockAdminUserDirectoryRepository],
/// [MockAdminDashboardRepository], and [MockAdminAccountActionsRepository].
///
/// A single shared store (rather than three independently-seeded mocks) is
/// what lets Phase 5's suspend/reactivate actions show up in Phase 3's
/// dashboard counts and Phase 4's search results during manual testing
/// (`ADMIN_MODULE_IMPLEMENTATION_PLAN.md` Phase 1, task 2). Distinct from
/// the User Management module's single-profile `MockProfileRepository` —
/// that one models "a traveler's view of themselves"; this one models "an
/// admin's view of many users."
class MockAdminUserStore {
  final List<Profile> profiles;

  MockAdminUserStore({List<Profile>? seed}) : profiles = seed ?? defaultSeed();

  static List<Profile> defaultSeed() {
    final now = DateTime.now();
    DateTime daysAgo(int days) => now.subtract(Duration(days: days));

    return [
      Profile(
        userID: 'admin-001',
        email: 'admin@tripjournal.dev',
        displayName: 'Admin Account',
        role: UserRole.admin,
        status: AccountStatus.active,
        createdAt: daysAgo(200),
        updatedAt: daysAgo(200),
      ),
      Profile(
        userID: 'user-101',
        email: 'alice.tan@example.com',
        displayName: 'Alice Tan',
        status: AccountStatus.active,
        createdAt: daysAgo(2),
        updatedAt: daysAgo(2),
      ),
      Profile(
        userID: 'user-102',
        email: 'brandon.lee@example.com',
        displayName: 'Brandon Lee',
        status: AccountStatus.active,
        createdAt: daysAgo(45),
        updatedAt: daysAgo(45),
      ),
      Profile(
        userID: 'user-103',
        email: 'mei.ling@example.com',
        displayName: 'Chong Mei Ling',
        status: AccountStatus.suspended,
        deactivatedAt: daysAgo(10),
        createdAt: daysAgo(120),
        updatedAt: daysAgo(10),
      ),
      Profile(
        userID: 'user-104',
        email: 'david.wong@example.com',
        displayName: 'David Wong',
        status: AccountStatus.deactivated,
        deactivatedAt: daysAgo(5),
        createdAt: daysAgo(90),
        updatedAt: daysAgo(5),
      ),
      Profile(
        userID: 'user-105',
        email: 'farah.aziz@example.com',
        displayName: 'Farah Aziz',
        status: AccountStatus.active,
        createdAt: daysAgo(1),
        updatedAt: daysAgo(1),
      ),
    ];
  }
}