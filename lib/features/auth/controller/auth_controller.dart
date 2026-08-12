import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/account_lifecycle_repository.dart';
import '../../../data/auth_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../data/user_management_repository_locator.dart';
import '../../../models/app_session.dart';
import '../../../models/profile.dart';

/// Controls the authentication flow: Google sign-in → create/fetch profile →
/// branch on status (active → authenticated; deactivated → reactivation).
///
/// Maps to the "Authentication Flow Component" and "Session Management"
/// components from Component.md. Listens to [AuthRepository.authStateChanges]
/// for session persistence (PB-08) so a signed-in user stays signed in
/// across navigation within the running app.
class AuthController extends ChangeNotifier {
  AuthController(
    this._authRepository,
    this._profileRepository,
    this._accountLifecycleRepository,
  ) {
    _sessionSubscription = _authRepository.authStateChanges().listen(_onAuthStateChanged);
  }

  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final AccountLifecycleRepository _accountLifecycleRepository;

  late StreamSubscription<AppSession> _sessionSubscription;

  AppSession? _session;
  Profile? _profile;
  bool _loading = false;
  String? _error;

  AppSession? get session => _session;
  Profile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;
  String? get currentUserId => _session?.userId;

  /// The current auth status, derived from [session] and [profile].
  ///
  /// Checks [Profile.isSuspended] before [Profile.isDeactivated] — an
  /// admin-imposed suspension (Admin Module) is a distinct status from a
  /// self-service deactivation and must not fall through to
  /// `AuthStatus.authenticated`. This was a real gap until now: nothing
  /// here ever consulted `isSuspended`, so a suspended profile signing in
  /// fresh (on any device, once a real shared backend exists — Phase 7)
  /// would have been treated as fully authenticated. Found and fixed
  /// 2026-08-12; see `docs/admin/PROGRESS.md`.
  AuthStatus get status {
    if (_loading) return AuthStatus.loading;
    if (_session == null || !_session!.isSignedIn) return AuthStatus.signedOut;
    final profile = _profile;
    if (profile == null) return AuthStatus.signedOut;
    if (profile.isSuspended) return AuthStatus.suspended;
    if (profile.isDeactivated) return AuthStatus.deactivated;
    return AuthStatus.authenticated;
  }

  /// The full sign-in flow (PB-01 through PB-05, PB-08):
  /// 1. Google sign-in via Supabase Auth (mocked).
  /// 2. Create profile if missing (PB-03, first-time account creation).
  /// 3. Branch on profile status (PB-04 active / PB-06 deactivated).
  ///    If deactivated, automatically send a reactivation code (PB-06).
  Future<void> signInWithGoogle() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final session = await _authRepository.signInWithGoogle();
      _session = session;

      // Fetch or create the profile (PB-03).
      final profile = await _profileRepository.createProfileIfMissing(
        userId: session.userId!,
        email: session.email!,
        displayName: _deriveDisplayName(session.email!),
      );
      _profile = profile;
      _error = null;

      // PB-06: if the account is deactivated, automatically send a
      // reactivation code so the user lands on the code-entry screen with
      // a code already on its way.
      if (profile.isDeactivated) {
        await _accountLifecycleRepository.requestReactivation();
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

  /// Signs the user out and clears all auth state. Used by the reactivation
  /// screen's cancel action (Architecture Decision 7 — don't leave a gated
  /// session hanging) and by the logout button (Phase 3).
  Future<void> signOut() async {
    await _authRepository.signOut();
    _session = null;
    _profile = null;
    _error = null;
    notifyListeners();
  }

  /// Sends a reactivation code to the user's email. Called automatically
  /// when a deactivated user signs in (PB-06) and on resend.
  Future<void> requestReactivation() async {
    await _accountLifecycleRepository.requestReactivation();
  }

  /// Confirms reactivation with [code]. On success, refreshes the profile
  /// (status becomes active) so the UI routes into the app.
  ///
  /// Throws [CodeValidationException] if the code is wrong or expired.
  Future<void> confirmReactivation(String code) async {
    await _accountLifecycleRepository.confirmReactivation(code);
    await onReactivated();
  }

  /// Sends a deactivation code to the user's email. Used by the
  /// deactivation flow (Phase 5).
  Future<void> requestDeactivation() async {
    await _accountLifecycleRepository.requestDeactivation();
  }

  /// Confirms deactivation with [code]. On success, signs the user out
  /// (PB-14 — ends the session) and returns to the login screen.
  ///
  /// Throws [CodeValidationException] if the code is wrong or expired.
  Future<void> confirmDeactivation(String code) async {
    await _accountLifecycleRepository.confirmDeactivation(code);
    await signOut();
  }

  /// Called when the user successfully reactivates — refreshes the local
  /// profile state so the UI can react (status becomes authenticated).
  Future<void> onReactivated() async {
    final userId = _session?.userId;
    if (userId == null) return;
    _profile = await _profileRepository.getProfile(userId);
    notifyListeners();
  }

  void _onAuthStateChanged(AppSession session) {
    // The stream fires on sign-in (already handled by signInWithGoogle) and
    // sign-out. Only act on sign-out here — sign-in is handled by
    // signInWithGoogle which also does the profile fetch.
    if (!session.isSignedIn) {
      _session = null;
      _profile = null;
      notifyListeners();
    }
  }

  String _deriveDisplayName(String email) {
    final localPart = email.split('@').first;
    return localPart
        .split(RegExp(r'[._-]'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join(' ');
  }

  @override
  void dispose() {
    _sessionSubscription.cancel();
    super.dispose();
  }
}

/// The high-level auth status the UI routes on. `suspended` (an
/// admin-imposed suspension) is distinct from `deactivated` (self-service)
/// — see [AuthController.status]'s doc comment.
enum AuthStatus { signedOut, loading, authenticated, deactivated, suspended }

/// The single place the app resolves its [AuthController] from — mirrors
/// `tripControllerProvider` / `journalControllerProvider`.
final authControllerProvider = ChangeNotifierProvider<AuthController>(
  (ref) => AuthController(
    authRepository,
    profileRepository,
    accountLifecycleRepository,
  ),
);