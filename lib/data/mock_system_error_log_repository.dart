import '../models/system_error_log.dart';
import 'system_error_log_repository.dart';

/// In-memory fake of [SystemErrorLogRepository] so UI work never blocks on a
/// backend. Seeded with sample errors across modules/severities (Phase 16)
/// so PB-11's filtering has something to demonstrate against out of the box.
class MockSystemErrorLogRepository implements SystemErrorLogRepository {
  final List<SystemErrorLog> _entries;

  /// Monotonic counter so two entries recorded in the same millisecond still
  /// get distinct ids, mirroring `MockAdminAuditLogRepository`'s
  /// `_logCounter` pattern.
  int _logCounter = 0;

  MockSystemErrorLogRepository({List<SystemErrorLog>? seed})
    : _entries = seed ?? defaultSeed();

  static List<SystemErrorLog> defaultSeed() {
    final now = DateTime.now();
    DateTime hoursAgo(int hours) => now.subtract(Duration(hours: hours));

    return [
      SystemErrorLog(
        logId: 'error-seed-1',
        module: 'journal',
        severity: ErrorSeverity.error,
        message: 'Failed to upload journal photo: storage quota exceeded.',
        stackTrace: null,
        createdAt: hoursAgo(2),
      ),
      SystemErrorLog(
        logId: 'error-seed-2',
        module: 'trip',
        severity: ErrorSeverity.warning,
        message: 'Trip summary generation took longer than expected (12s).',
        stackTrace: null,
        createdAt: hoursAgo(6),
      ),
      SystemErrorLog(
        logId: 'error-seed-3',
        module: 'auth',
        severity: ErrorSeverity.fatal,
        message: 'Unhandled exception during sign-in redirect.',
        stackTrace: 'PlatformException(sign_in_failed, ...)',
        createdAt: hoursAgo(20),
      ),
      SystemErrorLog(
        logId: 'error-seed-4',
        module: 'health',
        severity: ErrorSeverity.info,
        message: 'Health Connect not available on this device; using manual entry.',
        stackTrace: null,
        createdAt: hoursAgo(30),
      ),
      SystemErrorLog(
        logId: 'error-seed-5',
        module: 'journal',
        severity: ErrorSeverity.warning,
        message: 'Food detection returned a low-confidence match.',
        stackTrace: null,
        createdAt: hoursAgo(50),
      ),
    ];
  }

  /// All recorded entries, exposed for tests to inspect state.
  List<SystemErrorLog> get entries => List.unmodifiable(_entries);

  @override
  Future<void> recordError(SystemErrorLog entry) async {
    _entries.add(entry);
  }

  @override
  Future<List<SystemErrorLog>> getAllErrors({
    String? module,
    ErrorSeverity? severity,
  }) async {
    final matches = _entries.where((e) {
      if (module != null && e.module != module) return false;
      if (severity != null && e.severity != severity) return false;
      return true;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches;
  }

  /// Generates a unique log id for callers composing a [SystemErrorLog]
  /// before calling [recordError] (the `main.dart` global error hook).
  String nextLogId() {
    _logCounter++;
    return 'error-${DateTime.now().millisecondsSinceEpoch}-$_logCounter';
  }
}
