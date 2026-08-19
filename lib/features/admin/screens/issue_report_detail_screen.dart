import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/admin_repository_locator.dart';
import '../../../data/issue_report_repository.dart';
import '../../../models/admin_audit_log.dart';
import '../../../models/issue_report.dart';
import '../../../models/profile.dart';
import '../../journal/widgets/format_utils.dart';
import '../../journal/widgets/photo_thumbnail.dart';
import '../admin_format_utils.dart';
import '../controller/admin_auth_controller.dart';
import '../controller/issue_report_detail_controller.dart';
import '../widgets/leaving_resolved_remark_dialog.dart';

/// PB-08 (View Issue Details) + PB-09 (Update Issue Status). Reached from
/// `AdminIssueReportListScreen`'s tap-through, closing the `TODO` Phase 10
/// left on `_ReportTile`.
///
/// A `ConsumerStatefulWidget` (not a plain `StatefulWidget`) — needs
/// `ref.read(adminAuthControllerProvider)` to know which admin is acting,
/// for `IssueReportRepository.updateStatus`'s `adminUserId` param, exactly
/// like `AdminUserDetailScreen` needs it for suspend/reactivate.
/// `IssueReportDetailController` is still constructed locally per-instance
/// rather than resolved from a global Riverpod provider; see that
/// controller's doc comment for why.
///
/// [controller] / [issueReportRepositoryOverride] mirror
/// `AdminUserDetailScreen`'s test-injection pattern — optional, defaulting
/// to the real global instances (Phase 7/14,
/// `ADMIN_MODULE_IMPLEMENTATION_PLAN.md`).
class IssueReportDetailScreen extends ConsumerStatefulWidget {
  const IssueReportDetailScreen({
    super.key,
    required this.reportId,
    this.controller,
    this.issueReportRepositoryOverride,
  });

  final String reportId;
  final IssueReportDetailController? controller;
  final IssueReportRepository? issueReportRepositoryOverride;

  @override
  ConsumerState<IssueReportDetailScreen> createState() => _IssueReportDetailScreenState();
}

class _IssueReportDetailScreenState extends ConsumerState<IssueReportDetailScreen> {
  late final IssueReportRepository _issueReportRepository =
      widget.issueReportRepositoryOverride ?? issueReportRepository;
  late final IssueReportDetailController _controller =
      widget.controller ??
      IssueReportDetailController(
        _issueReportRepository,
        adminUserDirectoryRepository,
        adminAuditLogRepository,
      );

  final TextEditingController _remarksController = TextEditingController();
  bool _remarksInitialized = false;
  bool _updatingStatus = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _controller.load(widget.reportId);
  }

  void _onControllerChanged() {
    // Only seed the remarks field the first time a report loads — an
    // update triggered by this screen's own status-change action already
    // saved whatever's currently typed there, so overwriting it again
    // after that reload would just echo back the same text.
    if (!_remarksInitialized && _controller.report != null) {
      _remarksController.text = _controller.report!.adminRemarks ?? '';
      _remarksInitialized = true;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _remarksController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// PB-09. Defense-in-depth mirrors Phase 5's suspend/reactivate: the
  /// button for the report's *current* status is disabled in the UI
  /// (`_StatusControl`), and this repeats the check in case that ever goes
  /// stale, rejecting with a message rather than silently no-op'ing or
  /// recording a redundant audit entry.
  Future<void> _updateStatus(IssueReportStatus status) async {
    final admin = ref.read(adminAuthControllerProvider).profile;
    if (admin == null) return; // shouldn't happen — screen requires an authenticated admin

    final report = _controller.report;
    if (report == null) return;

    if (report.status == status) {
      _showMessage('This report is already ${issueReportStatusLabel(status).toLowerCase()}.');
      return;
    }

    var remarks = _remarksController.text.trim();

    // Leaving Resolved (down to In Progress or back to Open) is an "undo" of
    // a completed decision, not the routine forward flow — require and
    // confirm a remark before proceeding, same accountability bar Sprint 1
    // set for suspend. Every other transition keeps the optional remarks
    // field as-is (Sprint 2 Open Decision 6).
    if (report.status == IssueReportStatus.resolved) {
      final confirmedRemark = await showLeavingResolvedRemarkDialog(
        context,
        targetStatusLabel: issueReportStatusLabel(status),
        initialRemarks: remarks,
      );
      if (confirmedRemark == null) return; // cancelled — no side effects
      remarks = confirmedRemark;
      _remarksController.text = confirmedRemark;
    }

    setState(() => _updatingStatus = true);
    try {
      await _issueReportRepository.updateStatus(
        adminUserId: admin.userID,
        reportId: report.reportId,
        status: status,
        remarks: remarks.isEmpty ? null : remarks,
      );
      await _controller.load(widget.reportId);
      _showMessage('Marked as ${issueReportStatusLabel(status)}.');
    } catch (e) {
      _showMessage('Could not update this report: $e');
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Issue Report')),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.loading && _controller.report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.error != null && _controller.report == null) {
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
              _controller.error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('admin-issue-detail-retry'),
              onPressed: () => _controller.load(widget.reportId),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final report = _controller.report;
    if (report == null) return const SizedBox.shrink();

    return ListView(
      key: const Key('admin-issue-detail-content'),
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(label: Text(issueReportStatusLabel(report.status))),
            Text(report.page, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 12),
        Text(report.description, style: Theme.of(context).textTheme.bodyLarge),
        if (report.screenshotUrl != null) ...[
          const SizedBox(height: 16),
          PhotoThumbnail(photoPath: report.screenshotUrl!, size: 160),
        ],
        const SizedBox(height: 16),
        _SubmitterTile(submitter: _controller.submitter, report: report),
        Text(
          'Submitted ${formatDate(report.createdAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        Text('Update status', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          key: const Key('admin-issue-remarks-field'),
          controller: _remarksController,
          enabled: !_updatingStatus,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Admin remarks (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        _StatusControl(
          currentStatus: report.status,
          enabled: !_updatingStatus,
          onSelect: _updateStatus,
        ),
        const SizedBox(height: 24),
        Text('Status history', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_controller.statusHistory.isEmpty)
          const Text('No status changes recorded.')
        else
          ..._controller.statusHistory.map((entry) => _AuditLogTile(entry: entry)),
      ],
    );
  }
}

/// Three explicit target-status actions rather than a single "Resolve"
/// button — an admin needs to walk a report backward too (e.g. reopen one
/// mistakenly marked resolved), and `AdminAction` already models all three
/// transitions (`issueMarkInProgress`/`issueMarkResolved`/`issueReopen`),
/// not just a forward-only "resolve". The button matching the report's
/// current status is disabled rather than hidden, so all three options
/// stay visible as a reminder of what's possible next.
class _StatusControl extends StatelessWidget {
  const _StatusControl({
    required this.currentStatus,
    required this.enabled,
    required this.onSelect,
  });

  final IssueReportStatus currentStatus;
  final bool enabled;
  final ValueChanged<IssueReportStatus> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in IssueReportStatus.values)
          if (status == currentStatus)
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.check),
              label: Text(issueReportStatusLabel(status)),
            )
          else
            OutlinedButton(
              key: Key('admin-issue-set-status-${status.name}'),
              onPressed: enabled ? () => onSelect(status) : null,
              child: Text(issueReportStatusLabel(status)),
            ),
      ],
    );
  }
}

class _SubmitterTile extends StatelessWidget {
  const _SubmitterTile({required this.submitter, required this.report});

  final Profile? submitter;
  final IssueReport report;

  @override
  Widget build(BuildContext context) {
    final submitter = this.submitter;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        submitter == null
            ? 'Submitted by an unknown user (id: ${report.submittedByUserId}).'
            : 'Submitted by ${submitter.displayName} (${submitter.email})',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile({required this.entry});

  final AdminAuditLog entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(adminActionIcon(entry.action)),
      title: Text(adminActionLabel(entry.action)),
      subtitle: Text(
        entry.reason == null
            ? formatRelativeTime(entry.createdAt)
            : '${entry.reason} · ${formatRelativeTime(entry.createdAt)}',
      ),
    );
  }
}
