import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../models/app_session.dart';
import 'auth_repository.dart';

/// Real [AuthRepository] backed by Supabase Auth + the native Google
/// Sign-In SDK.
///
/// Uses the **native ID-token flow** (Phase 7 of
/// `USER_MANAGEMENT_IMPLEMENTATION_PLAN.md`): call `GoogleSignIn().signIn()`
/// to get an idToken/accessToken directly from Google, then pass those to
/// `supabase.auth.signInWithIdToken(...)`. This avoids deep linking/redirect
/// handling entirely — do **not** use `signInWithOAuth()` for this app.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, {GoogleSignIn? googleSignIn})
    : _googleSignIn =
          googleSignIn ??
          GoogleSignIn(
            // The Web OAuth client ID (the same one registered with Supabase's
            // Google provider). Required on Android — without this, signIn()
            // returns an accessToken but idToken stays null.
            serverClientId: _webClientId,
            scopes: ['email', 'profile'],
          );

  /// Web OAuth client ID from Google Cloud Console (Manual Prerequisite A,
  /// step 5) — the same ID entered into Supabase's Google provider settings.
  /// This is a public identifier, not a secret, so it's fine to keep as a
  /// constant here rather than in an env var.
  static const _webClientId =
      '793492431727-e19624nf3gsm934p00cvai3u346ia6av.apps.googleusercontent.com';

  final SupabaseClient _client;
  final GoogleSignIn _googleSignIn;

  @override
  Future<AppSession> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthException(
          AuthExceptionKind.cancelled,
          'Google sign-in cancelled.',
        );
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw const AuthException(
          AuthExceptionKind.failure,
          'Google sign-in did not return an ID token. '
          'This may be due to: '
          '1. Google Sign-In not configured to request ID token, '
          '2. Using a deprecated API, or '
          '3. Platform-specific configuration needed.',
        );
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException(
          AuthExceptionKind.failure,
          'Supabase did not return a user after Google sign-in.',
        );
      }

      return AppSession.signedIn(userId: user.id, email: user.email ?? '');
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(AuthExceptionKind.failure, e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } finally {
      // Supabase owns the app session. Its remote/local cleanup must still run
      // when the optional Google SDK cleanup fails.
      await _client.auth.signOut();
    }
  }

  @override
  Stream<AppSession> authStateChanges() {
    return _client.auth.onAuthStateChange.map((data) {
      final session = data.session;
      if (session == null) {
        return const AppSession.signedOut();
      }
      return AppSession.signedIn(
        userId: session.user.id,
        email: session.user.email ?? '',
      );
    });
  }

  @override
  String? currentUserId() => _client.auth.currentUser?.id;
}
