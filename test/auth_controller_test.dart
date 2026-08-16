import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/account_lifecycle_repository.dart';
import 'package:tripjournal/data/mock_account_lifecycle_repository.dart';
import 'package:tripjournal/data/mock_auth_repository.dart';
import 'package:tripjournal/data/mock_profile_repository.dart';
import 'package:tripjournal/data/mock_verification_code_repository.dart';
import 'package:tripjournal/features/auth/controller/auth_controller.dart';
import 'package:tripjournal/models/app_session.dart';
import 'package:tripjournal/models/profile.dart';
import 'package:tripjournal/models/verification_code.dart';

void main() {
  late MockAuthRepository authRepository;
  late MockProfileRepository profileRepository;
  late MockVerificationCodeRepository verificationCodeRepository;
  late MockAccountLifecycleRepository lifecycleRepository;
  late AuthController controller;

  setUp(() {
    authRepository = MockAuthRepository();
    profileRepository = MockProfileRepository(state: MockProfileState.active);
    verificationCodeRepository = MockVerificationCodeRepository();
    lifecycleRepository = MockAccountLifecycleRepository(
      profileRepository: profileRepository,
      verificationCodeRepository: verificationCodeRepository,
    );
    controller = AuthController(
      authRepository,
      profileRepository,
      lifecycleRepository,
    );
  });

  tearDown(() => controller.dispose());

  group('AuthController', () {
    test(
      'disposed mock auth repository closes without late auth events',
      () async {
        final auth = MockAuthRepository();
        final events = <AppSession>[];
        final subscription = auth.authStateChanges().listen(events.add);
        final completed = subscription.asFuture<void>();

        await auth.signOut();
        await auth.dispose();
        await completed;

        expect(events, [const AppSession.signedOut()]);
      },
    );

    test('initial status is loading (waiting for session restoration)', () {
      expect(controller.status, AuthStatus.loading);
    });

    test('passively restored session routes to authenticated', () async {
      authRepository.emitSignedInSession();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(controller.loading, isFalse);
      expect(controller.status, AuthStatus.authenticated);
      expect(controller.profile, isNotNull);
      expect(controller.profile!.isActive, isTrue);
    });

    test(
      'passively restored session for a deactivated user routes to deactivated',
      () async {
        profileRepository = MockProfileRepository(
          state: MockProfileState.deactivated,
        );
        lifecycleRepository = MockAccountLifecycleRepository(
          profileRepository: profileRepository,
          verificationCodeRepository: verificationCodeRepository,
        );
        controller = AuthController(
          authRepository,
          profileRepository,
          lifecycleRepository,
        );

        authRepository.emitSignedInSession();
        await Future.delayed(const Duration(milliseconds: 10));

        expect(controller.loading, isFalse);
        expect(controller.status, AuthStatus.deactivated);
        expect(controller.profile!.isDeactivated, isTrue);
      },
    );

    test(
      'passively restored signed-out session (no persisted session) routes to signedOut',
      () async {
        authRepository.emitSignedOutSession();
        await Future.delayed(const Duration(milliseconds: 10));

        expect(controller.loading, isFalse);
        expect(controller.status, AuthStatus.signedOut);
        expect(controller.session, isNull);
        expect(controller.profile, isNull);
      },
    );

    test('successful sign-in sets status to authenticated', () async {
      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.authenticated);
      expect(controller.currentUserId, 'user-001');
      expect(controller.profile, isNotNull);
      expect(controller.profile!.isActive, isTrue);
    });

    test('first-time user gets a profile created on sign-in', () async {
      profileRepository = MockProfileRepository(
        state: MockProfileState.firstTime,
      );
      lifecycleRepository = MockAccountLifecycleRepository(
        profileRepository: profileRepository,
        verificationCodeRepository: verificationCodeRepository,
      );
      controller = AuthController(
        authRepository,
        profileRepository,
        lifecycleRepository,
      );

      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.authenticated);
      expect(controller.profile, isNotNull);
      expect(controller.profile!.userID, 'user-001');
    });

    test('deactivated user sets status to deactivated', () async {
      profileRepository = MockProfileRepository(
        state: MockProfileState.deactivated,
      );
      lifecycleRepository = MockAccountLifecycleRepository(
        profileRepository: profileRepository,
        verificationCodeRepository: verificationCodeRepository,
      );
      controller = AuthController(
        authRepository,
        profileRepository,
        lifecycleRepository,
      );

      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.deactivated);
      expect(controller.profile!.isDeactivated, isTrue);
    });

    // Admin Module fix (docs/admin/PROGRESS.md, 2026-08-12): `status` never
    // checked `isSuspended` at all, so a suspended profile fell through to
    // `authenticated`. `MockProfileRepository` has no `MockProfileState`
    // for `suspended` (owned by the User Management module — a seed value
    // was intentionally not added there just for this test); mutate an
    // already-seeded active profile directly instead.
    test(
      'a suspended profile sets status to suspended, not authenticated',
      () async {
        await controller.signInWithGoogle();
        expect(controller.status, AuthStatus.authenticated);

        await profileRepository.updateProfile(
          controller.profile!.copyWith(status: AccountStatus.suspended),
        );
        await controller.onReactivated(); // re-fetches the profile

        expect(controller.status, AuthStatus.suspended);
        expect(controller.profile!.isSuspended, isTrue);
      },
    );

    test('signing in as an already-suspended profile does not '
        'auto-request a reactivation code (unlike deactivated)', () async {
      final existing = (await profileRepository.getProfile('user-001'))!;
      await profileRepository.updateProfile(
        existing.copyWith(status: AccountStatus.suspended),
      );

      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.suspended);
      expect(verificationCodeRepository.activeCode, isNull);
    });

    test('failed sign-in sets error and stays signedOut', () async {
      authRepository = MockAuthRepository(result: MockAuthResult.failure);
      controller = AuthController(
        authRepository,
        profileRepository,
        lifecycleRepository,
      );

      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.signedOut);
      expect(controller.error, isNotNull);
      expect(controller.error!.contains('failed'), isTrue);
    });

    test(
      'cancelled sign-in sets a cancelled error and stays signedOut',
      () async {
        authRepository = MockAuthRepository(result: MockAuthResult.cancelled);
        controller = AuthController(
          authRepository,
          profileRepository,
          lifecycleRepository,
        );

        await controller.signInWithGoogle();

        expect(controller.status, AuthStatus.signedOut);
        expect(controller.error, 'Sign-in cancelled.');
      },
    );

    test('signOut clears session and profile', () async {
      await controller.signInWithGoogle();
      expect(controller.status, AuthStatus.authenticated);

      await controller.signOut();

      expect(controller.status, AuthStatus.signedOut);
      expect(controller.session, isNull);
      expect(controller.profile, isNull);
    });

    test('signOut during an auth-stream restore finishes signedOut', () async {
      controller.dispose();
      final eventAuthRepository = _SignOutBeforeEventAuthRepository();
      final deferredProfileRepository = _DeferredProfileRepository();
      authRepository = eventAuthRepository;
      profileRepository = deferredProfileRepository;
      lifecycleRepository = MockAccountLifecycleRepository(
        profileRepository: profileRepository,
        verificationCodeRepository: verificationCodeRepository,
      );
      controller = AuthController(
        authRepository,
        profileRepository,
        lifecycleRepository,
      );
      final states = <AuthStatus>[controller.status];
      controller.addListener(() => states.add(controller.status));

      eventAuthRepository.emitSignedInSession();
      await deferredProfileRepository.createStarted;

      await controller.signOut();

      expect(
        controller.status,
        AuthStatus.signedOut,
        reason: 'Observed auth states: $states',
      );

      deferredProfileRepository.releaseCreate();
      await Future<void>.delayed(Duration.zero);

      expect(controller.session, isNull);
      expect(controller.profile, isNull);

      eventAuthRepository.emitSignedOutSession();
      await Future<void>.delayed(Duration.zero);

      final firstSignedOut = states.indexOf(AuthStatus.signedOut);
      expect(firstSignedOut, isNonNegative);
      expect(states.skip(firstSignedOut), everyElement(AuthStatus.signedOut));
    });

    test(
      'pending signOut prevents an older auth restore from publishing',
      () async {
        controller.dispose();
        final eventAuthRepository = _SignOutBeforeEventAuthRepository(
          deferSignOut: true,
        );
        final deferredProfileRepository = _DeferredProfileRepository();
        authRepository = eventAuthRepository;
        profileRepository = deferredProfileRepository;
        lifecycleRepository = MockAccountLifecycleRepository(
          profileRepository: profileRepository,
          verificationCodeRepository: verificationCodeRepository,
        );
        controller = AuthController(
          authRepository,
          profileRepository,
          lifecycleRepository,
        );
        final states = <AuthStatus>[controller.status];
        controller.addListener(() => states.add(controller.status));

        eventAuthRepository.emitSignedInSession();
        await deferredProfileRepository.createStarted;

        final signOut = controller.signOut();
        await eventAuthRepository.signOutStarted;
        deferredProfileRepository.releaseCreate();
        await Future<void>.delayed(Duration.zero);

        expect(controller.status, AuthStatus.loading);
        expect(controller.profile, isNull);
        expect(states, everyElement(AuthStatus.loading));

        eventAuthRepository.releaseSignOut();
        await signOut;

        expect(controller.status, AuthStatus.signedOut);
        expect(controller.session, isNull);
        expect(controller.profile, isNull);
      },
    );

    test(
      'a new signIn prevents an older auth restore from clearing loading',
      () async {
        controller.dispose();
        final deferredAuthRepository = _DeferredSignInAuthRepository();
        final deferredProfileRepository = _DeferredProfileRepository();
        authRepository = deferredAuthRepository;
        profileRepository = deferredProfileRepository;
        lifecycleRepository = MockAccountLifecycleRepository(
          profileRepository: profileRepository,
          verificationCodeRepository: verificationCodeRepository,
        );
        controller = AuthController(
          authRepository,
          profileRepository,
          lifecycleRepository,
        );
        final states = <AuthStatus>[controller.status];
        controller.addListener(() => states.add(controller.status));

        deferredAuthRepository.emitSignedInSession();
        await deferredProfileRepository.createStarted;

        final signIn = controller.signInWithGoogle();
        await deferredAuthRepository.signInStarted;
        deferredProfileRepository.releaseCreate();
        await Future<void>.delayed(Duration.zero);

        expect(controller.status, AuthStatus.loading);
        expect(controller.profile, isNull);
        expect(states, everyElement(AuthStatus.loading));

        deferredAuthRepository.releaseSignIn();
        await signIn;
        await Future<void>.delayed(Duration.zero);

        expect(controller.status, AuthStatus.authenticated);
        expect(controller.profile, isNotNull);
      },
    );

    test(
      'failed signOut during an auth-stream restore still finishes signedOut',
      () async {
        controller.dispose();
        final eventAuthRepository = _SignOutBeforeEventAuthRepository(
          signOutError: StateError('remote sign-out failed'),
        );
        final deferredProfileRepository = _DeferredProfileRepository();
        authRepository = eventAuthRepository;
        profileRepository = deferredProfileRepository;
        lifecycleRepository = MockAccountLifecycleRepository(
          profileRepository: profileRepository,
          verificationCodeRepository: verificationCodeRepository,
        );
        controller = AuthController(
          authRepository,
          profileRepository,
          lifecycleRepository,
        );

        eventAuthRepository.emitSignedInSession();
        await deferredProfileRepository.createStarted;

        await expectLater(controller.signOut(), throwsStateError);

        expect(controller.status, AuthStatus.signedOut);
        expect(controller.session, isNull);
        expect(controller.profile, isNull);

        deferredProfileRepository.releaseCreate();
        await Future<void>.delayed(Duration.zero);

        expect(controller.session, isNull);
        expect(controller.profile, isNull);
      },
    );

    test('a queued signed-in event cannot override a later signOut', () async {
      controller.dispose();
      final queuedAuthRepository = _QueuedSignedInAuthRepository();
      authRepository = queuedAuthRepository;
      controller = AuthController(
        authRepository,
        profileRepository,
        lifecycleRepository,
      );

      queuedAuthRepository.emitSignedInSession();
      await controller.signOut();
      expect(controller.status, AuthStatus.signedOut);

      queuedAuthRepository.releaseSignedInEvent();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.status, AuthStatus.signedOut);
      expect(controller.session, isNull);
      expect(controller.profile, isNull);
    });

    test(
      'a legitimate signed-in stream event after signOut restores the session',
      () async {
        await controller.signOut();
        expect(controller.status, AuthStatus.signedOut);

        authRepository.emitSignedInSession();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(controller.status, AuthStatus.authenticated);
        expect(controller.session?.userId, authRepository.mockUserId);
        expect(controller.profile, isNotNull);
      },
    );

    test(
      'interactive signIn completion cannot override a later signOut',
      () async {
        controller.dispose();
        final deferredAuthRepository = _DeferredSignInAuthRepository();
        authRepository = deferredAuthRepository;
        controller = AuthController(
          authRepository,
          profileRepository,
          lifecycleRepository,
        );
        deferredAuthRepository.emitSignedOutSession();
        await Future<void>.delayed(Duration.zero);
        expect(controller.status, AuthStatus.signedOut);

        final signIn = controller.signInWithGoogle();
        await deferredAuthRepository.signInStarted;
        final signOut = controller.signOut();

        deferredAuthRepository.releaseSignIn();
        await signIn;
        await signOut;
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(controller.status, AuthStatus.signedOut);
        expect(controller.session, isNull);
        expect(controller.profile, isNull);
      },
    );

    test('loading is true during sign-in, false after', () async {
      final future = controller.signInWithGoogle();
      expect(controller.loading, isTrue);
      await future;
      expect(controller.loading, isFalse);
    });

    test(
      'deactivated sign-in automatically sends a reactivation code',
      () async {
        profileRepository = MockProfileRepository(
          state: MockProfileState.deactivated,
        );
        lifecycleRepository = MockAccountLifecycleRepository(
          profileRepository: profileRepository,
          verificationCodeRepository: verificationCodeRepository,
        );
        controller = AuthController(
          authRepository,
          profileRepository,
          lifecycleRepository,
        );

        await controller.signInWithGoogle();

        expect(controller.status, AuthStatus.deactivated);
        expect(
          verificationCodeRepository.activeCode?.purpose,
          VerificationPurpose.reactivation,
        );
      },
    );

    test(
      'confirmReactivation with valid code sets status to authenticated',
      () async {
        profileRepository = MockProfileRepository(
          state: MockProfileState.deactivated,
        );
        lifecycleRepository = MockAccountLifecycleRepository(
          profileRepository: profileRepository,
          verificationCodeRepository: verificationCodeRepository,
        );
        controller = AuthController(
          authRepository,
          profileRepository,
          lifecycleRepository,
        );

        await controller.signInWithGoogle();
        expect(controller.status, AuthStatus.deactivated);

        await controller.confirmReactivation(
          MockVerificationCodeRepository.mockCode,
        );

        expect(controller.status, AuthStatus.authenticated);
        expect(controller.profile!.isActive, isTrue);
      },
    );

    test(
      'confirmReactivation with wrong code throws and stays deactivated',
      () async {
        profileRepository = MockProfileRepository(
          state: MockProfileState.deactivated,
        );
        lifecycleRepository = MockAccountLifecycleRepository(
          profileRepository: profileRepository,
          verificationCodeRepository: verificationCodeRepository,
        );
        controller = AuthController(
          authRepository,
          profileRepository,
          lifecycleRepository,
        );

        await controller.signInWithGoogle();

        expect(
          () => controller.confirmReactivation('000000'),
          throwsA(isA<CodeValidationException>()),
        );
        expect(controller.status, AuthStatus.deactivated);
      },
    );

    test('requestReactivation sends a reactivation code', () async {
      await controller.requestReactivation();

      expect(
        verificationCodeRepository.activeCode?.purpose,
        VerificationPurpose.reactivation,
      );
    });

    test('confirmDeactivation with valid code signs out', () async {
      await controller.signInWithGoogle();
      expect(controller.status, AuthStatus.authenticated);

      await controller.requestDeactivation();
      await controller.confirmDeactivation(
        MockVerificationCodeRepository.mockCode,
      );

      expect(controller.status, AuthStatus.signedOut);
      expect(controller.session, isNull);
      expect(controller.profile, isNull);
    });

    test(
      'confirmDeactivation with wrong code throws and stays signed in',
      () async {
        await controller.signInWithGoogle();

        await controller.requestDeactivation();

        expect(
          () => controller.confirmDeactivation('000000'),
          throwsA(isA<CodeValidationException>()),
        );
        expect(controller.status, AuthStatus.authenticated);
      },
    );
  });
}

final class _SignOutBeforeEventAuthRepository extends MockAuthRepository {
  _SignOutBeforeEventAuthRepository({
    this.signOutError,
    this.deferSignOut = false,
  });

  final Object? signOutError;
  final bool deferSignOut;
  final Completer<void> _signOutStarted = Completer<void>();
  final Completer<void> _releaseSignOut = Completer<void>();

  Future<void> get signOutStarted => _signOutStarted.future;

  void releaseSignOut() => _releaseSignOut.complete();

  @override
  Future<void> signOut() async {
    if (!_signOutStarted.isCompleted) _signOutStarted.complete();
    if (deferSignOut) await _releaseSignOut.future;
    final error = signOutError;
    if (error != null) throw error;
  }
}

final class _DeferredProfileRepository extends MockProfileRepository {
  final Completer<void> _createStarted = Completer<void>();
  final Completer<void> _releaseCreate = Completer<void>();

  Future<void> get createStarted => _createStarted.future;

  void releaseCreate() => _releaseCreate.complete();

  @override
  Future<Profile> createProfileIfMissing({
    required String userId,
    required String email,
    required String displayName,
  }) async {
    if (!_createStarted.isCompleted) _createStarted.complete();
    await _releaseCreate.future;
    return super.createProfileIfMissing(
      userId: userId,
      email: email,
      displayName: displayName,
    );
  }
}

final class _DeferredSignInAuthRepository extends MockAuthRepository {
  final Completer<void> _signInStarted = Completer<void>();
  final Completer<void> _releaseSignIn = Completer<void>();

  Future<void> get signInStarted => _signInStarted.future;

  void releaseSignIn() => _releaseSignIn.complete();

  @override
  Future<AppSession> signInWithGoogle() async {
    if (!_signInStarted.isCompleted) _signInStarted.complete();
    await _releaseSignIn.future;
    return super.signInWithGoogle();
  }
}

final class _QueuedSignedInAuthRepository extends MockAuthRepository {
  final Completer<void> _releaseSignedInEvent = Completer<void>();
  String? _currentUserId;

  void releaseSignedInEvent() => _releaseSignedInEvent.complete();

  @override
  void emitSignedInSession({String? userId, String? email}) {
    _currentUserId = userId ?? mockUserId;
    super.emitSignedInSession(userId: userId, email: email);
  }

  @override
  Stream<AppSession> authStateChanges() {
    return super.authStateChanges().asyncMap((session) async {
      if (session.isSignedIn) await _releaseSignedInEvent.future;
      return session;
    });
  }

  @override
  Future<void> signOut() async {
    _currentUserId = null;
  }

  @override
  String? currentUserId() => _currentUserId;
}
