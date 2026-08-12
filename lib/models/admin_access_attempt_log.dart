/// A record of a rejected admin sign-in attempt (PB-01) — someone reached
/// `AdminLoginScreen` and completed Google sign-in, but the post-sign-in
/// role check failed.
///
/// Deliberately **not** folded into [AdminAuditLog]: that table's shape
/// (`adminUserId`, `targetUserId`, `AdminAction { suspend, reactivate }`)
/// assumes the actor already is an admin acting on a target account. A
/// rejected sign-in has no admin actor at all — the attempter *is* the
/// subject, and there's no "action taken on their account" yet, only an
/// attempt. Added per team decision (2026-08-12, `docs/admin/PROGRESS.md`):
/// any non-admin sign-in attempt against the admin portal must be visible
/// to admins so they can decide on a warning/penalty later — the recording
/// half is built now, the warning/penalty mechanism itself is explicitly
/// deferred (undecided).
class AdminAccessAttemptLog {
  final String logId;

  /// The id Google/Supabase Auth returned for the signed-in account —
  /// always present (sign-in itself succeeded), even when no [Profile] row
  /// exists for it yet.
  final String attemptedUserId;
  final String attemptedEmail;
  final AdminAccessAttemptReason reason;
  final DateTime createdAt;

  const AdminAccessAttemptLog({
    required this.logId,
    required this.attemptedUserId,
    required this.attemptedEmail,
    required this.reason,
    required this.createdAt,
  });

  factory AdminAccessAttemptLog.fromJson(Map<String, dynamic> json) {
    return AdminAccessAttemptLog(
      logId: json['logId'] as String,
      attemptedUserId: json['attemptedUserId'] as String,
      attemptedEmail: json['attemptedEmail'] as String,
      reason: AdminAccessAttemptReason.values.firstWhere(
        (r) => r.name == json['reason'],
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'logId': logId,
      'attemptedUserId': attemptedUserId,
      'attemptedEmail': attemptedEmail,
      'reason': reason.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Why an admin sign-in attempt was rejected.
enum AdminAccessAttemptReason {
  /// The signed-in account has a `Profile`, but `role != UserRole.admin`.
  notAnAdmin,

  /// No `Profile` row exists at all for the signed-in account.
  noProfileFound,

  /// `role == UserRole.admin`, but the account isn't active (suspended or
  /// deactivated) — covers an admin account another admin has suspended.
  adminAccountNotActive,
}
