import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import 'package:tripjournal/data/auth_repository.dart';
import 'package:tripjournal/data/mock_auth_repository.dart';
import 'package:tripjournal/data/supabase_auth_repository.dart';
import 'package:tripjournal/models/app_session.dart';

void main() {
  group('MockAuthRepository', () {
    test(
      'successful sign-in returns a signed-in session and emits on stream',
      () async {
        final repo = MockAuthRepository();
        final emitted = <AppSession>[];
        final sub = repo.authStateChanges().listen(emitted.add);

        final session = await repo.signInWithGoogle();

        expect(session.isSignedIn, isTrue);
        expect(session.userId, 'user-001');
        expect(session.email, 'sangyou@example.com');
        expect(repo.currentUserId(), 'user-001');
        expect(emitted.last.isSignedIn, isTrue);

        await sub.cancel();
      },
    );

    test('failure sign-in throws AuthException with kind failure', () async {
      final repo = MockAuthRepository(result: MockAuthResult.failure);

      expect(
        () => repo.signInWithGoogle(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.kind,
            'kind',
            AuthExceptionKind.failure,
          ),
        ),
      );
      expect(repo.currentUserId(), isNull);
    });

    test(
      'cancelled sign-in throws AuthException with kind cancelled',
      () async {
        final repo = MockAuthRepository(result: MockAuthResult.cancelled);

        expect(
          () => repo.signInWithGoogle(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.kind,
              'kind',
              AuthExceptionKind.cancelled,
            ),
          ),
        );
        expect(repo.currentUserId(), isNull);
      },
    );

    test('signOut clears the session and emits signed-out on stream', () async {
      final repo = MockAuthRepository();
      final emitted = <AppSession>[];
      final sub = repo.authStateChanges().listen(emitted.add);

      await repo.signInWithGoogle();
      await repo.signOut();

      expect(repo.currentUserId(), isNull);
      expect(emitted.last.isSignedIn, isFalse);

      await sub.cancel();
    });

    test('currentUserId is null before any sign-in', () {
      final repo = MockAuthRepository();
      expect(repo.currentUserId(), isNull);
    });
  });

  group('SupabaseAuthRepository', () {
    test('attempts Supabase cleanup when Google sign-out fails', () async {
      final googleError = StateError('Google sign-out failed');
      final googleSignIn = _ThrowingGoogleSignIn(googleError);
      final authClient = _RecordingGoTrueClient();
      final client = _FakeSupabaseClient(authClient);
      final repository = SupabaseAuthRepository(
        client,
        googleSignIn: googleSignIn,
      );
      addTearDown(authClient.dispose);

      await expectLater(repository.signOut(), throwsA(same(googleError)));

      expect(googleSignIn.signOutCallCount, 1);
      expect(authClient.signOutCallCount, 1);
    });
  });
}

final class _ThrowingGoogleSignIn extends GoogleSignIn {
  _ThrowingGoogleSignIn(this.error);

  final Object error;
  int signOutCallCount = 0;

  @override
  Future<GoogleSignInAccount?> signOut() async {
    signOutCallCount++;
    throw error;
  }
}

final class _RecordingGoTrueClient extends GoTrueClient {
  _RecordingGoTrueClient() : super(autoRefreshToken: false);

  int signOutCallCount = 0;

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    signOutCallCount++;
  }
}

final class _FakeSupabaseClient extends SupabaseClient {
  _FakeSupabaseClient(this.authClient)
    : super(
        'https://example.supabase.co',
        'anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

  final GoTrueClient authClient;

  @override
  GoTrueClient get auth => authClient;
}
