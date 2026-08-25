import 'package:flutter/material.dart';

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
            _MonitoringCard(
              key: const Key('admin-monitoring-system-errors'),
              icon: Icons.bug_report_outlined,
              title: 'System Error Log',
              subtitle: 'Errors caught anywhere in the app (PB-11)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SystemErrorLogScreen()),
              ),
            ),
            _MonitoringCard(
              key: const Key('admin-monitoring-ai-requests'),
              icon: Icons.smart_toy_outlined,
              title: 'AI Request Monitoring',
              subtitle: 'AI call status, timing, and failed-request retries (PB-12, PB-13)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiRequestMonitoringScreen()),
              ),
            ),
            _MonitoringCard(
              key: const Key('admin-monitoring-system-health'),
              icon: Icons.health_and_safety_outlined,
              title: 'System Health',
              subtitle: 'AI key configuration and backend availability (PB-14)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SystemHealthScreen()),
              ),
            ),
            _MonitoringCard(
              key: const Key('admin-monitoring-report'),
              icon: Icons.summarize_outlined,
              title: 'Monitoring Report',
              subtitle: 'Date-ranged summary with PDF/CSV export (PB-15)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MonitoringReportScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitoringCard extends StatelessWidget {
  const _MonitoringCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 28, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
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
