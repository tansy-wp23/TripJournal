import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/monitoring_report.dart';
import 'package:tripjournal/features/admin/pdf/monitoring_report_pdf.dart';
import 'package:tripjournal/models/ai_request_log.dart';
import 'package:tripjournal/models/issue_report.dart';
import 'package:tripjournal/models/system_error_log.dart';

bool _looksLikePdf(List<int> bytes) {
  // Every valid PDF starts with the "%PDF" magic bytes — same check
  // journal_pdf_export_test.dart uses.
  return bytes.length > 4 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46;
}

MonitoringReport _report({DateTime? startDate, DateTime? endDate}) {
  return MonitoringReport(
    startDate: startDate,
    endDate: endDate,
    errorCountsBySeverity: {
      ErrorSeverity.info: 1,
      ErrorSeverity.warning: 2,
      ErrorSeverity.error: 0,
      ErrorSeverity.fatal: 1,
    },
    aiRequestCountsByStatus: {
      AiRequestStatus.succeeded: 5,
      AiRequestStatus.failed: 1,
    },
    issueCountsByStatus: {
      IssueReportStatus.open: 2,
      IssueReportStatus.inProgress: 1,
      IssueReportStatus.resolved: 3,
    },
  );
}

void main() {
  group('buildMonitoringReportPdf', () {
    test('produces a valid, non-empty PDF document', () async {
      final bytes = await buildMonitoringReportPdf(_report());

      expect(_looksLikePdf(bytes), isTrue);
      expect(bytes.length, greaterThan(100));
    });

    test('still produces a valid PDF with an all-time (no range) report', () async {
      final bytes = await buildMonitoringReportPdf(_report());

      expect(_looksLikePdf(bytes), isTrue);
    });

    test('still produces a valid PDF with an empty (all-zero) report', () async {
      final empty = MonitoringReport(
        errorCountsBySeverity: {for (final s in ErrorSeverity.values) s: 0},
        aiRequestCountsByStatus: {for (final s in AiRequestStatus.values) s: 0},
        issueCountsByStatus: {for (final s in IssueReportStatus.values) s: 0},
      );

      final bytes = await buildMonitoringReportPdf(empty);

      expect(_looksLikePdf(bytes), isTrue);
    });
  });

  group('monitoringReportRangeLabel', () {
    test('reads "All time" with no range set', () {
      expect(monitoringReportRangeLabel(_report()), 'All time');
    });

    test('shows both dates when a full range is set', () {
      final label = monitoringReportRangeLabel(
        _report(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31)),
      );
      expect(label, contains('–'));
    });
  });

  group('monitoringReportFileNameFor', () {
    test('names an all-time report distinctly', () {
      final name = monitoringReportFileNameFor(_report(), 'pdf');
      expect(name, 'monitoring_report_all_time.pdf');
    });

    test('embeds the ISO start/end dates when a range is set', () {
      final name = monitoringReportFileNameFor(
        _report(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31)),
        'csv',
      );
      expect(name, 'monitoring_report_2026-01-01_to_2026-01-31.csv');
    });
  });
}
