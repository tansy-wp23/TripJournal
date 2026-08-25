import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/ai_request_log.dart';
import '../../../models/issue_report.dart';
import '../../../models/system_error_log.dart';
import '../../journal/widgets/format_utils.dart' show formatDate;
import '../admin_format_utils.dart';
import '../controller/monitoring_report_controller.dart';
import '../monitoring_report.dart';
import '../monitoring_report_csv.dart';
import '../pdf/monitoring_report_pdf.dart';

/// PB-15 (Generate System Monitoring Reports, Phase 20). Reached from
/// `SystemMonitoringScreen`'s fourth card. A date range picker (mirrors
/// `AuditLogScreen`'s) above a summary of Phases 17–19's error/AI-request
/// data and Sprint 2's issue-report data, each drawn as its own card
/// (label + count rows + total) rather than a plain text dump, plus PDF
/// and CSV export actions.
class MonitoringReportScreen extends ConsumerStatefulWidget {
  const MonitoringReportScreen({super.key});

  @override
  ConsumerState<MonitoringReportScreen> createState() => _MonitoringReportScreenState();
}

class _MonitoringReportScreenState extends ConsumerState<MonitoringReportScreen> {
  bool _loadInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  Future<void> _generate() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    try {
      await ref.read(monitoringReportControllerProvider.notifier).generate();
    } finally {
      _loadInProgress = false;
    }
  }

  Future<void> _pickDateRange(MonitoringReportController controller) async {
    final now = DateTime.now();
    final startDate = controller.startDate;
    final endDate = controller.endDate;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange:
          startDate != null && endDate != null ? DateTimeRange(start: startDate, end: endDate) : null,
    );
    if (picked == null) return;

    // The picker returns midnight-to-midnight — extend the end to the last
    // moment of that day so entries recorded later on the end date aren't
    // excluded, same reasoning as AuditLogScreen's own date-range handling.
    final inclusiveEnd = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
    await ref
        .read(monitoringReportControllerProvider.notifier)
        .setDateRange(start: picked.start, end: inclusiveEnd);
  }

  Future<void> _exportPdf(MonitoringReport report) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final bytes = await buildMonitoringReportPdf(report);
      if (mounted) Navigator.pop(context); // close the loading dialog
      await Printing.sharePdf(
        bytes: bytes,
        filename: monitoringReportFileNameFor(report, 'pdf'),
      );
    } catch (_) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export the report as a PDF.')),
        );
      }
    }
  }

  Future<void> _exportCsv(MonitoringReport report) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final csv = buildMonitoringReportCsv(report);
      final filename = monitoringReportFileNameFor(report, 'csv');
      if (mounted) Navigator.pop(context); // close the loading dialog
      // share_plus's XFile.fromData `name` is ignored on every platform
      // except web (per its own doc comment) — fileNameOverrides is what
      // actually names the shared file elsewhere.
      await Share.shareXFiles(
        [XFile.fromData(utf8.encode(csv), name: filename, mimeType: 'text/csv')],
        fileNameOverrides: [filename],
      );
    } catch (_) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export the report as a CSV file.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(monitoringReportControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Monitoring Report')),
      body: SafeArea(
        child: Column(
          children: [
            _DateRangeBar(
              controller: controller,
              onPickDateRange: () => _pickDateRange(controller),
            ),
            Expanded(child: _buildBody(context, controller)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, MonitoringReportController controller) {
    if (controller.loading && controller.report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null && controller.report == null) {
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
              key: const Key('admin-monitoring-report-retry'),
              onPressed: _generate,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final report = controller.report;
    if (report == null) return const SizedBox.shrink();

    return ListView(
      key: const Key('admin-monitoring-report-body'),
      padding: const EdgeInsets.all(16),
      children: [
        _ReportSection(
          key: const Key('admin-monitoring-report-errors'),
          title: 'Errors by Severity',
          total: report.totalErrors,
          rows: [
            for (final severity in ErrorSeverity.values)
              (errorSeverityLabel(severity), report.errorCountsBySeverity[severity] ?? 0),
          ],
        ),
        const SizedBox(height: 12),
        _ReportSection(
          key: const Key('admin-monitoring-report-ai-requests'),
          title: 'AI Requests by Status',
          total: report.totalAiRequests,
          rows: [
            for (final status in AiRequestStatus.values)
              (aiRequestStatusLabel(status), report.aiRequestCountsByStatus[status] ?? 0),
          ],
        ),
        const SizedBox(height: 12),
        _ReportSection(
          key: const Key('admin-monitoring-report-issues'),
          title: 'Issue Reports by Status',
          total: report.totalIssues,
          rows: [
            for (final status in IssueReportStatus.values)
              (issueReportStatusLabel(status), report.issueCountsByStatus[status] ?? 0),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('admin-monitoring-report-export-pdf'),
                onPressed: () => _exportPdf(report),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('admin-monitoring-report-export-csv'),
                onPressed: () => _exportCsv(report),
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Export CSV'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DateRangeBar extends StatelessWidget {
  const _DateRangeBar({required this.controller, required this.onPickDateRange});

  final MonitoringReportController controller;
  final VoidCallback onPickDateRange;

  @override
  Widget build(BuildContext context) {
    final start = controller.startDate;
    final end = controller.endDate;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            key: const Key('admin-monitoring-report-date-range-button'),
            onPressed: onPickDateRange,
            icon: const Icon(Icons.date_range),
            label: Text(
              start != null && end != null ? '${formatDate(start)} – ${formatDate(end)}' : 'All time',
            ),
          ),
          if (start != null || end != null)
            IconButton(
              key: const Key('admin-monitoring-report-date-range-clear'),
              tooltip: 'Clear date range',
              icon: const Icon(Icons.close),
              onPressed: () => controller.setDateRange(start: null, end: null),
            ),
        ],
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    super.key,
    required this.title,
    required this.rows,
    required this.total,
  });

  final String title;
  final List<(String, int)> rows;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final (label, count) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(label), Text('$count')],
                ),
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text('$total', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
