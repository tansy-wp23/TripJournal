import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/admin_audit_log.dart';
import '../../../widgets/app_content_toolbar.dart';
import '../../journal/widgets/format_utils.dart';
import '../admin_format_utils.dart';
import '../controller/audit_log_controller.dart';
import 'admin_user_detail_screen.dart';
import 'issue_report_detail_screen.dart';

/// PB-10 (Sprint 2 — Monitor Audit Log). **Global** view across every admin
/// and every target type, reached from `AdminDashboardScreen`'s app bar —
/// distinct from `AdminUserDetailScreen`'s and `IssueReportDetailScreen`'s
/// per-target "Status history" sections, which only ever show one target's
/// entries via `getHistoryForTarget`. This screen is the only caller of
/// `AdminAuditLogRepository.getAllEntries`.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({
    super.key,
    this.userDetailScreenBuilder,
    this.issueDetailScreenBuilder,
  });

  /// Test-only overrides for the screens pushed on tapping an entry — see
  /// `AdminDashboardScreen.userDetailScreenBuilder`'s doc comment for why
  /// these exist.
  final Widget Function(String userId)? userDetailScreenBuilder;
  final Widget Function(String reportId)? issueDetailScreenBuilder;

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
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
      await ref.read(auditLogControllerProvider.notifier).load();
    } finally {
      _loadInProgress = false;
    }
  }

  Future<void> _pickDateRange(
    BuildContext context,
    AuditLogController controller,
  ) async {
    final now = DateTime.now();
    final startDate = controller.startDate;
    final endDate = controller.endDate;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate, end: endDate)
          : null,
    );
    if (picked == null) return;

    // The picker returns midnight-to-midnight — extend the end to the last
    // moment of that day so entries recorded later on the end date aren't
    // excluded by `getAllEntries`'s `isAfter(endDate)` check.
    final inclusiveEnd = DateTime(
      picked.end.year,
      picked.end.month,
      picked.end.day,
      23,
      59,
      59,
    );
    await controller.setDateRange(start: picked.start, end: inclusiveEnd);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(auditLogControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log'), actions: const []),
      body: SafeArea(
        child: Column(
          children: [
            _FilterBar(
              onPickDateRange: () => _pickDateRange(context, controller),
            ),
            Expanded(child: _buildBody(context, controller)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AuditLogController controller) {
    if (controller.loading &&
        controller.entries.isEmpty &&
        controller.error == null) {
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
              key: const Key('admin-audit-log-retry'),
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (controller.entries.isEmpty) {
      final message = controller.hasActiveFilter
          ? 'No audit entries match these filters.'
          : 'No audit entries have been recorded yet.';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            key: const Key('admin-audit-log-empty-state'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      key: const Key('admin-audit-log-results'),
      itemCount: controller.entries.length,
      itemBuilder: (context, index) => _AuditLogEntryTile(
        entry: controller.entries[index],
        controller: controller,
        userDetailScreenBuilder: widget.userDetailScreenBuilder,
        issueDetailScreenBuilder: widget.issueDetailScreenBuilder,
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.onPickDateRange});

  final VoidCallback onPickDateRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(auditLogControllerProvider);
    final notifier = ref.read(auditLogControllerProvider.notifier);
    final actionChoices = actionsForTargetType(controller.targetTypeFilter);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AppContentToolbar(
        resultLabel: '${controller.entries.length} audit entries',
        activeFilterLabel: controller.hasActiveFilter ? 'Filters active' : null,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              key: const Key('admin-audit-target-type-filters'),
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All targets'),
                  selected: controller.targetTypeFilter == null,
                  onSelected: (_) => notifier.setTargetTypeFilter(null),
                ),
                for (final targetType in AdminAuditTargetType.values)
                  ChoiceChip(
                    key: Key('admin-audit-target-type-${targetType.name}'),
                    label: Text(adminAuditTargetTypeLabel(targetType)),
                    selected: controller.targetTypeFilter == targetType,
                    onSelected: (_) => notifier.setTargetTypeFilter(targetType),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<AdminAction?>(
              key: const Key('admin-audit-action-filter'),
              initialValue: controller.actionFilter,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Action',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All actions')),
                for (final action in actionChoices)
                  DropdownMenuItem(
                    value: action,
                    child: Text(adminActionLabel(action)),
                  ),
              ],
              onChanged: notifier.setActionFilter,
            ),
          ),
          OutlinedButton.icon(
            key: const Key('admin-audit-date-range-button'),
            onPressed: onPickDateRange,
            icon: const Icon(Icons.date_range),
            label: Text(_dateRangeLabel(controller)),
          ),
          if (controller.startDate != null || controller.endDate != null)
            TextButton.icon(
              key: const Key('admin-audit-date-range-clear'),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Clear date'),
              onPressed: () => notifier.setDateRange(start: null, end: null),
            ),
          if (controller.hasActiveFilter)
            OutlinedButton.icon(
              key: const Key('admin-audit-log-clear-filters'),
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: const Text('Clear filters'),
              onPressed: notifier.clearFilters,
            ),
        ],
      ),
    );
  }

  String _dateRangeLabel(AuditLogController controller) {
    final start = controller.startDate;
    final end = controller.endDate;
    if (start == null || end == null) return 'Any date';
    return '${formatDate(start)} – ${formatDate(end)}';
  }
}

class _AuditLogEntryTile extends StatelessWidget {
  const _AuditLogEntryTile({
    required this.entry,
    required this.controller,
    this.userDetailScreenBuilder,
    this.issueDetailScreenBuilder,
  });

  final AdminAuditLog entry;
  final AuditLogController controller;
  final Widget Function(String userId)? userDetailScreenBuilder;
  final Widget Function(String reportId)? issueDetailScreenBuilder;

  /// Every entry's target is reachable — `AdminUserDetailScreen` and
  /// `IssueReportDetailScreen` already exist (Phase 4/Phase 11) and already
  /// handle an unresolvable id with an error+retry state, so routing a
  /// possibly-stale historical entry into them needed no new handling on
  /// the destination side. This is the only place that switches on
  /// [AdminAuditTargetType] to pick which screen to open — everywhere else
  /// a screen already knows which target type it's showing.
  void _openTarget(BuildContext context) {
    switch (entry.targetType) {
      case AdminAuditTargetType.user:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => userDetailScreenBuilder != null
                ? userDetailScreenBuilder!(entry.targetId)
                : AdminUserDetailScreen(userId: entry.targetId),
          ),
        );
      case AdminAuditTargetType.issueReport:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => issueDetailScreenBuilder != null
                ? issueDetailScreenBuilder!(entry.targetId)
                : IssueReportDetailScreen(reportId: entry.targetId),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('admin-audit-entry-${entry.logId}'),
      leading: Icon(adminActionIcon(entry.action)),
      title: Text(adminActionLabel(entry.action)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${adminAuditTargetTypeLabel(entry.targetType)}: ${controller.targetLabel(entry)} '
            '· by ${controller.adminLabel(entry.adminUserId)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (entry.reason != null) Text(entry.reason!),
          Text(
            formatRelativeTime(entry.createdAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      isThreeLine: entry.reason != null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openTarget(context),
    );
  }
}
