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

  /// Non-null exactly when [signInWithGoogle] just rejected a real,
  /// non-admin (or inactive-admin) account and has already signed it out —
  /// [AdminGate] consumes this via [consumePendingRejection] to pop itself
  /// and relay the message as a SnackBar on the traveler screen underneath.
  /// See that method's doc comment for why this exists.
  String? _pendingRejectionMessage;

  AppSession? get session => _session;
  Profile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasPendingRejection => _pendingRejectionMessage != null;

  /// One-shot read of [_pendingRejectionMessage] — clears it so a later
  /// rebuild of whatever consumes this doesn't pop/relay a second time.
  /// Throws if called with nothing pending; callers should guard with
  /// [hasPendingRejection] first (mirrors `Queue.removeFirst`'s contract).
  String consumePendingRejection() {
    final message = _pendingRejectionMessage;
    if (message == null) {
      throw StateError('consumePendingRejection() with no pending rejection');
    }
    _pendingRejectionMessage = null;
    return message;
  }

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
        await _rejectAndSignOut(
          session,
          'This Google account is not registered as an administrator.',
          profile == null
              ? AdminAccessAttemptReason.noProfileFound
              : AdminAccessAttemptReason.notAnAdmin,
        );
      } else if (!profile.isActive) {
        await _rejectAndSignOut(
          session,
          profile.isSuspended
              ? 'This administrator account has been suspended.'
              : 'This administrator account is not active.',
          AdminAccessAttemptReason.adminAccountNotActive,
        );
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

  /// Found and fixed 2026-08-26: a rejected admin attempt used to leave the
  /// real, non-admin account fully signed in (both the shared Supabase
  /// session and — since `AuthRepository` wraps a single shared
  /// `GoogleSignIn` instance — Google's own cached "currently selected
  /// account"). That second part broke the *next* attempt: `GoogleSignIn`
  /// generally reuses whichever account is already cached rather than
  /// showing the picker again, so trying to sign in with the real admin
  /// account right after a rejected one could silently re-select the same
  /// wrong account instead of letting you choose a different one. It could
  /// also read as "am I now logged into the wrong account?" on the
  /// traveler side once back-navigation was allowed to reach it (the
  /// previous fix, same date).
  ///
  /// So a rejection now: records the attempt (must happen *before* signing
  /// out — `admin_access_attempt_log_insert_own`'s RLS check needs
  /// `auth.uid()` to still be the rejected account), then fully signs out
  /// (clears both Google's cache and the Supabase session), then hands the
  /// message to [_pendingRejectionMessage] for [AdminGate] to relay after
  /// popping itself — rather than leaving the rejected account sitting
  /// there on `AdminLoginScreen` for the user to notice and back out of
  /// manually.
  Future<void> _rejectAndSignOut(
    AppSession session,
    String message,
    AdminAccessAttemptReason reason,
  ) async {
    _error = message;
    await _recordAttempt(session, reason);
    await _authRepository.signOut();
    _session = null;
    _profile = null;
    _pendingRejectionMessage = message;
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
