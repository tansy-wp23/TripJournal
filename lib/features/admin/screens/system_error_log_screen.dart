import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/system_error_log.dart';
import '../admin_format_utils.dart';
import '../controller/system_error_log_controller.dart';

/// PB-11 (Monitor System Error Logs, Phase 17). Reached from
/// `AdminDashboardScreen`'s app bar, mirrors `AuditLogScreen`'s layout: a
/// filter bar above a `ListView` of entries, each rendered as a card-like
/// tile (severity icon/color, module, relative time, message) rather than a
/// plain line of text — tapping one with a stack trace opens it in a
/// dialog, since a stack trace is too long to usefully inline in the list.
class SystemErrorLogScreen extends ConsumerStatefulWidget {
  const SystemErrorLogScreen({super.key});

  @override
  ConsumerState<SystemErrorLogScreen> createState() => _SystemErrorLogScreenState();
}

class _SystemErrorLogScreenState extends ConsumerState<SystemErrorLogScreen> {
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
      await ref.read(systemErrorLogControllerProvider.notifier).load();
    } finally {
      _loadInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(systemErrorLogControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Error Log'),
        actions: [
          if (controller.hasActiveFilter)
            IconButton(
              key: const Key('admin-system-error-clear-filters'),
              tooltip: 'Clear filters',
              icon: const Icon(Icons.filter_alt_off),
              onPressed: () => ref.read(systemErrorLogControllerProvider.notifier).clearFilters(),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _FilterBar(availableModules: controller.availableModules),
            Expanded(child: _buildBody(context, controller)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SystemErrorLogController controller) {
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
              key: const Key('admin-system-error-retry'),
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (controller.entries.isEmpty) {
      final message = controller.hasActiveFilter
          ? 'No errors match these filters.'
          : 'No errors have been recorded.';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            key: const Key('admin-system-error-empty-state'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      key: const Key('admin-system-error-results'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: controller.entries.length,
      itemBuilder: (context, index) => _SystemErrorLogTile(entry: controller.entries[index]),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.availableModules});

  final List<String> availableModules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(systemErrorLogControllerProvider);
    final notifier = ref.read(systemErrorLogControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            key: const Key('admin-system-error-severity-filters'),
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All severities'),
                selected: controller.severityFilter == null,
                onSelected: (_) => notifier.setSeverityFilter(null),
              ),
              for (final severity in ErrorSeverity.values)
                ChoiceChip(
                  key: Key('admin-system-error-severity-${severity.name}'),
                  avatar: Icon(_severityIcon(severity), size: 18),
                  label: Text(errorSeverityLabel(severity)),
                  selected: controller.severityFilter == severity,
                  onSelected: (_) => notifier.setSeverityFilter(severity),
                ),
            ],
          ),
          if (availableModules.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String?>(
                key: const Key('admin-system-error-module-filter'),
                initialValue: controller.moduleFilter,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Module',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All modules')),
                  for (final module in availableModules)
                    DropdownMenuItem(value: module, child: Text(module)),
                ],
                onChanged: notifier.setModuleFilter,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SystemErrorLogTile extends StatelessWidget {
  const _SystemErrorLogTile({required this.entry});

  final SystemErrorLog entry;

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_severityIcon(entry.severity), color: _severityColor(context, entry.severity)),
            const SizedBox(width: 8),
            Text(errorSeverityLabel(entry.severity)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(entry.message),
              if (entry.stackTrace != null) ...[
                const SizedBox(height: 12),
                Text('Stack trace', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                SelectableText(
                  entry.stackTrace!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: Key('admin-system-error-${entry.logId}'),
        leading: Icon(_severityIcon(entry.severity), color: _severityColor(context, entry.severity)),
        title: Text(entry.message, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${entry.module} · ${formatRelativeTime(entry.createdAt)}'),
        trailing: entry.stackTrace != null ? const Icon(Icons.chevron_right) : null,
        onTap: entry.stackTrace != null ? () => _showDetail(context) : null,
      ),
    );
  }
}

IconData _severityIcon(ErrorSeverity severity) {
  switch (severity) {
    case ErrorSeverity.info:
      return Icons.info_outline;
    case ErrorSeverity.warning:
      return Icons.warning_amber;
    case ErrorSeverity.error:
      return Icons.error_outline;
    case ErrorSeverity.fatal:
      return Icons.dangerous;
  }
}

Color _severityColor(BuildContext context, ErrorSeverity severity) {
  final theme = Theme.of(context);
  switch (severity) {
    case ErrorSeverity.info:
      return theme.colorScheme.primary;
    case ErrorSeverity.warning:
      return Colors.amber.shade800;
    case ErrorSeverity.error:
      return theme.colorScheme.error;
    case ErrorSeverity.fatal:
      return theme.colorScheme.error;
  }
}
