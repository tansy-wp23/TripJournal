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
/// across navigation within the running app — including a session restored
/// from local storage on app start (e.g. after a hot restart), not just a
/// fresh interactive sign-in. See [_onAuthStateChanged]'s doc comment; this
/// was a real gap until 2026-08-16 — the controller previously only ever
/// populated _session/_profile from an explicit signInWithGoogle() call,
/// so a passively-restored session was never picked up and the app always
/// fell back to the login screen on restart.
class AuthController extends ChangeNotifier {
  AuthController(
    this._authRepository,
    this._profileRepository,
    this._accountLifecycleRepository,
  ) {
    _sessionSubscription = _authRepository.authStateChanges().listen(
      _onAuthStateChanged,
    );
  }

  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final AccountLifecycleRepository _accountLifecycleRepository;

  late StreamSubscription<AppSession> _sessionSubscription;

  AppSession? _session;
  Profile? _profile;

  // Starts true, not false: on app launch, Supabase hasn't finished
  // checking local storage for a persisted session yet. If this defaulted
  // to false, `status` below would read `_session == null` as a definitive
  // "signed out" and route to the login screen before restoration ever had
  // a chance to complete — appearing to "lose" a perfectly valid session on
  // every restart. _onAuthStateChanged is what eventually flips this back
  // to false, once the stream's first event (restored session or
  // confirmed-absent) actually arrives.
  bool _loading = true;
  String? _error;
  int _authOperationVersion = 0;
  Future<void>? _activeInteractiveSignIn;
  int? _interactiveSignInOperationVersion;
  int _signOutsInProgress = 0;
  bool _failedSignOutRestorationFence = false;

  AppSession? get session => _session;
  Profile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;
  String? get currentUserId => _session?.userId;

  /// The current auth status, derived from [session] and [profile].
  ///
  /// Checks [Profile.role] before anything else — `docs/admin/PROGRESS.md`'s
  /// confirmed identity-model decision (2026-08-12) says an admin profile is
  /// always a *dedicated* account, never one that also signs in as a
  /// traveler, so `AuthGate`/`AdminGate` are supposed to be "two
  /// independent, non-overlapping entry points" by construction. That was
  /// never actually enforced here, though: nothing in this getter looked at
  /// `role` at all, so a `role == admin` profile that *did* reach this
  /// controller (e.g. an existing traveler account promoted to admin
  /// in-place, rather than a fresh dedicated account) fell straight through
  /// to `authenticated` — silently letting one sign-in resolve to both
  /// sides. Found and fixed 2026-08-26. Checked ahead of
  /// suspended/deactivated/onboarding, not after: this is a categorical
  /// redirect off the traveler side entirely, not a traveler-specific
  /// account state, so it should win regardless of what the profile's other
  /// fields say.
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
    if (profile.role == UserRole.admin) return AuthStatus.adminAccount;
    if (profile.isSuspended) return AuthStatus.suspended;
    if (profile.isDeactivated) return AuthStatus.deactivated;
    // Checked after suspended/deactivated (an admin-imposed or self-service
    // gate always wins over onboarding) but still before authenticated — a
    // freshly-created profile (`profileCompleted == false`) sees the
    // onboarding screen instead of the home screen exactly once. Skipping
    // still sets the flag (`ProfileController.skipOnboarding`), so this is
    // not re-checked on every subsequent login.
    if (!profile.profileCompleted) return AuthStatus.needsOnboarding;
    return AuthStatus.authenticated;
  }

  /// The full sign-in flow (PB-01 through PB-05, PB-08):
  /// 1. Google sign-in via Supabase Auth (mocked).
  /// 2. Create profile if missing (PB-03, first-time account creation).
  /// 3. Branch on profile status (PB-04 active / PB-06 deactivated).
  ///    If deactivated, automatically send a reactivation code (PB-06).
  Future<void> signInWithGoogle() {
    final operationVersion = ++_authOperationVersion;
    _failedSignOutRestorationFence = false;
    _interactiveSignInOperationVersion = operationVersion;
    late final Future<void> operation;
    operation = _performSignInWithGoogle(operationVersion).whenComplete(() {
      if (_interactiveSignInOperationVersion == operationVersion) {
        _interactiveSignInOperationVersion = null;
      }
      if (identical(_activeInteractiveSignIn, operation)) {
        _activeInteractiveSignIn = null;
      }
    });
    _activeInteractiveSignIn = operation;
    return operation;
  }

  Future<void> _performSignInWithGoogle(int operationVersion) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final session = await _authRepository.signInWithGoogle();
      if (!_ownsAuthOperation(operationVersion)) return;
      _session = session;

      // Fetch or create the profile (PB-03).
      final profile = await _profileRepository.createProfileIfMissing(
        userId: session.userId!,
        email: session.email!,
        displayName: _deriveDisplayName(session.email!),
      );
      if (!_ownsAuthOperation(operationVersion)) return;
      _profile = profile;
      _error = null;

      // PB-06: if the account is deactivated, automatically send a
      // reactivation code so the user lands on the code-entry screen with
      // a code already on its way.
      if (profile.isDeactivated) {
        await _accountLifecycleRepository.requestReactivation();
      }
    } on AuthException catch (e) {
      if (!_ownsAuthOperation(operationVersion)) return;
      _error = e.kind == AuthExceptionKind.cancelled
          ? 'Sign-in cancelled.'
          : 'Sign-in failed: ${e.message}';
    } catch (e) {
      if (!_ownsAuthOperation(operationVersion)) return;
      _error = 'An unexpected error occurred: $e';
    } finally {
      if (_ownsAuthOperation(operationVersion)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Signs the user out and clears all auth state. Used by the reactivation
  /// screen's cancel action (Architecture Decision 7 — don't leave a gated
  /// session hanging) and by the logout button (Phase 3).
  Future<void> signOut() async {
    final interactiveSignIn = _activeInteractiveSignIn;
    // Invalidate any profile restore already awaiting the repository. This
    // is deliberately silent: publishing a loading state here would make
    // AuthGate replace the current screen with the launch splash on logout.
    _authOperationVersion++;
    _signOutsInProgress++;
    _failedSignOutRestorationFence = true;
    _error = null;
    var repositorySignOutSucceeded = false;
    try {
      // If Google sign-in has already started, let its repository operation
      // settle before signing the resulting remote session out. Its controller
      // writes are already invalidated by the version/count changes above.
      if (interactiveSignIn != null) {
        try {
          await interactiveSignIn;
        } catch (_) {
          // Sign-out must still reach the repository after a sign-in failure.
        }
      }
      await _authRepository.signOut();
      repositorySignOutSucceeded = true;
    } finally {
      if (repositorySignOutSucceeded) {
        _failedSignOutRestorationFence = false;
      }
      _session = null;
      _profile = null;
      _loading = false;
      _signOutsInProgress--;
      notifyListeners();
    }
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

  /// Sends a permanent-deletion code to the user's email. Used by the
  /// deletion flow (Phase 9).
  Future<void> requestDeletion() async {
    await _accountLifecycleRepository.requestDeletion();
  }

  /// Confirms permanent account deletion with [code]. On success, explicitly
  /// clears local app state and signs out — the local Supabase session now
  /// points at a user that no longer exists, so don't rely on some later API
  /// call failing naturally to catch this; reset proactively and route to
  /// login (Phase 9).
  ///
  /// Throws [CodeValidationException] if the code is wrong or expired.
  Future<void> deleteAccount(String code) async {
    await _accountLifecycleRepository.deleteAccount(code);
    await signOut();
  }

  /// Called when the user successfully reactivates — refreshes the local
  /// profile state so the UI can react (status becomes authenticated).
  Future<void> onReactivated() => refreshProfile();

  /// Re-fetches the current user's profile from the repository and
  /// republishes it. Needed whenever something outside this controller
  /// changes the profile row — [ProfileController] finishing or skipping
  /// onboarding is the motivating case: it saves through its own
  /// [ProfileRepository] call, not through this controller, so
  /// [AuthController]'s cached `_profile` (and therefore [status]) would
  /// otherwise stay stuck on [AuthStatus.needsOnboarding] until the next
  /// full sign-in.
  Future<void> refreshProfile() async {
    final userId = _session?.userId;
    if (userId == null) return;
    _profile = await _profileRepository.getProfile(userId);
    notifyListeners();
  }

  /// Handles every emission from [AuthRepository.authStateChanges] —
  /// crucially including the *first* one, which is how a session restored
  /// from local storage on app launch (e.g. after a hot restart) is ever
  /// discovered. [signInWithGoogle] populates _session/_profile itself for
  /// an interactive sign-in, but that method is never called for a passive
  /// restore — this listener is the only code path that runs in that case,
  /// so it has to do the same profile fetch [signInWithGoogle] does, not
  /// just react to sign-out.
  ///
  /// Supabase also emits a stream event for an interactive sign-in. The
  /// interactive operation exclusively owns that matching event until its
  /// profile and any reactivation-code setup finish; passive events outside
  /// an interactive operation continue to restore sessions here.
  Future<void> _onAuthStateChanged(AppSession session) async {
    if (!session.isSignedIn) {
      _authOperationVersion++;
      _failedSignOutRestorationFence = false;
      _session = null;
      _profile = null;
      _loading = false;
      notifyListeners();
      return;
    }

    // Callback start time does not establish causality. Reject events while a
    // later sign-out owns the transition, and reject delayed events whose
    // session no longer matches the repository's current auth state.
    if (_signOutsInProgress > 0 ||
        _failedSignOutRestorationFence ||
        _authRepository.currentUserId() != session.userId) {
      return;
    }

    // The interactive flow owns its matching provider event from start to
    // finish. Letting the stream path consume it would duplicate profile
    // creation and could publish before reactivation-code delivery completes.
    if (_interactiveSignInOperationVersion != null) return;
    final operationVersion = _authOperationVersion;

    if (_session?.userId == session.userId && _profile != null) {
      // Already populated (almost certainly by signInWithGoogle) — just
      // make sure we're not still showing the splash.
      _loading = false;
      notifyListeners();
      return;
    }

    _session = session;
    var shouldPublishCompletion = false;
    try {
      final profile = await _profileRepository.createProfileIfMissing(
        userId: session.userId!,
        email: session.email!,
        displayName: _deriveDisplayName(session.email!),
      );
      if (!_ownsAuthOperation(operationVersion) ||
          _session?.userId != session.userId) {
        return;
      }
      _profile = profile;
      _error = null;
      shouldPublishCompletion = true;
    } catch (e) {
      if (!_ownsAuthOperation(operationVersion) ||
          _session?.userId != session.userId) {
        return;
      }
      // Couldn't restore the profile for an otherwise-valid session —
      // treat as signed out rather than getting stuck on the splash
      // screen indefinitely.
      _error = 'Failed to restore session: $e';
      _session = null;
      _profile = null;
      shouldPublishCompletion = true;
    } finally {
      if (shouldPublishCompletion && _ownsAuthOperation(operationVersion)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  bool _ownsAuthOperation(int operationVersion) {
    return operationVersion == _authOperationVersion &&
        _signOutsInProgress == 0;
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
/// — see [AuthController.status]'s doc comment. `needsOnboarding` is a
/// genuinely new profile (`Profile.profileCompleted == false`) that hasn't
/// seen the Profile Onboarding screen yet. `adminAccount` is a
/// `role == admin` profile — the traveler side (`AuthGate`) refuses to
/// treat it as a normal signed-in user; see [AuthController.status]'s doc
/// comment and `AdminAccountScreen`.
enum AuthStatus {
  signedOut,
  loading,
  authenticated,
  deactivated,
  suspended,
  needsOnboarding,
  adminAccount,
}

/// The single place the app resolves its [AuthController] from — mirrors
/// `tripControllerProvider` / `journalControllerProvider`.
final authControllerProvider = ChangeNotifierProvider<AuthController>(
  (ref) => AuthController(
    authRepository,
    profileRepository,
    accountLifecycleRepository,
  ),
);
