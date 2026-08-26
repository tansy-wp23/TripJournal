import '../../models/ai_request_log.dart';
import '../../models/issue_report.dart';
import '../../models/system_error_log.dart';
import 'admin_format_utils.dart';
import 'monitoring_report.dart';
import 'pdf/monitoring_report_pdf.dart' show monitoringReportRangeLabel;

/// PB-15's CSV export (Phase 20) — a plain string formatter, no new
/// dependency, per the plan. None of the labels this writes (severity/
/// status names, "Total") contain a comma or quote, so no CSV-escaping
/// logic is needed — a genuinely free-text field would need one, but
/// nothing here is free text.
String buildMonitoringReportCsv(MonitoringReport report) {
  final buffer = StringBuffer()
    ..writeln('System Monitoring Report')
    ..writeln('Date range,${monitoringReportRangeLabel(report)}')
    ..writeln();

  _writeSection(
    buffer,
    'Errors by Severity',
    'Severity',
    [for (final s in ErrorSeverity.values) (errorSeverityLabel(s), report.errorCountsBySeverity[s] ?? 0)],
    report.totalErrors,
  );
  _writeSection(
    buffer,
    'AI Requests by Status',
    'Status',
    [for (final s in AiRequestStatus.values) (aiRequestStatusLabel(s), report.aiRequestCountsByStatus[s] ?? 0)],
    report.totalAiRequests,
  );
  _writeSection(
    buffer,
    'Issue Reports by Status',
    'Status',
    [for (final s in IssueReportStatus.values) (issueReportStatusLabel(s), report.issueCountsByStatus[s] ?? 0)],
    report.totalIssues,
  );

  return buffer.toString();
}

void _writeSection(
  StringBuffer buffer,
  String title,
  String columnLabel,
  List<(String, int)> rows,
  int total,
) {
  buffer
    ..writeln(title)
    ..writeln('$columnLabel,Count');
  for (final (label, count) in rows) {
    buffer.writeln('$label,$count');
  }
  buffer
    ..writeln('Total,$total')
    ..writeln();
}
