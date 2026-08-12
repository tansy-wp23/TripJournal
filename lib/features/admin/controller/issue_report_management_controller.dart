import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/admin_repository_locator.dart';
import '../../../data/issue_report_repository.dart';
import '../../../models/issue_report.dart';

/// PB-07: View System Issue Reports. Loads `IssueReport`s via
/// `IssueReportRepository.getAllReports`, exposing loading/error/data
/// states — mirrors `AdminDashboardController`'s plain `ChangeNotifier` +
/// manual loading/error flags convention, for consistency with the rest of
/// the admin feature.
///
/// Supports an optional status filter (`ADMIN_MODULE_IMPLEMENTATION_PLAN.md`
/// Sprint 2, Phase 10, task 4) — narrower than
/// `AdminUserManagementController`'s text-search + client-side filter
/// combination, since PB-07's backlog wording only asks for "display issue
/// summary and status", not a text search over reports.
class IssueReportManagementController extends ChangeNotifier {
  IssueReportManagementController(this._repository);

  final IssueReportRepository _repository;

  List<IssueReport> _reports = [];
  bool _loading = false;
  String? _error;
  IssueReportStatus? _statusFilter;

  List<IssueReport> get reports => _reports;
  bool get loading => _loading;
  String? get error => _error;
  IssueReportStatus? get statusFilter => _statusFilter;

  /// Loads (or reloads) all reports, respecting the current status filter.
  /// Safe to call again after an error (e.g. from a retry button) — clears
  /// the prior error first.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _reports = await _repository.getAllReports(statusFilter: _statusFilter);
    } catch (e) {
      _error = 'Could not load issue reports: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Applies a status filter (or clears it, passing null) and reloads.
  Future<void> setStatusFilter(IssueReportStatus? status) {
    _statusFilter = status;
    return load();
  }
}

/// The single place the app resolves its [IssueReportManagementController]
/// from — mirrors `adminDashboardControllerProvider`.
final issueReportManagementControllerProvider =
    ChangeNotifierProvider<IssueReportManagementController>(
  (ref) => IssueReportManagementController(issueReportRepository),
);
