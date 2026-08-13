import 'package:flutter/foundation.dart';

import '../../../data/admin_audit_log_repository.dart';
import '../../../data/admin_user_directory_repository.dart';
import '../../../data/issue_report_repository.dart';
import '../../../models/admin_audit_log.dart';
import '../../../models/issue_report.dart';
import '../../../models/profile.dart';

/// PB-08: loads one [IssueReport] by id, the submitting user's [Profile]
/// (via `AdminUserDirectoryRepository.getUserById` — reusing Sprint 1's
/// lookup rather than duplicating one, per the plan's Phase 11 task 1),
/// and its status-change history (`AdminAuditLog`, `targetType:
/// issueReport`).
///
/// Only reads — PB-09's status-update write happens directly from
/// `IssueReportDetailScreen` against `issueReportRepository`, then calls
/// [load] again to refresh, mirroring the split `AdminUserDetailController`
/// (reads) / `AdminUserDetailScreen` (writes) already established for
/// suspend/reactivate.
///
/// Deliberately **not** a global `ChangeNotifierProvider`, same reasoning
/// as `AdminUserDetailController` — per-report, constructed fresh by
/// `IssueReportDetailScreen` for whichever `reportId` it's showing.
class IssueReportDetailController extends ChangeNotifier {
  IssueReportDetailController(
    this._issueReportRepository,
    this._userDirectoryRepository,
    this._auditLogRepository,
  );

  final IssueReportRepository _issueReportRepository;
  final AdminUserDirectoryRepository _userDirectoryRepository;
  final AdminAuditLogRepository _auditLogRepository;

  IssueReport? _report;
  Profile? _submitter;
  List<AdminAuditLog> _statusHistory = [];
  bool _loading = false;
  String? _error;

  IssueReport? get report => _report;

  /// The profile that filed [report], or null if either it hasn't loaded
  /// yet or the submitting account no longer exists — a distinct case from
  /// [error], which means the *report itself* failed to load.
  Profile? get submitter => _submitter;
  List<AdminAuditLog> get statusHistory => _statusHistory;
  bool get loading => _loading;
  String? get error => _error;

  /// Fetches (or re-fetches) [reportId]'s report, submitter, and status
  /// history. Safe to call again, e.g. from a retry button or after a
  /// Phase 12 status-update action.
  Future<void> load(String reportId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final report = await _issueReportRepository.getReportById(reportId);
      _report = report;
      if (report == null) {
        _error = 'No issue report found with id $reportId.';
      } else {
        _submitter = await _userDirectoryRepository.getUserById(report.submittedByUserId);
        _statusHistory = await _auditLogRepository.getHistoryForTarget(
          targetType: AdminAuditTargetType.issueReport,
          targetId: reportId,
        );
      }
    } catch (e) {
      _error = 'Could not load this issue report: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
