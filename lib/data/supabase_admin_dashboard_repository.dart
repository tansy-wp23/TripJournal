import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_dashboard_stats.dart';
import 'admin_dashboard_repository.dart';

/// Real [AdminDashboardRepository] (Phase 7 of
/// ADMIN_MODULE_IMPLEMENTATION_PLAN.md) — an RLS-protected read scoped to
/// `is_admin_user()` callers via `profiles_select_admin`
/// (202608190001_admin_rbac_and_audit_logs.sql), computing the same aggregates
/// [MockAdminDashboardRepository] does client-side over the seeded list.
/// Fetches only the three columns the counts need rather than a full
/// `Profile` row per user, and computes on the client rather than via a
/// Postgres aggregate query — kept simple per the plan's "keep to fields a
/// mock can trivially compute" guidance (Phase 0, task 3); revisit with a
/// server-side aggregate/RPC if the user table grows large enough for this
/// to matter.
class SupabaseAdminDashboardRepository implements AdminDashboardRepository {
  SupabaseAdminDashboardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AdminDashboardStats> getDashboardStats() async {
    final rows = await _client.from('profiles').select('role, status, created_at');
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));

    var activeUsers = 0;
    var suspendedUsers = 0;
    var deactivatedUsers = 0;
    var adminUsers = 0;
    var newUsersThisWeek = 0;

    for (final row in rows) {
      switch (row['status'] as String) {
        case 'active':
          activeUsers++;
        case 'suspended':
          suspendedUsers++;
        case 'deactivated':
          deactivatedUsers++;
      }
      if (row['role'] as String == 'admin') adminUsers++;
      if (DateTime.parse(row['created_at'] as String).isAfter(weekAgo)) {
        newUsersThisWeek++;
      }
    }

    return AdminDashboardStats(
      totalUsers: rows.length,
      activeUsers: activeUsers,
      suspendedUsers: suspendedUsers,
      deactivatedUsers: deactivatedUsers,
      adminUsers: adminUsers,
      newUsersThisWeek: newUsersThisWeek,
    );
  }
}
