import '../../models/ai_request_log.dart';
import '../../models/issue_report.dart';
import '../../models/system_error_log.dart';

/// PB-15 (Generate System Monitoring Reports, Phase 20). A computed
/// summary over Phases 17–19's data (system errors) and Sprint 2's issue
/// reports, narrowed to [startDate]/[endDate] if set (`null`/`null` means
/// all time). Deliberately **not** a `lib/models/` entity — nothing here is
/// persisted; it's assembled fresh by `MonitoringReportController.generate`
/// each time and only ever exists in memory for the current screen/export.
class MonitoringReport {
  const MonitoringReport({
    this.startDate,
    this.endDate,
    required this.errorCountsBySeverity,
    required this.aiRequestCountsByStatus,
    required this.issueCountsByStatus,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final Map<ErrorSeverity, int> errorCountsBySeverity;
  final Map<AiRequestStatus, int> aiRequestCountsByStatus;
  final Map<IssueReportStatus, int> issueCountsByStatus;

  int get totalErrors => errorCountsBySeverity.values.fold(0, (a, b) => a + b);
  int get totalAiRequests => aiRequestCountsByStatus.values.fold(0, (a, b) => a + b);
  int get totalIssues => issueCountsByStatus.values.fold(0, (a, b) => a + b);
}
