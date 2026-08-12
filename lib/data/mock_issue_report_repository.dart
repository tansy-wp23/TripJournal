import '../models/admin_audit_log.dart';
import '../models/issue_report.dart';
import 'issue_report_repository.dart';
import 'mock_admin_audit_log_repository.dart';

/// In-memory fake of [IssueReportRepository] so UI work in Phases 10–13
/// never blocks on a backend. Seeded with a handful of sample reports
/// spanning all three [IssueReportStatus] values, mirroring
/// `MockAdminUserStore`'s seeding approach
/// (`ADMIN_MODULE_IMPLEMENTATION_PLAN.md` Phase 9).
///
/// `updateStatus` is a composition, exactly like
/// `MockAdminAccountActionsRepository.suspendUser`/`reactivateUser`: it
/// mutates the report and writes through to [MockAdminAuditLogRepository]
/// with `targetType: issueReport`, not raw list mutation from the UI
/// (Architecture Decision 8).
class MockIssueReportRepository implements IssueReportRepository {
  final MockAdminAuditLogRepository auditLogRepository;
  final List<IssueReport> _reports;

  /// Monotonic counter so two reports submitted in the same millisecond
  /// still get distinct ids, mirroring
  /// `MockAdminAuditLogRepository.nextLogId()`'s pattern.
  int _reportCounter = 0;

  MockIssueReportRepository({
    required this.auditLogRepository,
    List<IssueReport>? seed,
  }) : _reports = seed ?? defaultSeed();

  static List<IssueReport> defaultSeed() {
    final now = DateTime.now();
    DateTime daysAgo(int days) => now.subtract(Duration(days: days));

    return [
      IssueReport(
        reportId: 'issue-001',
        submittedByUserId: 'user-101',
        page: 'TripViewScreen',
        description: 'Cover photo fails to upload when offline.',
        status: IssueReportStatus.open,
        createdAt: daysAgo(1),
        updatedAt: daysAgo(1),
      ),
      IssueReport(
        reportId: 'issue-002',
        submittedByUserId: 'user-102',
        page: 'HomeScreen',
        description: 'Dashboard stats spinner never stops on a slow connection.',
        status: IssueReportStatus.inProgress,
        adminRemarks: 'Investigating loading-state handling.',
        createdAt: daysAgo(4),
        updatedAt: daysAgo(2),
      ),
      IssueReport(
        reportId: 'issue-003',
        submittedByUserId: 'user-103',
        page: 'TripViewScreen',
        description: 'Journal entry list scrolls back to top after editing.',
        status: IssueReportStatus.resolved,
        adminRemarks: 'Fixed in the latest release.',
        createdAt: daysAgo(10),
        updatedAt: daysAgo(6),
      ),
      IssueReport(
        reportId: 'issue-004',
        submittedByUserId: 'user-105',
        page: 'HomeScreen',
        description: 'App name is misspelled on the settings page footer.',
        status: IssueReportStatus.open,
        createdAt: daysAgo(0),
        updatedAt: daysAgo(0),
      ),
    ];
  }

  @override
  Future<void> submitReport({
    required String userId,
    required String page,
    required String description,
    String? screenshotUrl,
  }) async {
    final now = DateTime.now();
    _reports.add(
      IssueReport(
        reportId: _nextReportId(),
        submittedByUserId: userId,
        page: page,
        description: description,
        screenshotUrl: screenshotUrl,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<List<IssueReport>> getAllReports({
    IssueReportStatus? statusFilter,
  }) async {
    final matches = _reports
        .where((r) => statusFilter == null || r.status == statusFilter)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches;
  }

  @override
  Future<IssueReport?> getReportById(String reportId) async {
    for (final report in _reports) {
      if (report.reportId == reportId) return report;
    }
    return null;
  }

  @override
  Future<void> updateStatus({
    required String adminUserId,
    required String reportId,
    required IssueReportStatus status,
    String? remarks,
  }) async {
    final index = _reports.indexWhere((r) => r.reportId == reportId);
    if (index == -1) {
      throw StateError('No issue report with id $reportId.');
    }
    final now = DateTime.now();
    // remarks is optional (Sprint 2 Open Decision 6) — when omitted, keep
    // whatever remarks the report already had rather than wiping them, the
    // same way `copyWith` treats a null non-cleared field everywhere else
    // in this codebase.
    _reports[index] = _reports[index].copyWith(
      status: status,
      adminRemarks: remarks,
      updatedAt: now,
    );
    await auditLogRepository.recordAction(
      AdminAuditLog(
        logId: auditLogRepository.nextLogId(),
        adminUserId: adminUserId,
        targetType: AdminAuditTargetType.issueReport,
        targetId: reportId,
        action: _actionFor(status),
        reason: remarks,
        createdAt: now,
      ),
    );
  }

  /// Every target status maps to exactly one `AdminAction` value — the
  /// three `IssueReportStatus` values and the three issue-specific
  /// `AdminAction` values were added 1:1 in Phase 8
  /// (`docs/admin/PROGRESS.md`), so this switch doesn't need to consult the
  /// report's *previous* status to pick the right verb.
  AdminAction _actionFor(IssueReportStatus status) {
    switch (status) {
      case IssueReportStatus.open:
        return AdminAction.issueReopen;
      case IssueReportStatus.inProgress:
        return AdminAction.issueMarkInProgress;
      case IssueReportStatus.resolved:
        return AdminAction.issueMarkResolved;
    }
  }

  String _nextReportId() {
    _reportCounter++;
    return 'issue-${DateTime.now().millisecondsSinceEpoch}-$_reportCounter';
  }
}
