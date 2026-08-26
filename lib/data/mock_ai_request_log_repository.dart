import '../models/ai_request_log.dart';
import 'ai_request_log_repository.dart';

/// In-memory fake of [AiRequestLogRepository] so UI work never blocks on a
/// backend. Seeded with a mix of succeeded/failed requests across all three
/// [AiRequestType] values (Phase 16) so PB-12/PB-13's filtering has
/// something to demonstrate against out of the box.
class MockAiRequestLogRepository implements AiRequestLogRepository {
  final List<AiRequestLog> _entries;

  /// Monotonic counter so two entries recorded in the same millisecond still
  /// get distinct ids, mirroring `MockAdminAuditLogRepository`'s
  /// `_logCounter` pattern.
  int _logCounter = 0;

  MockAiRequestLogRepository({List<AiRequestLog>? seed})
    : _entries = seed ?? defaultSeed();

  static List<AiRequestLog> defaultSeed() {
    final now = DateTime.now();
    DateTime minutesAgo(int minutes) =>
        now.subtract(Duration(minutes: minutes));

    return [
      AiRequestLog(
        logId: 'ai-seed-1',
        userId: 'user-101',
        requestType: AiRequestType.dailyAdvice,
        status: AiRequestStatus.succeeded,
        executionTimeMs: 1450,
        createdAt: minutesAgo(15),
      ),
      AiRequestLog(
        logId: 'ai-seed-2',
        userId: 'user-102',
        requestType: AiRequestType.foodDetection,
        status: AiRequestStatus.succeeded,
        executionTimeMs: 2100,
        createdAt: minutesAgo(40),
      ),
      AiRequestLog(
        logId: 'ai-seed-3',
        userId: 'user-103',
        requestType: AiRequestType.foodDetection,
        status: AiRequestStatus.failed,
        executionTimeMs: 800,
        errorMessage: 'RESOURCE_EXHAUSTED: quota exceeded for gemini-flash-latest.',
        createdAt: minutesAgo(90),
      ),
      AiRequestLog(
        logId: 'ai-seed-4',
        userId: 'user-105',
        requestType: AiRequestType.tripSummary,
        status: AiRequestStatus.succeeded,
        executionTimeMs: 3200,
        createdAt: minutesAgo(180),
      ),
      AiRequestLog(
        logId: 'ai-seed-5',
        userId: 'user-101',
        requestType: AiRequestType.tripSummary,
        status: AiRequestStatus.failed,
        executionTimeMs: 5000,
        errorMessage: 'Request timed out after 5000ms.',
        createdAt: minutesAgo(360),
      ),
      AiRequestLog(
        logId: 'ai-seed-6',
        userId: 'user-104',
        requestType: AiRequestType.dailyAdvice,
        status: AiRequestStatus.succeeded,
        executionTimeMs: 1100,
        createdAt: minutesAgo(500),
      ),
    ];
  }

  /// All recorded entries, exposed for tests to inspect state.
  List<AiRequestLog> get entries => List.unmodifiable(_entries);

  @override
  Future<void> recordRequest(AiRequestLog entry) async {
    _entries.add(entry);
  }

  @override
  Future<List<AiRequestLog>> getAllRequests({AiRequestStatus? status}) async {
    final matches = _entries.where((e) {
      if (status != null && e.status != status) return false;
      return true;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches;
  }

  @override
  Future<List<AiRequestLog>> getFailedRequests() {
    return getAllRequests(status: AiRequestStatus.failed);
  }

  /// Generates a unique log id for callers composing an [AiRequestLog]
  /// before calling [recordRequest] (the AI-locator logging decorators).
  String nextLogId() {
    _logCounter++;
    return 'ai-${DateTime.now().millisecondsSinceEpoch}-$_logCounter';
  }
}
