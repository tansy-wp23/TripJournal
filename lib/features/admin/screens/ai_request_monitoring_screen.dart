import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/ai_request_log.dart';
import '../admin_format_utils.dart';
import '../controller/ai_request_monitoring_controller.dart';
import 'failed_ai_requests_screen.dart';

/// PB-12 (Monitor AI Processing Requests, Phase 18). Reached from
/// `AdminDashboardScreen`'s app bar, mirrors `SystemErrorLogScreen`'s
/// layout: a status filter bar above a `ListView` of card-style tiles
/// (type, status icon/chip, execution time, relative time) rather than a
/// plain text dump. View-only — an app bar action links out to
/// `FailedAiRequestsScreen` for PB-13's retry workflow, rather than adding
/// retry buttons to every row here (see that controller's doc comment for
/// why the two stay separate screens).
class AiRequestMonitoringScreen extends ConsumerStatefulWidget {
  const AiRequestMonitoringScreen({super.key});

  @override
  ConsumerState<AiRequestMonitoringScreen> createState() => _AiRequestMonitoringScreenState();
}

class _AiRequestMonitoringScreenState extends ConsumerState<AiRequestMonitoringScreen> {
  bool _loadInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    try {
      await ref.read(aiRequestMonitoringControllerProvider.notifier).load();
    } finally {
      _loadInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(aiRequestMonitoringControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Request Monitoring'),
        actions: [
          IconButton(
            key: const Key('admin-ai-requests-failed'),
            tooltip: 'Failed requests',
            icon: const Icon(Icons.error_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FailedAiRequestsScreen()),
            ),
          ),
          if (controller.hasActiveFilter)
            IconButton(
              key: const Key('admin-ai-requests-clear-filters'),
              tooltip: 'Clear filters',
              icon: const Icon(Icons.filter_alt_off),
              onPressed: () => ref.read(aiRequestMonitoringControllerProvider.notifier).clearFilters(),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _StatusFilterBar(),
            Expanded(child: _buildBody(context, controller)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AiRequestMonitoringController controller) {
    if (controller.loading && controller.entries.isEmpty && controller.error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null) {
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
            Text(controller.error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('admin-ai-requests-retry-load'),
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (controller.entries.isEmpty) {
      final message = controller.hasActiveFilter
          ? 'No requests match this filter.'
          : 'No AI requests have been recorded.';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            key: const Key('admin-ai-requests-empty-state'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      key: const Key('admin-ai-requests-results'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: controller.entries.length,
      itemBuilder: (context, index) => _AiRequestTile(entry: controller.entries[index]),
    );
  }
}

class _StatusFilterBar extends ConsumerWidget {
  const _StatusFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(aiRequestMonitoringControllerProvider);
    final notifier = ref.read(aiRequestMonitoringControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        key: const Key('admin-ai-requests-status-filters'),
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('All statuses'),
            selected: controller.statusFilter == null,
            onSelected: (_) => notifier.setStatusFilter(null),
          ),
          for (final status in AiRequestStatus.values)
            ChoiceChip(
              key: Key('admin-ai-requests-status-${status.name}'),
              avatar: Icon(_statusIcon(status), size: 18),
              label: Text(aiRequestStatusLabel(status)),
              selected: controller.statusFilter == status,
              onSelected: (_) => notifier.setStatusFilter(status),
            ),
        ],
      ),
    );
  }
}

class _AiRequestTile extends StatelessWidget {
  const _AiRequestTile({required this.entry});

  final AiRequestLog entry;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context, entry.status);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: Key('admin-ai-request-${entry.logId}'),
        leading: Icon(_statusIcon(entry.status), color: statusColor),
        title: Text(aiRequestTypeLabel(entry.requestType)),
        subtitle: Text(
          '${aiRequestStatusLabel(entry.status)} · ${entry.executionTimeMs}ms · '
          '${formatRelativeTime(entry.createdAt)}',
        ),
        trailing: entry.status == AiRequestStatus.failed
            ? Icon(Icons.warning_amber, color: statusColor)
            : null,
      ),
    );
  }
}

IconData _statusIcon(AiRequestStatus status) {
  switch (status) {
    case AiRequestStatus.succeeded:
      return Icons.check_circle_outline;
    case AiRequestStatus.failed:
      return Icons.error_outline;
  }
}

Color _statusColor(BuildContext context, AiRequestStatus status) {
  final theme = Theme.of(context);
  switch (status) {
    case AiRequestStatus.succeeded:
      return Colors.green;
    case AiRequestStatus.failed:
      return theme.colorScheme.error;
  }
}
