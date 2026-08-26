import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/admin_repository_locator.dart';
import '../../../data/system_error_log_repository.dart';
import '../../../models/system_error_log.dart';

/// PB-11 (Monitor System Error Logs, Phase 17). Loads
/// [SystemErrorLog] entries via [SystemErrorLogRepository.getAllErrors],
/// exposing loading/error/data plus module/severity filters — mirrors
/// `AuditLogController`'s plain `ChangeNotifier` + manual loading/error
/// flags convention, for consistency with the rest of the admin feature.
class SystemErrorLogController extends ChangeNotifier {
  SystemErrorLogController(this._repository);

  final SystemErrorLogRepository _repository;

  List<SystemErrorLog> _entries = [];
  bool _loading = false;
  String? _error;

  String? _moduleFilter;
  ErrorSeverity? _severityFilter;

  // The set of modules seen in the entry log, for the module-filter
  // dropdown's choices. `getAllErrors` only ever returns the currently
  // filtered subset, so this is populated from one unfiltered fetch the
  // first time `load()` runs and then left alone — a module appearing only
  // after that first load (mock data doesn't grow that way) simply won't
  // show up as a filter option until the controller is recreated, an
  // acceptable trade-off for mock-data session lengths (mirrors
  // `AuditLogController`'s label-cache trade-off).
  List<String> _availableModules = [];

  List<SystemErrorLog> get entries => _entries;
  bool get loading => _loading;
  String? get error => _error;
  String? get moduleFilter => _moduleFilter;
  ErrorSeverity? get severityFilter => _severityFilter;
  List<String> get availableModules => _availableModules;
  bool get hasActiveFilter => _moduleFilter != null || _severityFilter != null;

  /// Loads (or reloads) entries, respecting the current filters. Safe to
  /// call again after an error (e.g. from a retry button) — clears the
  /// prior error first.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _entries = await _repository.getAllErrors(
        module: _moduleFilter,
        severity: _severityFilter,
      );
      if (_availableModules.isEmpty) {
        final all = (_moduleFilter == null && _severityFilter == null)
            ? _entries
            : await _repository.getAllErrors();
        _availableModules = all.map((e) => e.module).toSet().toList()..sort();
      }
    } catch (e) {
      _error = 'Could not load the system error log: $e';
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> setModuleFilter(String? module) {
    _moduleFilter = module;
    return load();
  }

  Future<void> setSeverityFilter(ErrorSeverity? severity) {
    _severityFilter = severity;
    return load();
  }

  Future<void> clearFilters() {
    _moduleFilter = null;
    _severityFilter = null;
    return load();
  }
}

/// The single place the app resolves its [SystemErrorLogController] from —
/// mirrors `auditLogControllerProvider`.
final systemErrorLogControllerProvider =
    ChangeNotifierProvider<SystemErrorLogController>(
      (ref) => SystemErrorLogController(systemErrorLogRepository),
    );
