import '../models/admin_dashboard_stats.dart';

/// Maps to PB-02 (View Admin Dashboard). Read-only aggregate over the user
/// directory; the real implementation (Phase 7) is an RLS-protected query
/// scoped to callers with `Profile.role == admin`.
abstract class AdminDashboardRepository {
  Future<AdminDashboardStats> getDashboardStats();
}