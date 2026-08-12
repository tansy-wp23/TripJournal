import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/admin_audit_log_repository.dart';
import '../../../data/admin_repository_locator.dart';
import '../../../data/admin_user_directory_repository.dart';
import '../../../data/issue_report_repository.dart';
import '../../../models/admin_audit_log.dart';
import '../../../models/issue_report.dart';
import '../../../models/profile.dart';

/// PB-10 (Sprint 2 — Monitor Audit Log, Phase 13). Loads every audit entry
/// across every admin and every target via
/// `AdminAuditLogRepository.getAllEntries`, exposing loading/error/data —
/// mirrors `IssueReportManagementController`'s plain `ChangeNotifier` +
/// manual loading/error flags convention, for consistency with the rest of
/// the admin feature.
///
/// Distinct from Sprint 1's per-target history sections
/// (`AdminUserDetailController`/`IssueReportDetailController`, both backed
/// by `getHistoryForTarget`) — this is the global view those two were never
/// meant to be.
///
/// Also resolves display labels for the raw ids an [AdminAuditLog] entry
/// carries (post-Phase-13 improvement, 2026-08-12) — an id on its own
/// ("admin-001", "user-101") isn't meaningful to an admin scanning history.
/// Needs two more repositories beyond [AdminAuditLogRepository] for this:
/// [AdminUserDirectoryRepository] (acting admins and `user`-type targets)
/// and [IssueReportRepository] (`issueReport`-type targets, which don't have
/// a "display name" the way a `Profile` does — [targetLabel] falls back to
/// the report's description instead).
class AuditLogController extends ChangeNotifier {
  AuditLogController(this._repository, this._userDirectoryRepository, this._issueReportRepository);

  final AdminAuditLogRepository _repository;
  final AdminUserDirectoryRepository _userDirectoryRepository;
  final IssueReportRepository _issueReportRepository;

  List<AdminAuditLog> _entries = [];
  bool _loading = false;
  String? _error;

  AdminAuditTargetType? _targetTypeFilter;
  AdminAction? _actionFilter;
  DateTime? _startDate;
  DateTime? _endDate;

  // Caches keyed by id, populated by _resolveLabels. A key present with a
  // null value means that id was looked up and came back unresolvable
  // (deleted account/report) — distinct from a key that's simply never
  // been looked up yet — so a not-found result isn't re-fetched on every
  // subsequent load(). Persists across filter changes/reloads for the life
  // of the controller; a name changing mid-session would show stale until
  // the screen is rebuilt from scratch, an acceptable trade-off for
  // mock-data session lengths.
  final Map<String, Profile?> _userCache = {};
  final Map<String, IssueReport?> _reportCache = {};

  List<AdminAuditLog> get entries => _entries;
  bool get loading => _loading;
  String? get error => _error;
  AdminAuditTargetType? get targetTypeFilter => _targetTypeFilter;
  AdminAction? get actionFilter => _actionFilter;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  bool get hasActiveFilter =>
      _targetTypeFilter != null ||
      _actionFilter != null ||
      _startDate != null ||
      _endDate != null;

  /// Display label for the admin who performed an entry's action — the
  /// resolved display name, or the raw id if that account no longer
  /// resolves (or hasn't been resolved yet).
  String adminLabel(String adminUserId) => _userCache[adminUserId]?.displayName ?? adminUserId;

  /// Display label for an entry's target — a resolved user's display name,
  /// a resolved issue report's description, or the raw
  /// [AdminAuditLog.targetId] if that lookup came back null.
  String targetLabel(AdminAuditLog entry) {
    switch (entry.targetType) {
      case AdminAuditTargetType.user:
        return _userCache[entry.targetId]?.displayName ?? entry.targetId;
      case AdminAuditTargetType.issueReport:
        return _reportCache[entry.targetId]?.description ?? entry.targetId;
    }
  }

  /// Loads (or reloads) all entries, respecting the current filters. Safe to
  /// call again after an error (e.g. from a retry button) — clears the prior
  /// error first.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _entries = await _repository.getAllEntries(
        targetTypeFilter: _targetTypeFilter,
        actionFilter: _actionFilter,
        startDate: _startDate,
        endDate: _endDate,
      );
    } catch (e) {
      _error = 'Could not load the audit log: $e';
      _loading = false;
      notifyListeners();
      return;
    }

    // Best-effort — a naming lookup failing shouldn't block the audit log
    // itself from showing; adminLabel/targetLabel fall back to the raw id
    // regardless of whether a lookup errored or simply returned null.
    try {
      await _resolveLabels();
    } catch (_) {
      // ignore — labels just fall back to raw ids
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> _resolveLabels() async {
    final userIds = <String>{};
    final reportIds = <String>{};
    for (final entry in _entries) {
      if (!_userCache.containsKey(entry.adminUserId)) userIds.add(entry.adminUserId);
      if (entry.targetType == AdminAuditTargetType.user && !_userCache.containsKey(entry.targetId)) {
        userIds.add(entry.targetId);
      }
      if (entry.targetType == AdminAuditTargetType.issueReport &&
          !_reportCache.containsKey(entry.targetId)) {
        reportIds.add(entry.targetId);
      }
    }
    for (final id in userIds) {
      _userCache[id] = await _userDirectoryRepository.getUserById(id);
    }
    for (final id in reportIds) {
      _reportCache[id] = await _issueReportRepository.getReportById(id);
    }
  }

  /// Applies a target-type filter (or clears it, passing null) and reloads.
  /// Clears the action filter too when it no longer applies to the new
  /// target type (e.g. switching to "User" while "Marked Resolved" was
  /// selected) rather than silently keeping a filter combination that could
  /// never match anything.
  Future<void> setTargetTypeFilter(AdminAuditTargetType? targetType) {
    _targetTypeFilter = targetType;
    final currentAction = _actionFilter;
    if (currentAction != null &&
        !actionsForTargetType(targetType).contains(currentAction)) {
      _actionFilter = null;
    }
    return load();
  }

  Future<void> setActionFilter(AdminAction? action) {
    _actionFilter = action;
    return load();
  }

  Future<void> setDateRange({DateTime? start, DateTime? end}) {
    _startDate = start;
    _endDate = end;
    return load();
  }

  Future<void> clearFilters() {
    _targetTypeFilter = null;
    _actionFilter = null;
    _startDate = null;
    _endDate = null;
    return load();
  }
}

/// Which [AdminAction] values are meaningful for a given target-type filter
/// — `suspend`/`reactivate` only ever target a `user`; the three `issue*`
/// actions only ever target an `issueReport`. `null` (no target-type filter)
/// offers every action. Shared between the controller (to drop a
/// now-irrelevant action filter) and the screen (to populate the action
/// dropdown's choices).
List<AdminAction> actionsForTargetType(AdminAuditTargetType? targetType) {
  switch (targetType) {
    case null:
      return AdminAction.values;
    case AdminAuditTargetType.user:
      return const [AdminAction.suspend, AdminAction.reactivate];
    case AdminAuditTargetType.issueReport:
      return const [
        AdminAction.issueMarkInProgress,
        AdminAction.issueMarkResolved,
        AdminAction.issueReopen,
      ];
  }
}

/// The single place the app resolves its [AuditLogController] from —
/// mirrors `issueReportManagementControllerProvider`.
final auditLogControllerProvider = ChangeNotifierProvider<AuditLogController>(
  (ref) => AuditLogController(
    adminAuditLogRepository,
    adminUserDirectoryRepository,
    issueReportRepository,
  ),
);
