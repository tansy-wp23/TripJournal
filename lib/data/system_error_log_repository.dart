import '../models/system_error_log.dart';

/// Maps to PB-11 (Monitor System Error Logs), Sprint 3. Real implementation
/// (Phase 21, later sprint): `system_error_logs` table, insert-only from the
/// `main.dart` error hook, readable by `is_admin_user()` callers via RLS.
abstract class SystemErrorLogRepository {
  /// Appends an error entry. Called by the global error hook in `main.dart`
  /// (Architecture Decision 9), not directly by UI code.
  Future<void> recordError(SystemErrorLog entry);

  /// All error entries, newest first, optionally narrowed by [module]
  /// and/or [severity] — backs PB-11's "filtering by module and severity".
  Future<List<SystemErrorLog>> getAllErrors({
    String? module,
    ErrorSeverity? severity,
  });
}
