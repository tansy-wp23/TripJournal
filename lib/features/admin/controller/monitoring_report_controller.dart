import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/admin_repository_locator.dart';
import '../../../data/ai_request_log_repository.dart';
import '../../../data/issue_report_repository.dart';
import '../../../data/system_error_log_repository.dart';
import '../../../models/ai_request_log.dart';
import '../../../models/issue_report.dart';
import '../../../models/system_error_log.dart';
import '../monitoring_report.dart';

/// PB-15 (Generate System Monitoring Reports, Phase 20). Draws on three
/// repositories — none of which support a date-range parameter on their own
/// `getAll*` methods — so this fetches everything from each and filters to
/// [startDate]/[endDate] here, mirroring how `AuditLogController` composes
/// data its own repository doesn't filter for it either.
class MonitoringReportController extends ChangeNotifier {
  MonitoringReportController(
    this._systemErrorLogRepository,
    this._aiRequestLogRepository,
    this._issueReportRepository,
  );

  final SystemErrorLogRepository _systemErrorLogRepository;
  final AiRequestLogRepository _aiRequestLogRepository;
  final IssueReportRepository _issueReportRepository;

  DateTime? _startDate;
  DateTime? _endDate;
  MonitoringReport? _report;
  bool _loading = false;
  String? _error;

  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  MonitoringReport? get report => _report;
  bool get loading => _loading;
  String? get error => _error;

  bool _inRange(DateTime time) {
    final start = _startDate;
    final end = _endDate;
    if (start != null && time.isBefore(start)) return false;
    if (end != null && time.isAfter(end)) return false;
    return true;
  }

  /// Applies a date range (or clears it, passing both null) and regenerates
  /// — mirrors `AuditLogController.setDateRange`'s auto-reload-on-filter-
  /// change convention, so this screen doesn't need a separate "Apply"/
  /// "Generate" step beyond picking the range.
  Future<void> setDateRange({DateTime? start, DateTime? end}) {
    _startDate = start;
    _endDate = end;
    return generate();
  }

  Future<void> generate() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final errors = (await _systemErrorLogRepository.getAllErrors())
          .where((e) => _inRange(e.createdAt));
      final aiRequests = (await _aiRequestLogRepository.getAllRequests())
          .where((e) => _inRange(e.createdAt));
      final issues = (await _issueReportRepository.getAllReports())
          .where((e) => _inRange(e.createdAt));

      final errorCounts = {for (final s in ErrorSeverity.values) s: 0};
      for (final e in errors) {
        errorCounts[e.severity] = (errorCounts[e.severity] ?? 0) + 1;
      }

      final aiRequestCounts = {for (final s in AiRequestStatus.values) s: 0};
      for (final e in aiRequests) {
        aiRequestCounts[e.status] = (aiRequestCounts[e.status] ?? 0) + 1;
      }

      final issueCounts = {for (final s in IssueReportStatus.values) s: 0};
      for (final e in issues) {
        issueCounts[e.status] = (issueCounts[e.status] ?? 0) + 1;
      }

      _report = MonitoringReport(
        startDate: _startDate,
        endDate: _endDate,
        errorCountsBySeverity: errorCounts,
        aiRequestCountsByStatus: aiRequestCounts,
        issueCountsByStatus: issueCounts,
      );
    } catch (e) {
      _error = 'Could not generate the monitoring report: $e';
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = false;
    notifyListeners();
  }
}

/// The single place the app resolves its [MonitoringReportController] from
/// — mirrors `auditLogControllerProvider`.
final monitoringReportControllerProvider =
    ChangeNotifierProvider<MonitoringReportController>(
      (ref) => MonitoringReportController(
        systemErrorLogRepository,
        aiRequestLogRepository,
        issueReportRepository,
      ),
    );
