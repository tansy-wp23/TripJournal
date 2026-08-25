import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/admin_repository_locator.dart';
import '../../../data/ai_request_log_repository.dart';
import '../../../models/ai_request_log.dart';
import '../ai_request_retry.dart';

/// PB-13 (Monitor Failed AI Requests, Phase 18). Loads only
/// [AiRequestStatus.failed] entries via
/// [AiRequestLogRepository.getFailedRequests] and exposes a per-entry
/// [retry] action (Architecture Decision 10 — see `ai_request_retry.dart`'s
/// doc comment for exactly what "retry" does and doesn't reproduce).
/// Deliberately its own screen/controller, not a filtered view layered onto
/// `AiRequestMonitoringController` — see that controller's doc comment.
class FailedAiRequestsController extends ChangeNotifier {
  FailedAiRequestsController(this._repository);

  final AiRequestLogRepository _repository;

  List<AiRequestLog> _entries = [];
  bool _loading = false;
  String? _error;

  // Tracks which entries have a retry in flight, keyed by logId, so each
  // row can show its own spinner rather than one global loading state
  // disabling every retry button at once.
  final Set<String> _retryingLogIds = {};

  List<AiRequestLog> get entries => _entries;
  bool get loading => _loading;
  String? get error => _error;
  bool isRetrying(String logId) => _retryingLogIds.contains(logId);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _entries = await _repository.getFailedRequests();
    } catch (e) {
      _error = 'Could not load failed AI requests: $e';
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = false;
    notifyListeners();
  }

  /// Re-invokes the request's underlying AI service (see
  /// `ai_request_retry.dart`) and reloads afterward — whether the retry
  /// itself succeeded or failed, a new `AiRequestLog` entry now exists for
  /// it (recorded by the same `logged*Service` wrapper the original call
  /// used), so reloading is what surfaces that outcome; the original failed
  /// entry stays in this list either way, since the retry created a new
  /// entry rather than mutating the old one.
  Future<void> retry(AiRequestLog entry) async {
    if (_retryingLogIds.contains(entry.logId)) return;
    _retryingLogIds.add(entry.logId);
    notifyListeners();

    try {
      await retryAiRequest(entry.requestType);
    } catch (_) {
      // Already recorded as a new failed AiRequestLog entry by the logging
      // decorator — nothing further to surface here.
    }

    _retryingLogIds.remove(entry.logId);
    await load();
  }
}

/// The single place the app resolves its [FailedAiRequestsController] from
/// — mirrors `aiRequestMonitoringControllerProvider`.
final failedAiRequestsControllerProvider =
    ChangeNotifierProvider<FailedAiRequestsController>(
      (ref) => FailedAiRequestsController(aiRequestLogRepository),
    );
