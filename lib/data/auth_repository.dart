import 'dart:async';

import '../models/app_session.dart';

/// Maps to the "Social Login" and "Session Management" components from
/// Component.md. These are thin wrappers over Supabase Auth rather than
/// owning their own storage — see `docs/user-management/PROGRESS.md`
/// Architecture Decisions 1–3.
///
/// Google is the only provider for now, but the interface stays
/// provider-agnostic (no hardcoded "Google" where a generic OAuth concept
/// will do).
abstract class AuthRepository {
  /// Initiates a Google sign-in. Completes with the resulting session.
  ///
  /// Throws [AuthException] on failure or cancellation (callers distinguish
  /// via [AuthException.kind]).
  Future<AppSession> signInWithGoogle();

  /// Signs the current user out and clears the local session.
  Future<void> signOut();

  /// Stream of auth state changes, mirroring Supabase's
  /// `onAuthStateChange`. Screens listen to this to keep navigation in sync
  /// with sign-in/sign-out.
  Stream<AppSession> authStateChanges();

  /// The currently signed-in user's id, or null if signed out.
  String? currentUserId();
}

/// Result of a failed sign-in attempt.
class AuthException implements Exception {
  final AuthExceptionKind kind;
  final String message;

  const AuthException(this.kind, this.message);

  @override
  String toString() => 'AuthException($kind): $message';
}

enum AuthExceptionKind { failure, cancelled }