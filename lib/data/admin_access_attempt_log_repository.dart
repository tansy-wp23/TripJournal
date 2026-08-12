import '../models/admin_access_attempt_log.dart';

/// Records rejected admin sign-in attempts (see
/// `AdminAccessAttemptLog`'s doc comment for why this is a separate table
/// from `AdminAuditLogRepository`). Real implementation (Phase 7): an
/// insert-only `admin_access_attempt_log` table, written from
/// `AdminAuthController`'s equivalent server-side check, readable by
/// `role == admin` callers via RLS.
abstract class AdminAccessAttemptLogRepository {
  /// Appends an attempt entry. Called by `AdminAuthController` on a
  /// rejected sign-in, not directly by UI code.
  Future<void> recordAttempt(AdminAccessAttemptLog entry);

  /// The most recent attempts across all accounts, newest first, capped at
  /// [limit] (all of them if null) — backs the dashboard's "recent
  /// unauthorized attempts" section.
  Future<List<AdminAccessAttemptLog>> getRecentAttempts({int? limit});

  /// All attempts recorded against [userId], newest first — for a future
  /// per-user review (e.g. on `AdminUserDetailScreen`, Phase 4/5) once a
  /// warning/penalty mechanism is decided.
  Future<List<AdminAccessAttemptLog>> getAttemptsForUserId(String userId);
}
