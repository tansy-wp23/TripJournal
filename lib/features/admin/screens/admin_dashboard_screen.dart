import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/admin_access_attempt_log.dart';
import '../../journal/widgets/format_utils.dart';
import '../../trip/widgets/stat_tile.dart';
import '../admin_format_utils.dart';
import '../controller/admin_auth_controller.dart';
import '../controller/admin_dashboard_controller.dart';
import 'admin_user_list_screen.dart';

/// PB-02: View Admin Dashboard. Loads `AdminDashboardStats` on first build
/// and renders a stat-tile grid — reuses the `StatTile` widget pattern from
/// `lib/features/trip/widgets/stat_tile.dart` per the plan. Also shows the
/// most recent rejected admin sign-in attempts (`docs/admin/PROGRESS.md`
/// post-Phase-3 addition), so a non-admin trying the admin portal is
/// actually visible to an admin, not just recorded.
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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminUserListScreen()),
            ),
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
        GridView.count(
          key: const Key('admin-dashboard-stats-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            StatTile(
              icon: Icons.people,
              label: '${formatThousands(stats.totalUsers)} Total users',
            ),
            StatTile(
              icon: Icons.check_circle,
              label: '${formatThousands(stats.activeUsers)} Active',
            ),
            StatTile(
              icon: Icons.block,
              label: '${formatThousands(stats.suspendedUsers)} Suspended',
            ),
            StatTile(
              icon: Icons.person_off,
              label: '${formatThousands(stats.deactivatedUsers)} Deactivated',
            ),
            StatTile(
              icon: Icons.admin_panel_settings,
              label: '${formatThousands(stats.adminUsers)} Admins',
            ),
            StatTile(
              icon: Icons.fiber_new,
              label: '${formatThousands(stats.newUsersThisWeek)} New this week',
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'Recent unauthorized admin sign-in attempts',
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
          ...dashboard.recentAttempts.map(
            (attempt) => _AccessAttemptTile(attempt: attempt),
          ),
      ],
    );
  }
}

class _AccessAttemptTile extends StatelessWidget {
  const _AccessAttemptTile({required this.attempt});

  final AdminAccessAttemptLog attempt;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
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
