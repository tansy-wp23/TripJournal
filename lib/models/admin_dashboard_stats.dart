/// Summary statistics shown on the Admin Dashboard (PB-02).
///
/// Kept to fields a mock can trivially compute from an in-memory user list
/// (`ADMIN_MODULE_IMPLEMENTATION_PLAN.md` Phase 0, task 3). Cross-module
/// fields (e.g. trip/journal counts) were left out for Sprint 1 — add them
/// only once `TripRepository`/`JournalRepository` expose a cheap aggregate
/// read, per the plan's guidance.
class AdminDashboardStats {
  final int totalUsers;
  final int activeUsers;
  final int suspendedUsers;
  final int deactivatedUsers;
  final int adminUsers;
  final int newUsersThisWeek;

  const AdminDashboardStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.suspendedUsers,
    required this.deactivatedUsers,
    required this.adminUsers,
    required this.newUsersThisWeek,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      totalUsers: json['totalUsers'] as int,
      activeUsers: json['activeUsers'] as int,
      suspendedUsers: json['suspendedUsers'] as int,
      deactivatedUsers: json['deactivatedUsers'] as int,
      adminUsers: json['adminUsers'] as int,
      newUsersThisWeek: json['newUsersThisWeek'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalUsers': totalUsers,
      'activeUsers': activeUsers,
      'suspendedUsers': suspendedUsers,
      'deactivatedUsers': deactivatedUsers,
      'adminUsers': adminUsers,
      'newUsersThisWeek': newUsersThisWeek,
    };
  }
}