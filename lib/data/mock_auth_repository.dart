import 'dart:async';

import '../models/app_session.dart';
import 'auth_repository.dart';

/// In-memory fake of [AuthRepository] so UI work in Phases 2–5 never blocks
/// on a backend.
///
/// Simulates a Google sign-in with a configurable result
/// ([MockAuthResult.success] / [MockAuthResult.failure] /
/// [MockAuthResult.cancelled]) and exposes a fake [authStateChanges] stream
/// so screens react to sign-in/sign-out the same way they would with the
/// real Supabase stream.
class MockAuthRepository implements AuthRepository {
  /// Controls the outcome of the next [signInWithGoogle] call.
  MockAuthResult result;

  /// The user id / email used when a sign-in succeeds.
  String mockUserId;
  String mockEmail;

  AppSession? _current;
  final StreamController<AppSession> _controller =
      StreamController<AppSession>.broadcast();

  MockAuthRepository({
    this.result = MockAuthResult.success,
    this.mockUserId = 'user-001',
    this.mockEmail = 'sangyou@example.com',
  });

  @override
  Future<AppSession> signInWithGoogle() async {
    switch (result) {
      case MockAuthResult.failure:
        throw const AuthException(
          AuthExceptionKind.failure,
          'Google sign-in failed (mock).',
        );
      case MockAuthResult.cancelled:
        throw const AuthException(
          AuthExceptionKind.cancelled,
          'Google sign-in cancelled (mock).',
        );
      case MockAuthResult.success:
        final session = AppSession.signedIn(
          userId: mockUserId,
          email: mockEmail,
        );
        _current = session;
        _controller.add(session);
        return session;
    }
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(const AppSession.signedOut());
  }

  /// Simulates Supabase emitting a restored session on app start (e.g. after
  /// a hot restart or app relaunch) — the real `onAuthStateChange` stream
  /// fires once on subscribe with the current session from local storage.
  /// This mirrors that so the controller's passive-restore path can be tested.
  void emitSignedInSession({String? userId, String? email}) {
    final session = AppSession.signedIn(
      userId: userId ?? mockUserId,
      email: email ?? mockEmail,
    );
    _current = session;
    _controller.add(session);
  }

  /// Simulates Supabase confirming no persisted session exists on app start.
  void emitSignedOutSession() {
    _current = null;
    _controller.add(const AppSession.signedOut());
  }

  @override
  Stream<AppSession> authStateChanges() => _controller.stream;

  /// Releases the broadcast stream owned by this test double.
  Future<void> dispose() async {
    await _controller.close();
  }

  @override
  String? currentUserId() => _current?.userId;
}

/// Configurable outcome of a mock Google sign-in.
enum MockAuthResult { success, failure, cancelled }
