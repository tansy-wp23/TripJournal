import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_request_log.dart';
import 'admin_repository_locator.dart';

/// Shared recording helper for the Sprint 3 AI-request logging decorators
/// (Phase 18, `docs/admin/PROGRESS.md`, Architecture Decision 9) —
/// `daily_advice_locator.dart`, `food_detection_locator.dart`, and
/// `trip_summary_locator.dart` each define their own small wrapper class
/// (one per service interface, per Phase 15's recon — none of the three
/// share a common method signature to wrap generically), but all three
/// funnel through this one function so the id-generation,
/// user-resolution, and fire-and-forget-write logic isn't tripled three
/// times over.
void recordAiRequest({
  required AiRequestType requestType,
  required AiRequestStatus status,
  required int executionTimeMs,
  String? errorMessage,
}) {
  final entry = AiRequestLog(
    logId: const Uuid().v4(),
    userId: _currentUserId(),
    requestType: requestType,
    status: status,
    executionTimeMs: executionTimeMs,
    errorMessage: errorMessage,
    createdAt: DateTime.now(),
  );
  // Fire-and-forget, best-effort — mirrors `error_reporting.dart`'s
  // `reportSystemError`: a logging failure must never surface as a failure
  // of the AI call it's merely observing.
  //
  // Wrapped in its own synchronous try/catch, not just `.catchError` on the
  // resulting Future — `aiRequestLogRepository` is a lazy getter (Phase 21:
  // real Supabase-backed), so simply *resolving* it can throw synchronously
  // (e.g. `Supabase.instance` accessed before `Supabase.initialize()`, the
  // state every widget test runs in). A throw there happens before
  // `.recordRequest(...)` is even called, so `.catchError` never gets a
  // Future to attach to — this bit the three `_Logging*Service` wrappers'
  // callers as soon as this repository stopped being mock-backed: a
  // *successful* AI call was getting misreported as failed, because the
  // synchronous throw from this line landed back in the wrapper's own
  // `try` block, not swallowed here as intended.
  try {
    unawaited(aiRequestLogRepository.recordRequest(entry).catchError((_) {}));
  } catch (_) {
    // ignore — a logging failure, sync or async, must never propagate
  }
}

/// The signed-in user's id, or `'unknown'` when Supabase Auth hasn't been
/// initialized (e.g. a widget test exercising a decorator directly, which
/// never calls `Supabase.initialize()`) or nobody is signed in. A
/// monitoring log entry is still useful without a resolved user, so this
/// never throws — mirrors the defensive best-effort style used everywhere
/// else in this module's logging code.
String _currentUserId() {
  try {
    return Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
  } catch (_) {
    return 'unknown';
  }
}
