import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/issue_report.dart';
import '../../../widgets/app_content_toolbar.dart';
import '../admin_format_utils.dart';
import '../controller/issue_report_management_controller.dart';
import 'issue_report_detail_screen.dart';

/// PB-07: View System Issue Reports. Status-filterable list, reached from
/// `AdminDashboardScreen`'s app bar. Tapping a report opens
/// `IssueReportDetailScreen` (Phase 11).
class AdminIssueReportListScreen extends ConsumerStatefulWidget {
  const AdminIssueReportListScreen({super.key, this.detailScreenBuilder});

  /// Test-only override for the screen pushed on tapping a report — see
  /// `AdminDashboardScreen.userDetailScreenBuilder`'s doc comment for why
  /// this exists.
  final Widget Function(String reportId)? detailScreenBuilder;

  @override
  ConsumerState<AdminIssueReportListScreen> createState() =>
      _AdminIssueReportListScreenState();
}

class _AdminIssueReportListScreenState
    extends ConsumerState<AdminIssueReportListScreen> {
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
      await ref.read(issueReportManagementControllerProvider.notifier).load();
    } finally {
      _loadInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final management = ref.watch(issueReportManagementControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Issue Reports')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AppContentToolbar(
                resultLabel: '${management.reports.length} reports found',
                activeFilterLabel: management.statusFilter == null
                    ? null
                    : 'Status filter active',
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      key: const Key('admin-issue-status-filters'),
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusFilterChip(
                          label: 'All',
                          selected: management.statusFilter == null,
                          onSelected: () => ref
                              .read(
                                issueReportManagementControllerProvider
                                    .notifier,
                              )
                              .setStatusFilter(null),
                        ),
                        for (final status in IssueReportStatus.values)
                          _StatusFilterChip(
                            label: issueReportStatusLabel(status),
                            selected: management.statusFilter == status,
                            onSelected: () => ref
                                .read(
                                  issueReportManagementControllerProvider
                                      .notifier,
                                )
                                .setStatusFilter(status),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(context, management)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    IssueReportManagementController management,
  ) {
    if (management.loading &&
        management.reports.isEmpty &&
        management.error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (management.error != null) {
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
            Text(management.error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('admin-issue-list-retry'),
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (management.reports.isEmpty) {
      final message = management.statusFilter == null
          ? 'No issue reports have been submitted.'
          : 'No ${issueReportStatusLabel(management.statusFilter!).toLowerCase()} reports.';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            key: const Key('admin-issue-list-empty-state'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      key: const Key('admin-issue-list-results'),
      itemCount: management.reports.length,
      itemBuilder: (context, index) => _ReportTile(
        report: management.reports[index],
        detailScreenBuilder: widget.detailScreenBuilder,
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report, this.detailScreenBuilder});

  final IssueReport report;
  final Widget Function(String reportId)? detailScreenBuilder;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        _statusIcon(report.status),
        color: _statusColor(context, report.status),
      ),
      title: Text(
        report.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${report.page} · ${formatRelativeTime(report.createdAt)}',
      ),
      trailing: Chip(
        label: Text(issueReportStatusLabel(report.status)),
        visualDensity: VisualDensity.compact,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => detailScreenBuilder != null
              ? detailScreenBuilder!(report.reportId)
              : IssueReportDetailScreen(reportId: report.reportId),
        ),
      ),
    );
  }

  IconData _statusIcon(IssueReportStatus status) {
    switch (status) {
      case IssueReportStatus.open:
        return Icons.fiber_new;
      case IssueReportStatus.inProgress:
        return Icons.hourglass_top;
      case IssueReportStatus.resolved:
        return Icons.check_circle;
    }
  }

  Color _statusColor(BuildContext context, IssueReportStatus status) {
    final theme = Theme.of(context);
    switch (status) {
      case IssueReportStatus.open:
        return theme.colorScheme.error;
      case IssueReportStatus.inProgress:
        return theme.colorScheme.primary;
      case IssueReportStatus.resolved:
        return Colors.green;
    }
  }
}
