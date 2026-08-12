import 'package:flutter/foundation.dart';

import '../../../data/admin_access_attempt_log_repository.dart';
import '../../../data/admin_audit_log_repository.dart';
import '../../../data/admin_user_directory_repository.dart';
import '../../../models/admin_access_attempt_log.dart';
import '../../../models/admin_audit_log.dart';
import '../../../models/profile.dart';

/// PB-03's detail half: loads one user's full [Profile] by id, plus their
/// [AdminAuditLog] history (status changes an admin has made) and
/// [AdminAccessAttemptLog] history (rejected admin sign-in attempts by this
/// account, if any — closes the follow-up flagged in `docs/admin/PROGRESS.md`'s
/// post-Phase-3 addition).
///
/// Deliberately **not** a global `ChangeNotifierProvider` like the other
/// admin controllers — this one is per-user, constructed fresh by
/// `AdminUserDetailScreen` for whichever `userId` it's showing, the same
/// way `TripViewScreen`/`EntryDetailScreen` look their subject up rather
/// than holding a shared singleton. A fresh `getUserById` fetch (rather
/// than reusing `AdminUserManagementController`'s already-fetched list) is
/// what lets Phase 5's suspend/reactivate actions call [load] again to
/// refresh this exact screen after mutating the account.
class AdminUserDetailController extends ChangeNotifier {
  AdminUserDetailController(
    this._directoryRepository,
    this._auditLogRepository,
    this._accessAttemptLogRepository,
  );

  final AdminUserDirectoryRepository _directoryRepository;
  final AdminAuditLogRepository _auditLogRepository;
  final AdminAccessAttemptLogRepository _accessAttemptLogRepository;

  Profile? _profile;
  List<AdminAuditLog> _auditHistory = [];
  List<AdminAccessAttemptLog> _accessAttempts = [];
  bool _loading = false;
  String? _error;

  Profile? get profile => _profile;
  List<AdminAuditLog> get auditHistory => _auditHistory;
  List<AdminAccessAttemptLog> get accessAttempts => _accessAttempts;
  bool get loading => _loading;
  String? get error => _error;

  /// Fetches (or re-fetches) [userId]'s profile and history. Safe to call
  /// again, e.g. from a retry button or after a Phase 5 suspend/reactivate
  /// action.
  Future<void> load(String userId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final profile = await _directoryRepository.getUserById(userId);
      _profile = profile;
      if (profile == null) {
        _error = 'No user found with id $userId.';
      } else {
        _auditHistory = await _auditLogRepository.getHistoryForTarget(
          targetType: AdminAuditTargetType.user,
          targetId: userId,
        );
        _accessAttempts = await _accessAttemptLogRepository.getAttemptsForUserId(userId);
      }
    } catch (e) {
      _error = 'Could not load this user: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
