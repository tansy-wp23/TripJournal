import '../models/issue_report.dart';

/// Maps to PB-06 (Submit, added scope) through PB-09 (Update Issue Status)
/// — `ADMIN_MODULE_IMPLEMENTATION_PLAN.md` Sprint 2. Real implementation
/// (later phase): `issue_reports` table; `submitReport` is a plain
/// RLS-scoped insert any signed-in user can make (their own `userId`
/// only); `updateStatus` is admin-only, same privilege boundary as
/// `AdminAccountActionsRepository`.
abstract class IssueReportRepository {
  /// Files a new report — called from `ReportIssueButton`, placed on
  /// non-admin screens. Not admin-gated: any signed-in user can submit one
  /// about their own experience.
  Future<void> submitReport({
    required String userId,
    required String page,
    required String description,
    String? screenshotUrl,
  });

  /// All reports, newest first, optionally narrowed to one status — backs
  /// PB-07's list screen.
  Future<List<IssueReport>> getAllReports({IssueReportStatus? statusFilter});

  /// A single report by id, or null if none exists — backs PB-08's detail
  /// screen.
  Future<IssueReport?> getReportById(String reportId);

  /// Updates a report's status (and optionally its remarks) — a
  /// composition (update the report + write an `AdminAuditLog` entry with
  /// `targetType: issueReport`), not raw table access from the UI, mirroring
  /// `AdminAccountActionsRepository.suspendUser`/`reactivateUser`. Backs
  /// PB-09.
  Future<void> updateStatus({
    required String adminUserId,
    required String reportId,
    required IssueReportStatus status,
    String? remarks,
  });
}
