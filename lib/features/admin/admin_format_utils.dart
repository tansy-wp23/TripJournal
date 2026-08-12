import '../../models/admin_access_attempt_log.dart';

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
