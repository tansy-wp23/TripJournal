import 'dart:async';

import 'package:uuid/uuid.dart';

import 'data/admin_repository_locator.dart';
import 'data/system_error_log_repository.dart';
import 'models/system_error_log.dart';

/// The admin module's global error hook (Architecture Decision 9,
/// `docs/admin/PROGRESS.md` Phase 17) — records every unhandled error to
/// [systemErrorLogRepository] instead of scattering try/catch blocks
/// throughout the app. `main.dart` wires this into both
/// `FlutterError.onError` (framework/rendering errors) and
/// `runZonedGuarded`'s error callback (uncaught async errors that would
/// otherwise crash the isolate).
///
/// Extracted to its own top-level function, rather than an inline closure in
/// `main()`, specifically so a test can call it directly and assert against
/// [systemErrorLogRepository]/`AdminTestHarness` without needing to actually
/// crash something inside a running app.
///
/// `module` can't be determined generically at this level — a truly global
/// hook has no reliable way to know which feature raised a given error —
/// so every entry recorded this way uses `'app'`. Tagging the originating
/// feature module would need per-feature instrumentation, out of scope for
/// this phase's single global hook.
///
/// [repository] defaults to the real, shared [systemErrorLogRepository]
/// (Phase 21: Supabase-backed) — the optional override exists purely as a
/// test seam, so a test can inject a [MockSystemErrorLogRepository] and
/// assert against it directly, the way `error_reporting_test.dart` did
/// before Phase 21 made the default global genuinely live (and therefore
/// unsafe to touch from a plain test).
void reportSystemError(
  Object error,
  StackTrace? stackTrace, {
  ErrorSeverity severity = ErrorSeverity.fatal,
  SystemErrorLogRepository? repository,
}) {
  final entry = SystemErrorLog(
    logId: const Uuid().v4(),
    module: 'app',
    severity: severity,
    message: error.toString(),
    stackTrace: stackTrace?.toString(),
    createdAt: DateTime.now(),
  );
  // Fire-and-forget, best-effort — mirrors AdminAuthController's best-effort
  // write for rejected sign-in attempts: a logging failure must never take
  // down the error handler itself, which would defeat the point of it.
  //
  // Wrapped in its own synchronous try/catch, not just `.catchError` on the
  // resulting Future — `systemErrorLogRepository` is a lazy getter (Phase
  // 21: real Supabase-backed), so simply *resolving* it can throw
  // synchronously, before `.recordError(...)` is even called (so
  // `.catchError` never gets a Future to attach to). This matters more here
  // than anywhere else in the app: `main.dart` wires this function directly
  // into `FlutterError.onError`, *before* `Supabase.initialize()` runs — an
  // error during that early window would otherwise throw again from inside
  // the error handler itself.
  try {
    final repo = repository ?? systemErrorLogRepository;
    unawaited(repo.recordError(entry).catchError((_) {}));
  } catch (_) {
    // ignore — a logging failure, sync or async, must never propagate
  }
}
