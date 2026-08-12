import '../models/admin_access_attempt_log.dart';
import 'admin_access_attempt_log_repository.dart';

/// In-memory fake of [AdminAccessAttemptLogRepository], mirroring
/// [MockAdminAuditLogRepository]'s shape.
class MockAdminAccessAttemptLogRepository implements AdminAccessAttemptLogRepository {
  final List<AdminAccessAttemptLog> _entries = [];

  /// Monotonic counter so two entries recorded in the same millisecond
  /// still get distinct ids, mirroring `MockAdminAuditLogRepository`'s
  /// `_logCounter` pattern.
  int _logCounter = 0;

  /// All recorded entries, exposed for tests to inspect state.
  List<AdminAccessAttemptLog> get entries => List.unmodifiable(_entries);

  @override
  Future<void> recordAttempt(AdminAccessAttemptLog entry) async {
    _entries.add(entry);
  }

  @override
  Future<List<AdminAccessAttemptLog>> getRecentAttempts({int? limit}) async {
    final sorted = List<AdminAccessAttemptLog>.from(_entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (limit == null || sorted.length <= limit) return sorted;
    return sorted.sublist(0, limit);
  }

  @override
  Future<List<AdminAccessAttemptLog>> getAttemptsForUserId(String userId) async {
    final matches = _entries.where((e) => e.attemptedUserId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches;
  }

  /// Generates a unique log id for callers composing an
  /// [AdminAccessAttemptLog] before calling [recordAttempt] (mirrors
  /// `MockAdminAuditLogRepository.nextLogId()`).
  String nextLogId() {
    _logCounter++;
    return 'access-attempt-${DateTime.now().millisecondsSinceEpoch}-$_logCounter';
  }
}
