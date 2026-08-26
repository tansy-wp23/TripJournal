import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_audit_log.dart';
import '../models/issue_report.dart';
import 'issue_report_repository.dart';

/// Real [IssueReportRepository] backed by the `issue_reports` table (Phase
/// 14 of ADMIN_MODULE_IMPLEMENTATION_PLAN.md, Sprint 2).
///
/// Unlike [AdminAccountActionsRepository]'s suspend/reactivate,
/// [updateStatus] does NOT need a privileged Edge Function — it doesn't
/// call `auth.admin.signOut()` or anything else requiring the service
/// role, so a direct RLS-scoped write from the signed-in admin's own
/// session is enough: `issue_reports_update_admin` and
/// `admin_audit_log_insert_admin` (202608190001/202608190002 migrations)
/// both gate on `is_admin_user()` evaluated against that session's own
/// `auth.uid()`.
class SupabaseIssueReportRepository implements IssueReportRepository {
  SupabaseIssueReportRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> submitReport({
    required String userId,
    required String page,
    required String description,
    String? screenshotUrl,
  }) async {
    await _client.from('issue_reports').insert({
      'submitted_by_user_id': userId,
      'page': page,
      'description': description,
      'screenshot_url': screenshotUrl,
    });
  }

  @override
  Future<List<IssueReport>> getAllReports({
    IssueReportStatus? statusFilter,
  }) async {
    var builder = _client.from('issue_reports').select();
    if (statusFilter != null) {
      builder = builder.eq('status', statusFilter.name);
    }
    final rows = await builder.order('created_at', ascending: false);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<IssueReport?> getReportById(String reportId) async {
    final row = await _client
        .from('issue_reports')
        .select()
        .eq('report_id', reportId)
        .maybeSingle();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<void> updateStatus({
    required String adminUserId,
    required String reportId,
    required IssueReportStatus status,
    String? remarks,
  }) async {
    // remarks is optional (Sprint 2 Open Decision 6) — when omitted, don't
    // send admin_remarks at all so the existing value on the row is left
    // untouched, mirroring MockIssueReportRepository's copyWith behavior.
    await _client.from('issue_reports').update({
      'status': status.name,
      'admin_remarks': ?remarks,
    }).eq('report_id', reportId);

    await _client.from('admin_audit_log').insert({
      'admin_user_id': adminUserId,
      'target_type': AdminAuditTargetType.issueReport.name,
      'target_id': reportId,
      'action': _actionFor(status).name,
      'reason': remarks,
    });
  }

  /// Every target status maps to exactly one `AdminAction` value — mirrors
  /// `MockIssueReportRepository._actionFor`.
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

  IssueReport _fromRow(Map<String, dynamic> row) {
    return IssueReport(
      reportId: row['report_id'] as String,
      submittedByUserId: row['submitted_by_user_id'] as String,
      page: row['page'] as String,
      description: row['description'] as String,
      screenshotUrl: row['screenshot_url'] as String?,
      status: IssueReportStatus.values.firstWhere(
        (s) => s.name == row['status'],
        orElse: () => IssueReportStatus.open,
      ),
      adminRemarks: row['admin_remarks'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
