import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/admin_access_attempt_log.dart';
import '../../../models/profile.dart';
import '../../journal/widgets/format_utils.dart';
import '../admin_format_utils.dart';
import '../controller/admin_auth_controller.dart';
import '../controller/admin_dashboard_controller.dart';
import 'admin_user_list_screen.dart';

/// PB-02: View Admin Dashboard. Loads `AdminDashboardStats` on first build
/// and renders it as a grid of tappable cards, organized into "Overview"
/// (stats — each navigates to `AdminUserListScreen` pre-filtered to that
/// subset, per the redesign request 2026-08-12 — the plain `StatTile`s
/// this screen originally used were read-only, which didn't match "6
/// icons that should lead somewhere") and "Recent Activity" (rejected
/// admin sign-in attempts, `docs/admin/PROGRESS.md` post-Phase-3
/// addition), so a non-admin trying the admin portal is actually visible
/// to an admin, not just recorded.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _loadInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    try {
      await ref.read(adminDashboardControllerProvider.notifier).loadStats();
    } finally {
      _loadInProgress = false;
    }
  }

  void _openUserList(
    BuildContext context, {
    required String title,
    AccountStatus? status,
    UserRole? role,
    bool newThisWeek = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminUserListScreen(
          title: title,
          initialStatusFilter: status,
          initialRoleFilter: role,
          initialNewThisWeek: newThisWeek,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(adminAuthControllerProvider);
    final dashboard = ref.watch(adminDashboardControllerProvider);
    final profile = admin.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            key: const Key('admin-manage-users'),
            tooltip: 'Manage users',
            icon: const Icon(Icons.manage_accounts),
            onPressed: () => _openUserList(context, title: 'Manage Users'),
          ),
          IconButton(
            key: const Key('admin-logout'),
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(adminAuthControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (profile != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Signed in as ${profile.displayName} (${profile.email})',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              Expanded(child: _buildBody(context, dashboard)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AdminDashboardController dashboard) {
    if (dashboard.loading && dashboard.stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (dashboard.error != null && dashboard.stats == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              dashboard.error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('admin-dashboard-retry'),
              onPressed: _loadStats,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final stats = dashboard.stats;
    if (stats == null) {
      // Shouldn't normally be reached (loading/error above cover the gap
      // before the first successful load), but avoids a blank screen if it
      // ever is.
      return const SizedBox.shrink();
    }

    return ListView(
      children: [
        Text('Overview', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Tap a card to see that group of users.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        GridView.count(
          key: const Key('admin-dashboard-stats-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _DashboardStatCard(
              key: const Key('admin-stat-total-users'),
              icon: Icons.people,
              value: formatThousands(stats.totalUsers),
              label: 'Total users',
              onTap: () => _openUserList(context, title: 'Manage Users'),
            ),
            _DashboardStatCard(
              key: const Key('admin-stat-active'),
              icon: Icons.check_circle,
              value: formatThousands(stats.activeUsers),
              label: 'Active',
              onTap: () => _openUserList(
                context,
                title: 'Active Users',
                status: AccountStatus.active,
              ),
            ),
            _DashboardStatCard(
              key: const Key('admin-stat-suspended'),
              icon: Icons.block,
              value: formatThousands(stats.suspendedUsers),
              label: 'Suspended',
              onTap: () => _openUserList(
                context,
                title: 'Suspended Users',
                status: AccountStatus.suspended,
              ),
            ),
            _DashboardStatCard(
              key: const Key('admin-stat-deactivated'),
              icon: Icons.person_off,
              value: formatThousands(stats.deactivatedUsers),
              label: 'Deactivated',
              onTap: () => _openUserList(
                context,
                title: 'Deactivated Users',
                status: AccountStatus.deactivated,
              ),
            ),
            _DashboardStatCard(
              key: const Key('admin-stat-admins'),
              icon: Icons.admin_panel_settings,
              value: formatThousands(stats.adminUsers),
              label: 'Admins',
              onTap: () => _openUserList(
                context,
                title: 'Administrators',
                role: UserRole.admin,
              ),
            ),
            _DashboardStatCard(
              key: const Key('admin-stat-new-this-week'),
              icon: Icons.fiber_new,
              value: formatThousands(stats.newUsersThisWeek),
              label: 'New this week',
              onTap: () => _openUserList(
                context,
                title: 'New This Week',
                newThisWeek: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Non-admin accounts that tried to sign in through the admin '
          'portal. Recorded for review — no automatic action is taken.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (dashboard.recentAttempts.isEmpty)
          const Text('No attempts recorded.')
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final attempt in dashboard.recentAttempts)
                  _AccessAttemptTile(attempt: attempt),
              ],
            ),
          ),
      ],
    );
  }
}

/// A tappable dashboard stat — distinct from the shared, read-only
/// `StatTile` (`lib/features/trip/widgets/stat_tile.dart`, still used
/// as-is for genuinely non-interactive stats like the trip wellness row):
/// this one needs tap affordance (elevation, ripple, chevron) `StatTile`
/// was never designed for, so it's a separate widget rather than bending
/// `StatTile` to a second purpose. Mirrors the `Card` + `InkWell` pattern
/// `HomeScreen`'s trip cards already use.
class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 28, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      label,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessAttemptTile extends StatelessWidget {
  const _AccessAttemptTile({required this.attempt});

  final AdminAccessAttemptLog attempt;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.warning_amber,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(attempt.attemptedEmail),
      subtitle: Text(
        '${accessAttemptReasonLabel(attempt.reason)} · ${formatRelativeTime(attempt.createdAt)}',
      ),
    );
  }
}
