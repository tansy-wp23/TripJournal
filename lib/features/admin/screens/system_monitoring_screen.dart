import 'package:flutter/material.dart';

import '../../../widgets/app_navigation_tile.dart';
import 'ai_request_monitoring_screen.dart';
import 'monitoring_report_screen.dart';
import 'system_error_log_screen.dart';
import 'system_health_screen.dart';

/// Sprint 3's monitoring hub — reached from `AdminDashboardScreen`'s app
/// bar via a single "Monitoring" action.
///
/// **Redesign, added alongside Phase 19** (not itself a numbered phase in
/// `ADMIN_MODULE_IMPLEMENTATION_PLAN.md`): Phases 17 and 18 each added
/// their own individual app bar icon to `AdminDashboardScreen`
/// (`admin-system-errors`, `admin-ai-requests`), following the precedent
/// Sprint 1/2 phases set (one icon per new screen). Adding Phase 19's
/// `SystemHealthScreen` as a fourth icon there — with Phase 20's
/// `MonitoringReportScreen` still to come as a likely fifth — would have
/// pushed the app bar past what "clean, organized" (the team's explicit
/// design bar for this batch of screens) can reasonably hold. This screen
/// replaces those two individual icons with one, and is where Phase 20's
/// report screen gets its own tappable card too.
class SystemMonitoringScreen extends StatelessWidget {
  const SystemMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitoring')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'System operations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Review service health, errors, AI activity, and reports.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            AppNavigationTile(
              key: const Key('admin-monitoring-system-errors'),
              icon: Icons.bug_report_outlined,
              title: 'System Error Log',
              subtitle: 'Errors caught anywhere in the app (PB-11)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SystemErrorLogScreen()),
              ),
            ),
            const SizedBox(height: 12),
            AppNavigationTile(
              key: const Key('admin-monitoring-ai-requests'),
              icon: Icons.smart_toy_outlined,
              title: 'AI Request Monitoring',
              subtitle:
                  'AI call status, timing, and failed-request retries (PB-12, PB-13)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AiRequestMonitoringScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppNavigationTile(
              key: const Key('admin-monitoring-system-health'),
              icon: Icons.health_and_safety_outlined,
              title: 'System Health',
              subtitle: 'AI key configuration and backend availability (PB-14)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SystemHealthScreen()),
              ),
            ),
            const SizedBox(height: 12),
            AppNavigationTile(
              key: const Key('admin-monitoring-report'),
              icon: Icons.summarize_outlined,
              title: 'Monitoring Report',
              subtitle: 'Date-ranged summary with PDF/CSV export (PB-15)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MonitoringReportScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
