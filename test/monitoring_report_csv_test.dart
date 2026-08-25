import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/monitoring_report.dart';
import 'package:tripjournal/features/admin/monitoring_report_csv.dart';
import 'package:tripjournal/models/ai_request_log.dart';
import 'package:tripjournal/models/issue_report.dart';
import 'package:tripjournal/models/system_error_log.dart';

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
  group('buildMonitoringReportCsv', () {
    test('includes every section header and the date range', () {
      final csv = buildMonitoringReportCsv(_report());

      expect(csv, contains('System Monitoring Report'));
      expect(csv, contains('Date range,All time'));
      expect(csv, contains('Errors by Severity'));
      expect(csv, contains('AI Requests by Status'));
      expect(csv, contains('Issue Reports by Status'));
    });

    test('writes each severity/status label with its count', () {
      final csv = buildMonitoringReportCsv(_report());

      expect(csv, contains('Warning,2'));
      expect(csv, contains('Fatal,1'));
      expect(csv, contains('Succeeded,5'));
      expect(csv, contains('Failed,1'));
      expect(csv, contains('Open,2'));
      expect(csv, contains('In Progress,1'));
      expect(csv, contains('Resolved,3'));
    });

    test('writes a Total row per section matching the sum of that section',
        () {
      final csv = buildMonitoringReportCsv(_report());
      final lines = csv.split('\n');

      // Errors: 1 + 2 + 0 + 1 = 4; AI requests: 5 + 1 = 6; issues: 2+1+3 = 6.
      expect(lines.where((l) => l == 'Total,4'), hasLength(1));
      expect(lines.where((l) => l == 'Total,6'), hasLength(2));
    });

    test('is valid CSV structure — every non-header, non-title data row has '
        'exactly one comma', () {
      final csv = buildMonitoringReportCsv(_report());
      final dataLines = csv
          .split('\n')
          .where((l) => l.contains(',') && !l.startsWith('Date range'));

      for (final line in dataLines) {
        expect(line.split(',').length, 2, reason: 'malformed row: "$line"');
      }
    });
  });
}
