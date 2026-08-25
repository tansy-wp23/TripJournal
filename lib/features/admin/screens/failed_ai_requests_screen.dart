import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/ai_request_log.dart';
import '../admin_format_utils.dart';
import '../controller/failed_ai_requests_controller.dart';

/// PB-13 (Monitor Failed AI Requests, Phase 18). Reached from
/// `AiRequestMonitoringScreen`'s app bar. Dedicated view of only
/// [AiRequestStatus.failed] entries, each with its error message and a
/// per-row Retry action — see `FailedAiRequestsController`'s and
/// `ai_request_retry.dart`'s doc comments for what "retry" does and
/// doesn't reproduce (a fixed representative payload, not the original
/// request's real data — this screen surfaces that via the SnackBar
/// confirmation after a retry, not just by omission).
class FailedAiRequestsScreen extends ConsumerStatefulWidget {
  const FailedAiRequestsScreen({super.key});

  @override
  ConsumerState<FailedAiRequestsScreen> createState() => _FailedAiRequestsScreenState();
}

class _FailedAiRequestsScreenState extends ConsumerState<FailedAiRequestsScreen> {
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
      await ref.read(failedAiRequestsControllerProvider.notifier).load();
    } finally {
      _loadInProgress = false;
    }
  }

  Future<void> _retry(AiRequestLog entry) async {
    await ref.read(failedAiRequestsControllerProvider.notifier).retry(entry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Retried ${aiRequestTypeLabel(entry.requestType)} with a representative test '
          'request — check the log above for the outcome.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(failedAiRequestsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Failed AI Requests')),
      body: SafeArea(child: _buildBody(context, controller)),
    );
  }

  Widget _buildBody(BuildContext context, FailedAiRequestsController controller) {
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
              key: const Key('admin-failed-ai-requests-retry-load'),
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (controller.entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No failed AI requests recorded.',
            key: const Key('admin-failed-ai-requests-empty-state'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      key: const Key('admin-failed-ai-requests-results'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: controller.entries.length,
      itemBuilder: (context, index) {
        final entry = controller.entries[index];
        return _FailedAiRequestTile(
          entry: entry,
          retrying: controller.isRetrying(entry.logId),
          onRetry: () => _retry(entry),
        );
      },
    );
  }
}

class _FailedAiRequestTile extends StatelessWidget {
  const _FailedAiRequestTile({
    required this.entry,
    required this.retrying,
    required this.onRetry,
  });

  final AiRequestLog entry;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    aiRequestTypeLabel(entry.requestType),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  formatRelativeTime(entry.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (entry.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(entry.errorMessage!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: retrying
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : OutlinedButton.icon(
                      key: Key('admin-ai-request-retry-${entry.logId}'),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
