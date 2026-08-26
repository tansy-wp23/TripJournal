import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/ai_request_log.dart';
import '../../../models/issue_report.dart';
import '../../../models/system_error_log.dart';
import '../../journal/widgets/format_utils.dart' show formatDate;
import '../admin_format_utils.dart';
import '../monitoring_report.dart';

/// PB-15's PDF export (Phase 20, Architecture Decision 11) — built the same
/// way `journal_pdf_export.dart` builds its documents (a `pw.Document`, one
/// page, returned as bytes for the caller to share via `Printing.sharePdf`),
/// so this doesn't introduce a second PDF-building convention.
Future<Uint8List> buildMonitoringReportPdf(MonitoringReport report) async {
  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'System Monitoring Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(monitoringReportRangeLabel(report)),
          pw.SizedBox(height: 20),
          _section(
            'Errors by Severity',
            [
              for (final severity in ErrorSeverity.values)
                _row(errorSeverityLabel(severity), report.errorCountsBySeverity[severity] ?? 0),
            ],
            report.totalErrors,
          ),
          pw.SizedBox(height: 16),
          _section(
            'AI Requests by Status',
            [
              for (final status in AiRequestStatus.values)
                _row(aiRequestStatusLabel(status), report.aiRequestCountsByStatus[status] ?? 0),
            ],
            report.totalAiRequests,
          ),
          pw.SizedBox(height: 16),
          _section(
            'Issue Reports by Status',
            [
              for (final status in IssueReportStatus.values)
                _row(issueReportStatusLabel(status), report.issueCountsByStatus[status] ?? 0),
            ],
            report.totalIssues,
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

pw.Widget _section(String title, List<pw.Widget> rows, int total) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        ...rows,
        pw.Divider(),
        _row('Total', total, bold: true),
      ],
    ),
  );
}

pw.Widget _row(String label, int count, {bool bold = false}) {
  final style = bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null;
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text('$count', style: style),
      ],
    ),
  );
}

/// "1 Jan 2026 – 15 Jan 2026", or "All time" with no range set — shared
/// between the PDF and CSV builders (and the screen's own header) so they
/// can't drift on wording.
String monitoringReportRangeLabel(MonitoringReport report) {
  final start = report.startDate;
  final end = report.endDate;
  if (start == null && end == null) return 'All time';
  if (start != null && end != null) {
    return '${formatDate(start)} – ${formatDate(end)}';
  }
  if (start != null) return 'From ${formatDate(start)}';
  return 'Until ${formatDate(end!)}';
}

/// Filesystem/share-safe filename shared by the PDF and CSV exports —
/// mirrors `journal_pdf_export.dart`'s `pdfFileNameFor` in spirit (kept as
/// a separate small helper here rather than importing that Journal-module
/// file from the Admin feature for one five-line function).
String monitoringReportFileNameFor(MonitoringReport report, String extension) {
  final start = report.startDate;
  final end = report.endDate;
  if (start == null && end == null) return 'monitoring_report_all_time.$extension';
  final startLabel = start != null ? _isoDate(start) : 'start';
  final endLabel = end != null ? _isoDate(end) : 'end';
  return 'monitoring_report_${startLabel}_to_$endLabel.$extension';
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
