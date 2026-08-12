import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/admin_access_attempt_log_repository.dart';
import '../../../data/admin_dashboard_repository.dart';
import '../../../data/admin_repository_locator.dart';
import '../../../models/admin_access_attempt_log.dart';
import '../../../models/admin_dashboard_stats.dart';

/// Loads [AdminDashboardStats] for PB-02 (View Admin Dashboard), exposing
/// loading/error/data states — mirrors `TripController`'s plain
/// `ChangeNotifier` + manual loading/error flags convention rather than an
/// `AsyncNotifier`, for consistency with the rest of the app.
///
/// Also loads the most recent [AdminAccessAttemptLog] entries (team
/// decision, 2026-08-12 — `docs/admin/PROGRESS.md`) so a rejected admin
/// sign-in attempt is actually visible to an admin, not just recorded.
/// Folded into the same load/loading/error cycle as the stats rather than
/// a second controller, since both are "load the dashboard" data fetched
/// at the same moment.
class AdminDashboardController extends ChangeNotifier {
  AdminDashboardController(this._dashboardRepository, this._accessAttemptLogRepository);

  final AdminDashboardRepository _dashboardRepository;
  final AdminAccessAttemptLogRepository _accessAttemptLogRepository;

  static const int _recentAttemptsLimit = 10;

  AdminDashboardStats? _stats;
  List<AdminAccessAttemptLog> _recentAttempts = [];
  bool _loading = false;
  String? _error;

  AdminDashboardStats? get stats => _stats;
  List<AdminAccessAttemptLog> get recentAttempts => _recentAttempts;
  bool get loading => _loading;
  String? get error => _error;

  /// Fetches (or re-fetches) the dashboard stats and recent access-attempt
  /// log. Safe to call again after an error (e.g. from a retry button) —
  /// clears the prior error first.
  Future<void> loadStats() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _stats = await _dashboardRepository.getDashboardStats();
      _recentAttempts = await _accessAttemptLogRepository.getRecentAttempts(
        limit: _recentAttemptsLimit,
      );
    } catch (e) {
      _error = 'Could not load dashboard stats: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

/// The single place the app resolves its [AdminDashboardController] from —
/// mirrors `adminAuthControllerProvider`.
final adminDashboardControllerProvider =
    ChangeNotifierProvider<AdminDashboardController>(
  (ref) => AdminDashboardController(
    adminDashboardRepository,
    adminAccessAttemptLogRepository,
  ),
);
