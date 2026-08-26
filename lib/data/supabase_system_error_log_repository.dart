import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/system_error_log.dart';
import 'system_error_log_repository.dart';

/// Real [SystemErrorLogRepository] backed by the `system_error_logs` table
/// (Phase 21 of ADMIN_MODULE_IMPLEMENTATION_PLAN.md,
/// 202608260002_system_error_and_ai_request_logs.sql). Insert is
/// allowed for any signed-in caller (`to authenticated`, no ownership
/// check — the table has no user_id column at all, see the migration's own
/// comment for why); reads are `is_admin_user()`-scoped.
class SupabaseSystemErrorLogRepository implements SystemErrorLogRepository {
  SupabaseSystemErrorLogRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> recordError(SystemErrorLog entry) async {
    await _client.from('system_error_logs').insert({
      'module': entry.module,
      'severity': entry.severity.name,
      'message': entry.message,
      'stack_trace': entry.stackTrace,
    });
  }

  @override
  Future<List<SystemErrorLog>> getAllErrors({
    String? module,
    ErrorSeverity? severity,
  }) async {
    var builder = _client.from('system_error_logs').select();
    if (module != null) {
      builder = builder.eq('module', module);
    }
    if (severity != null) {
      builder = builder.eq('severity', severity.name);
    }
    final rows = await builder.order('created_at', ascending: false);
    return rows.map(_fromRow).toList();
  }

  SystemErrorLog _fromRow(Map<String, dynamic> row) {
    return SystemErrorLog(
      logId: row['log_id'] as String,
      module: row['module'] as String,
      severity: ErrorSeverity.values.firstWhere((s) => s.name == row['severity']),
      message: row['message'] as String,
      stackTrace: row['stack_trace'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
