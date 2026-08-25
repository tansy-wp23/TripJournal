import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/admin_repository_locator.dart';
import '../../../data/ai_request_log_repository.dart';
import '../../../models/ai_request_log.dart';

/// PB-12 (Monitor AI Processing Requests, Phase 18). Loads [AiRequestLog]
/// entries via [AiRequestLogRepository.getAllRequests], exposing
/// loading/error/data plus a status filter — mirrors
/// `SystemErrorLogController`'s plain `ChangeNotifier` convention.
///
/// View-only — retrying a failed request is PB-13's job, deliberately kept
/// on its own screen/controller (`FailedAiRequestsController`) rather than
/// bolted onto this general view, matching the precedent already set by
/// `AiRequestLogRepository.getFailedRequests`'s own doc comment ("exposed
/// separately since PB-13 is its own backlog item with its own screen").
class AiRequestMonitoringController extends ChangeNotifier {
  AiRequestMonitoringController(this._repository);

  final AiRequestLogRepository _repository;

  List<AiRequestLog> _entries = [];
  bool _loading = false;
  String? _error;
  AiRequestStatus? _statusFilter;

  List<AiRequestLog> get entries => _entries;
  bool get loading => _loading;
  String? get error => _error;
  AiRequestStatus? get statusFilter => _statusFilter;
  bool get hasActiveFilter => _statusFilter != null;

  /// Loads (or reloads) entries, respecting the current filter. Safe to
  /// call again after an error (e.g. from a retry button) — clears the
  /// prior error first.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _entries = await _repository.getAllRequests(status: _statusFilter);
    } catch (e) {
      _error = 'Could not load AI request monitoring: $e';
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> setStatusFilter(AiRequestStatus? status) {
    _statusFilter = status;
    return load();
  }

  Future<void> clearFilters() {
    _statusFilter = null;
    return load();
  }
}

/// The single place the app resolves its [AiRequestMonitoringController]
/// from — mirrors `systemErrorLogControllerProvider`.
final aiRequestMonitoringControllerProvider =
    ChangeNotifierProvider<AiRequestMonitoringController>(
      (ref) => AiRequestMonitoringController(aiRequestLogRepository),
    );
