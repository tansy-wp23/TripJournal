import '../models/profile.dart';
import 'admin_user_directory_repository.dart';
import 'mock_admin_user_store.dart';

/// In-memory fake of [AdminUserDirectoryRepository] so UI work in Phases
/// 2–6 never blocks on a backend. Reads from a [MockAdminUserStore] shared
/// with [MockAdminDashboardRepository] and
/// [MockAdminAccountActionsRepository].
class MockAdminUserDirectoryRepository implements AdminUserDirectoryRepository {
  final MockAdminUserStore store;

  MockAdminUserDirectoryRepository(this.store);

  @override
  Future<List<Profile>> searchUsers({String? query}) async {
    if (query == null || query.trim().isEmpty) {
      return List.unmodifiable(store.profiles);
    }
    final needle = query.trim().toLowerCase();
    return store.profiles
        .where(
          (p) =>
              p.displayName.toLowerCase().contains(needle) ||
              p.email.toLowerCase().contains(needle),
        )
        .toList();
  }

  @override
  Future<Profile?> getUserById(String userId) async {
    for (final profile in store.profiles) {
      if (profile.userID == userId) return profile;
    }
    return null;
  }
}