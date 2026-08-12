import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/admin_access_attempt_log_repository.dart';
import '../../../data/admin_repository_locator.dart';
import '../../../data/admin_user_directory_repository.dart';
import '../../../data/auth_repository.dart';
import '../../../models/admin_access_attempt_log.dart';
import '../../../models/app_session.dart';
import '../../../models/profile.dart';

/// Controls the admin authentication flow: Google sign-in → look up the
/// signed-in id's [Profile] → verify `role == UserRole.admin` (PB-01).
///
/// Mirrors `AuthController`, with one deliberate deviation from the plan's
/// literal wording — see the class-level note on the profile lookup below.
class AdminAuthController extends ChangeNotifier {
  AdminAuthController(
    this._authRepository,
    this._userDirectoryRepository,
    this._accessAttemptLogRepository,
  ) {
    _sessionSubscription =
        _authRepository.authStateChanges().listen(_onAuthStateChanged);
  }

  final AuthRepository _authRepository;

  /// Looks up the signed-in id's [Profile] via the admin module's own
  /// directory interface rather than the User Management module's
  /// single-caller `ProfileRepository.getProfile`.
  ///
  /// `ADMIN_MODULE_IMPLEMENTATION_PLAN.md`'s Architecture Decision 2 frames
  /// the role check as reading "the already-fetched profile" without
  /// mandating which repository fetches it. `ProfileRepository`/
  /// `MockProfileRepository` model a single fixed traveler persona
  /// (`user-001`, always `role: user`) with no way to seed a `role: admin`
  /// row — so a real admin sign-in could never succeed against that mock.
  /// `AdminUserDirectoryRepository.getUserById` already resolves against
  /// `MockAdminUserStore`, which does seed an `admin-001` / `role: admin`
  /// row, and is an interface this module already owns — no cross-module
  /// change to `profile_repository.dart` needed. Noted in
  /// `docs/admin/PROGRESS.md` Phase 2 per the plan's own instruction to
  /// document conflicts like this rather than silently resolve them.
  final AdminUserDirectoryRepository _userDirectoryRepository;

  /// Records rejected sign-in attempts (team decision, 2026-08-12 —
  /// `docs/admin/PROGRESS.md`): any non-admin attempt to reach the admin
  /// portal must be visible to admins, even though what to do about it
  /// (warning/penalty) isn't decided yet. Recording only, no enforcement.
  final AdminAccessAttemptLogRepository _accessAttemptLogRepository;

  late final StreamSubscription<AppSession> _sessionSubscription;

  AppSession? _session;
  Profile? _profile;
  bool _loading = false;
  String? _error;

  AppSession? get session => _session;
  Profile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;

  /// The current admin auth status, derived from [session] and [profile].
  AdminAuthStatus get status {
    if (_loading) return AdminAuthStatus.loading;
    if (_session == null || !_session!.isSignedIn) {
      return AdminAuthStatus.signedOut;
    }
    final profile = _profile;
    // Not an admin profile, or an admin profile that isn't active (e.g.
    // suspended by another admin) — either way, no dashboard access.
    if (profile == null || profile.role != UserRole.admin || !profile.isActive) {
      return AdminAuthStatus.unauthorized;
    }
    return AdminAuthStatus.authenticated;
  }

  /// PB-01: Google sign-in (mocked) → fetch the signed-in id's profile →
  /// verify the admin role. Does not auto-provision a profile the way the
  /// traveler flow's `createProfileIfMissing` does — an admin profile must
  /// already exist; this screen never creates one.
  Future<void> signInWithGoogle() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final session = await _authRepository.signInWithGoogle();
      _session = session;

      final profile = await _userDirectoryRepository.getUserById(session.userId!);
      _profile = profile;

      if (profile == null || profile.role != UserRole.admin) {
        _error = 'This Google account is not registered as an administrator.';
        await _recordAttempt(
          session,
          profile == null
              ? AdminAccessAttemptReason.noProfileFound
              : AdminAccessAttemptReason.notAnAdmin,
        );
      } else if (!profile.isActive) {
        _error = profile.isSuspended
            ? 'This administrator account has been suspended.'
            : 'This administrator account is not active.';
        await _recordAttempt(session, AdminAccessAttemptReason.adminAccountNotActive);
      } else {
        _error = null;
      }
    } on AuthException catch (e) {
      _error = e.kind == AuthExceptionKind.cancelled
          ? 'Sign-in cancelled.'
          : 'Sign-in failed: ${e.message}';
    } catch (e) {
      _error = 'An unexpected error occurred: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Best-effort write to [_accessAttemptLogRepository] — swallows its own
  /// failures (logged via [debugPrint]) rather than letting a logging
  /// problem override the more specific rejection message already set in
  /// [_error] via the outer `catch` in [signInWithGoogle].
  Future<void> _recordAttempt(AppSession session, AdminAccessAttemptReason reason) async {
    try {
      await _accessAttemptLogRepository.recordAttempt(
        AdminAccessAttemptLog(
          logId: 'attempt-${DateTime.now().microsecondsSinceEpoch}',
          attemptedUserId: session.userId!,
          attemptedEmail: session.email ?? 'unknown',
          reason: reason,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('AdminAuthController: failed to record access attempt: $e');
    }
  }

  /// Signs the admin out and clears all admin auth state (PB-10, Phase 6).
  Future<void> signOut() async {
    await _authRepository.signOut();
    _session = null;
    _profile = null;
    _error = null;
    notifyListeners();
  }

  void _onAuthStateChanged(AppSession session) {
    // Mirrors `AuthController._onAuthStateChanged` — only react to
    // sign-out here, since sign-in is already handled by signInWithGoogle
    // (which also does the profile lookup).
    if (!session.isSignedIn) {
      _session = null;
      _profile = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sessionSubscription.cancel();
    super.dispose();
  }
}

/// The high-level admin auth status the UI routes on. `unauthorized` covers
/// both "not an admin profile" and "admin profile but not active" — in both
/// cases the dashboard must not be reached (Phase 2 Definition of Done).
enum AdminAuthStatus { signedOut, loading, authenticated, unauthorized }

/// The single place the app resolves its [AdminAuthController] from —
/// mirrors `authControllerProvider`.
final adminAuthControllerProvider = ChangeNotifierProvider<AdminAuthController>(
  (ref) => AdminAuthController(
    adminAuthRepository,
    adminUserDirectoryRepository,
    adminAccessAttemptLogRepository,
  ),
);
