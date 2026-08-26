import 'package:flutter/material.dart' show IconData, Icons;

import '../../models/admin_access_attempt_log.dart';
import '../../models/admin_audit_log.dart';
import '../../models/ai_request_log.dart';
import '../../models/issue_report.dart';
import '../../models/system_error_log.dart';

/// Shared formatting helpers for the admin feature — extracted from
/// `AdminDashboardScreen`'s original private `_formatTimestamp`/
/// `_reasonLabel` so `AdminUserDetailScreen`'s audit/access-attempt
/// sections (Phase 4) don't duplicate them.
String formatRelativeTime(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String accessAttemptReasonLabel(AdminAccessAttemptReason reason) {
  switch (reason) {
    case AdminAccessAttemptReason.notAnAdmin:
      return 'Not an administrator';
    case AdminAccessAttemptReason.noProfileFound:
      return 'No account on record';
    case AdminAccessAttemptReason.adminAccountNotActive:
      return 'Admin account not active';
  }
}

/// Shared display label for an [IssueReportStatus] — used by
/// `AdminIssueReportListScreen` (Phase 10) and `IssueReportDetailScreen`
/// (Phase 11) so the two screens can't drift on wording.
String issueReportStatusLabel(IssueReportStatus status) {
  switch (status) {
    case IssueReportStatus.open:
      return 'Open';
    case IssueReportStatus.inProgress:
      return 'In Progress';
    case IssueReportStatus.resolved:
      return 'Resolved';
  }
}

/// Shared label/icon for an [AdminAuditLog] entry's [AdminAction] —
/// extracted from `AdminUserDetailScreen`'s original private
/// `_AuditLogTile` switch (Phase 4) so `IssueReportDetailScreen`'s own
/// status-history section (Phase 11) doesn't duplicate it. Both screens'
/// audit tiles use these, even though each only ever loads history for one
/// `AdminAuditTargetType` — the switch stays exhaustive across both target
/// types regardless of which screen is asking (Sprint 2, Phase 8).
String adminActionLabel(AdminAction action) {
  switch (action) {
    case AdminAction.suspend:
      return 'Suspended';
    case AdminAction.reactivate:
      return 'Reactivated';
    case AdminAction.issueMarkInProgress:
      return 'Marked In Progress';
    case AdminAction.issueMarkResolved:
      return 'Marked Resolved';
    case AdminAction.issueReopen:
      return 'Reopened';
  }
}

/// Shared display label for an [AdminAuditTargetType] — used by
/// `AuditLogScreen`'s global view (Phase 13), the only screen that ever
/// shows entries spanning more than one target type at once.
String adminAuditTargetTypeLabel(AdminAuditTargetType targetType) {
  switch (targetType) {
    case AdminAuditTargetType.user:
      return 'User';
    case AdminAuditTargetType.issueReport:
      return 'Issue Report';
  }
}

/// Shared display label for an [ErrorSeverity] — used by
/// `SystemErrorLogScreen` (Phase 17) and, per the Sprint 3 plan,
/// `MonitoringReportScreen` (Phase 20)'s error-count-by-severity summary, so
/// the two can't drift on wording.
String errorSeverityLabel(ErrorSeverity severity) {
  switch (severity) {
    case ErrorSeverity.info:
      return 'Info';
    case ErrorSeverity.warning:
      return 'Warning';
    case ErrorSeverity.error:
      return 'Error';
    case ErrorSeverity.fatal:
      return 'Fatal';
  }
}

/// Shared display label for an [AiRequestType] — used by
/// `AiRequestMonitoringScreen` and `FailedAiRequestsScreen` (Phase 18) so
/// the two can't drift on wording.
String aiRequestTypeLabel(AiRequestType type) {
  switch (type) {
    case AiRequestType.dailyAdvice:
      return 'Daily Advice';
    case AiRequestType.foodDetection:
      return 'Food Detection';
    case AiRequestType.tripSummary:
      return 'Trip Summary';
  }
}

/// Shared display label for an [AiRequestStatus] — same reuse reason as
/// [aiRequestTypeLabel].
String aiRequestStatusLabel(AiRequestStatus status) {
  switch (status) {
    case AiRequestStatus.succeeded:
      return 'Succeeded';
    case AiRequestStatus.failed:
      return 'Failed';
  }
}

IconData adminActionIcon(AdminAction action) {
  switch (action) {
    case AdminAction.suspend:
      return Icons.block;
    case AdminAction.reactivate:
      return Icons.check_circle;
    case AdminAction.issueMarkInProgress:
      return Icons.hourglass_top;
    case AdminAction.issueMarkResolved:
      return Icons.check_circle;
    case AdminAction.issueReopen:
      return Icons.replay;
  }
}
