import '../models/ai_request_log.dart';

/// Maps to PB-12 (Monitor AI Processing Requests) and PB-13 (Monitor Failed
/// AI Requests), Sprint 3. Real implementation (Phase 21, later sprint):
/// `ai_request_logs` table, insert-only from the AI-locator logging
/// decorators, readable by `is_admin_user()` callers via RLS.
abstract class AiRequestLogRepository {
  /// Appends a request entry. Called by the logging decorator wrapping each
  /// AI locator (Architecture Decision 9), not directly by UI code.
  Future<void> recordRequest(AiRequestLog entry);

  /// All request entries, newest first, optionally narrowed by [status] —
  /// backs PB-12's "filter AI requests by status".
  Future<List<AiRequestLog>> getAllRequests({AiRequestStatus? status});

  /// Every entry with [AiRequestStatus.failed], newest first — backs
  /// PB-13's failed-requests view. Equivalent to `getAllRequests(status:
  /// AiRequestStatus.failed)`, exposed separately since PB-13 is its own
  /// backlog item with its own screen.
  Future<List<AiRequestLog>> getFailedRequests();
}
