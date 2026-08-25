import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_request_log.dart';
import 'ai_request_log_repository.dart';

/// Real [AiRequestLogRepository] backed by the `ai_request_logs` table
/// (Phase 21 of ADMIN_MODULE_IMPLEMENTATION_PLAN.md,
/// 202608260002_admin_module_phase21_sprint3_real_backend.sql). Insert
/// requires `auth.uid()::text = user_id` — a caller can only record a
/// request attributed to themselves; reads are `is_admin_user()`-scoped.
class SupabaseAiRequestLogRepository implements AiRequestLogRepository {
  SupabaseAiRequestLogRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> recordRequest(AiRequestLog entry) async {
    await _client.from('ai_request_logs').insert({
      'user_id': entry.userId,
      'request_type': entry.requestType.name,
      'status': entry.status.name,
      'execution_time_ms': entry.executionTimeMs,
      'error_message': entry.errorMessage,
    });
  }

  @override
  Future<List<AiRequestLog>> getAllRequests({AiRequestStatus? status}) async {
    var builder = _client.from('ai_request_logs').select();
    if (status != null) {
      builder = builder.eq('status', status.name);
    }
    final rows = await builder.order('created_at', ascending: false);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<AiRequestLog>> getFailedRequests() {
    return getAllRequests(status: AiRequestStatus.failed);
  }

  AiRequestLog _fromRow(Map<String, dynamic> row) {
    return AiRequestLog(
      logId: row['log_id'] as String,
      userId: row['user_id'] as String,
      requestType: AiRequestType.values.firstWhere((t) => t.name == row['request_type']),
      status: AiRequestStatus.values.firstWhere((s) => s.name == row['status']),
      executionTimeMs: row['execution_time_ms'] as int,
      errorMessage: row['error_message'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
