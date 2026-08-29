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
      'passively restored signed-out session (no persisted session) routes to guest',
      () async {
        authRepository.emitSignedOutSession();
        await Future.delayed(const Duration(milliseconds: 10));

        expect(controller.loading, isFalse);
        expect(controller.status, AuthStatus.guest);
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

    test(
      'first-time user gets a profile created on sign-in, routed to '
      'onboarding (Profile Onboarding feature)',
      () async {
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

        // Not authenticated yet — a genuinely new profile has
        // profileCompleted == false until onboarding is finished or
        // skipped (ProfileController.completeOnboarding / skipOnboarding).
        expect(controller.status, AuthStatus.needsOnboarding);
        expect(controller.profile, isNotNull);
        expect(controller.profile!.userID, 'user-001');
        expect(controller.profile!.profileCompleted, isFalse);
      },
    );

    test(
      'refreshProfile() re-fetches the profile and republishes status — '
      'the completeOnboarding/skipOnboarding -> AuthGate wiring',
      () async {
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
        expect(controller.status, AuthStatus.needsOnboarding);

        // Simulate what ProfileController.skipOnboarding does: write
        // straight through the repository, bypassing AuthController.
        final current = await profileRepository.getProfile('user-001');
        await profileRepository.updateProfile(
          current!.copyWith(profileCompleted: true),
        );

        // AuthController's cached profile is stale until told to refresh.
        expect(controller.status, AuthStatus.needsOnboarding);

        await controller.refreshProfile();

        expect(controller.status, AuthStatus.authenticated);
      },
    );

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

    // Found and fixed 2026-08-26 (see AuthController.status's doc comment):
    // `role` was never checked here at all, so a `role == admin` profile —
    // meant to be a dedicated account that never signs in on the traveler
    // side (docs/admin/PROGRESS.md's 2026-08-12 identity-model decision) —
    // fell straight through to `authenticated` if it ever reached this
    // controller, e.g. an existing traveler account promoted to admin in
    // place rather than a fresh dedicated account being created.
    test(
      'an admin-role profile sets status to adminAccount, not authenticated',
      () async {
        await controller.signInWithGoogle();
        expect(controller.status, AuthStatus.authenticated);

        await profileRepository.updateProfile(
          controller.profile!.copyWith(role: UserRole.admin),
        );
        await controller.onReactivated(); // re-fetches the profile

        expect(controller.status, AuthStatus.adminAccount);
        expect(controller.profile!.role, UserRole.admin);
      },
    );

    test('signing in as an already-admin profile goes straight to '
        'adminAccount, never authenticated', () async {
      final existing = (await profileRepository.getProfile('user-001'))!;
      await profileRepository.updateProfile(
        existing.copyWith(role: UserRole.admin),
      );

      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.adminAccount);
    });

    test(
      'adminAccount wins over suspended — the redirect off the traveler '
      'side is categorical, not just another traveler account state',
      () async {
        final existing = (await profileRepository.getProfile('user-001'))!;
        await profileRepository.updateProfile(
          existing.copyWith(
            role: UserRole.admin,
            status: AccountStatus.suspended,
          ),
        );

        await controller.signInWithGoogle();

        expect(controller.status, AuthStatus.adminAccount);
      },
    );

    group('Guest Mode (2026-08-27 redesign)', () {
      test(
        'a first-time launch (no persisted session) resolves to guest '
        'directly — no separate opt-in step',
        () async {
          authRepository.emitSignedOutSession();
          await Future.delayed(const Duration(milliseconds: 10));

          expect(controller.status, AuthStatus.guest);
          expect(controller.session, isNull);
          expect(controller.currentUserId, isNull);
        },
      );

      test(
        'signing in from guest lands on authenticated — a real session '
        'replaces the "no session" guest state',
        () async {
          authRepository.emitSignedOutSession();
          await Future.delayed(const Duration(milliseconds: 10));
          expect(controller.status, AuthStatus.guest);

          await controller.signInWithGoogle();

          expect(controller.status, AuthStatus.authenticated);
        },
      );

      test(
        'signing out returns to guest, not a distinct signed-out status — '
        'logging out lands back on browsing, not a login wall',
        () async {
          await controller.signInWithGoogle();
          expect(controller.status, AuthStatus.authenticated);

          await controller.signOut();

          expect(controller.status, AuthStatus.guest);
          expect(controller.session, isNull);
          expect(controller.profile, isNull);
        },
      );
    });

    test('failed sign-in sets error and stays on guest', () async {
      authRepository = MockAuthRepository(result: MockAuthResult.failure);
      controller = AuthController(
        authRepository,
        profileRepository,
        lifecycleRepository,
      );

      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.guest);
      expect(controller.error, isNotNull);
      expect(controller.error!.contains('failed'), isTrue);
    });

    test(
      'cancelled sign-in sets a cancelled error and stays on guest',
      () async {
        authRepository = MockAuthRepository(result: MockAuthResult.cancelled);
        controller = AuthController(
          authRepository,
          profileRepository,
          lifecycleRepository,
        );

        await controller.signInWithGoogle();

        expect(controller.status, AuthStatus.guest);
        expect(controller.error, 'Sign-in cancelled.');
      },
    );

    test(
      'profile creation failure shows a friendly message and falls back to guest',
      () async {
        profileRepository = _FailingCreateProfileRepository();
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

        expect(controller.status, AuthStatus.guest);
        expect(
          controller.error,
          "We couldn't finish setting up your account. Please try again.",
        );
        expect(controller.session, isNull);
        expect(controller.profile, isNull);
      },
    );

    test('signOut clears session and profile', () async {
      await controller.signInWithGoogle();
      expect(controller.status, AuthStatus.authenticated);

      await controller.signOut();

      expect(controller.status, AuthStatus.guest);
      expect(controller.session, isNull);
      expect(controller.profile, isNull);
    });

    test('signOut during an auth-stream restore finishes on guest', () async {
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
        AuthStatus.guest,
        reason: 'Observed auth states: $states',
      );

      deferredProfileRepository.releaseCreate();
      await Future<void>.delayed(Duration.zero);

      expect(controller.session, isNull);
      expect(controller.profile, isNull);

      eventAuthRepository.emitSignedOutSession();
      await Future<void>.delayed(Duration.zero);

      final firstSignedOut = states.indexOf(AuthStatus.guest);
      expect(firstSignedOut, isNonNegative);
      expect(states.skip(firstSignedOut), everyElement(AuthStatus.guest));
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

        expect(controller.status, AuthStatus.guest);
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
      'failed signOut during an auth-stream restore still finishes on guest',
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

        expect(controller.status, AuthStatus.guest);
        expect(controller.session, isNull);
        expect(controller.profile, isNull);

        deferredProfileRepository.releaseCreate();
        await Future<void>.delayed(Duration.zero);

        expect(controller.session, isNull);
        expect(controller.profile, isNull);
      },
    );

    test(
      'failed signOut fences a queued signed-in event until signed-out is observed',
      () async {
        controller.dispose();
        final signOutError = StateError('remote sign-out failed');
        final queuedAuthRepository = _QueuedSignedInAuthRepository(
          signOutError: signOutError,
        );
        final deferredProfileRepository = _DeferredCountingProfileRepository();
        authRepository = queuedAuthRepository;
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
        addTearDown(queuedAuthRepository.dispose);

        queuedAuthRepository.queueSignedInSession();
        await expectLater(controller.signOut(), throwsA(same(signOutError)));

        queuedAuthRepository.releaseSignedInEvent();
        final sessionAfterQueuedEvent = controller.session;
        final createsAfterQueuedEvent =
            deferredProfileRepository.createCallCount;

        deferredProfileRepository.releaseCreate();
        await Future<void>.delayed(Duration.zero);

        expect(sessionAfterQueuedEvent, isNull);
        expect(createsAfterQueuedEvent, 0);
        expect(controller.status, AuthStatus.guest);

        final restored = Completer<void>();
        controller.addListener(() {
          if (controller.status == AuthStatus.authenticated &&
              !restored.isCompleted) {
            restored.complete();
          }
        });
        queuedAuthRepository.emitSignedOutSession();
        queuedAuthRepository.emitSignedInSessionNow();
        await restored.future;

        expect(controller.status, AuthStatus.authenticated);
      },
    );

    test(
      'a deliberate interactive sign-in clears a failed signOut fence',
      () async {
        controller.dispose();
        final queuedAuthRepository = _QueuedSignedInAuthRepository(
          signOutError: StateError('remote sign-out failed'),
        );
        authRepository = queuedAuthRepository;
        controller = AuthController(
          authRepository,
          profileRepository,
          lifecycleRepository,
        );
        addTearDown(queuedAuthRepository.dispose);

        await expectLater(controller.signOut(), throwsStateError);

        final signIn = controller.signInWithGoogle();
        queuedAuthRepository.releaseSignedInEvent();
        await signIn;

        expect(controller.status, AuthStatus.authenticated);
        expect(controller.currentUserId, queuedAuthRepository.mockUserId);
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
      expect(controller.status, AuthStatus.guest);

      queuedAuthRepository.releaseSignedInEvent();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.status, AuthStatus.guest);
      expect(controller.session, isNull);
      expect(controller.profile, isNull);
    });

    test(
      'a legitimate signed-in stream event after signOut restores the session',
      () async {
        await controller.signOut();
        expect(controller.status, AuthStatus.guest);

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
        expect(controller.status, AuthStatus.guest);

        final signIn = controller.signInWithGoogle();
        await deferredAuthRepository.signInStarted;
        final signOut = controller.signOut();

        deferredAuthRepository.releaseSignIn();
        await signIn;
        await signOut;
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(controller.status, AuthStatus.guest);
        expect(controller.session, isNull);
        expect(controller.profile, isNull);
      },
    );

    test(
      'matching interactive auth event does not duplicate profile creation',
      () async {
        controller.dispose();
        final queuedAuthRepository = _QueuedSignedInAuthRepository();
        final deferredProfileRepository = _DeferredCountingProfileRepository();
        authRepository = queuedAuthRepository;
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
        addTearDown(queuedAuthRepository.dispose);

        final signIn = controller.signInWithGoogle();
        await deferredProfileRepository.createStarted;

        queuedAuthRepository.releaseSignedInEvent();
        final createCallsWhilePending =
            deferredProfileRepository.createCallCount;
        final statusWhilePending = controller.status;

        deferredProfileRepository.releaseCreate();
        await signIn;
        await Future<void>.delayed(Duration.zero);

        expect(createCallsWhilePending, 1);
        expect(statusWhilePending, AuthStatus.loading);
        expect(controller.status, AuthStatus.authenticated);
      },
    );

    test(
      'matching auth event cannot publish before interactive reactivation setup',
      () async {
        controller.dispose();
        final queuedAuthRepository = _QueuedSignedInAuthRepository();
        final countingProfileRepository = _CountingProfileRepository(
          state: MockProfileState.deactivated,
        );
        final deferredLifecycleRepository =
            _DeferredReactivationLifecycleRepository(
              profileRepository: countingProfileRepository,
              verificationCodeRepository: verificationCodeRepository,
            );
        authRepository = queuedAuthRepository;
        profileRepository = countingProfileRepository;
        lifecycleRepository = deferredLifecycleRepository;
        controller = AuthController(
          authRepository,
          profileRepository,
          lifecycleRepository,
        );
        addTearDown(queuedAuthRepository.dispose);

        final signIn = controller.signInWithGoogle();
        await deferredLifecycleRepository.reactivationStarted;

        queuedAuthRepository.releaseSignedInEvent();
        final statusWhileCodeDeliveryIsPending = controller.status;

        deferredLifecycleRepository.releaseReactivation();
        await signIn;

        expect(statusWhileCodeDeliveryIsPending, AuthStatus.loading);
        expect(countingProfileRepository.createCallCount, 1);
        expect(controller.status, AuthStatus.deactivated);
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

      expect(controller.status, AuthStatus.guest);
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

    // Phase 9 — Account Deletion (Permanent).
    test('requestDeletion sends a deletion code', () async {
      await controller.requestDeletion();

      expect(
        verificationCodeRepository.activeCode?.purpose,
        VerificationPurpose.deletion,
      );
    });

    test('deleteAccount with valid code signs out', () async {
      await controller.signInWithGoogle();
      expect(controller.status, AuthStatus.authenticated);

      await controller.requestDeletion();
      await controller.deleteAccount(MockVerificationCodeRepository.mockCode);

      expect(controller.status, AuthStatus.guest);
      expect(controller.session, isNull);
      expect(controller.profile, isNull);
    });

    test(
      'deleteAccount with wrong code throws and stays signed in',
      () async {
        await controller.signInWithGoogle();

        await controller.requestDeletion();

        expect(
          () => controller.deleteAccount('000000'),
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

class _CountingProfileRepository extends MockProfileRepository {
  _CountingProfileRepository({super.state});

  int createCallCount = 0;

  @override
  Future<Profile> createProfileIfMissing({
    required String userId,
    required String email,
    required String displayName,
  }) async {
    createCallCount++;
    return createWithoutCounting(
      userId: userId,
      email: email,
      displayName: displayName,
    );
  }

  Future<Profile> createWithoutCounting({
    required String userId,
    required String email,
    required String displayName,
  }) {
    return super.createProfileIfMissing(
      userId: userId,
      email: email,
      displayName: displayName,
    );
  }
}

final class _FailingCreateProfileRepository extends MockProfileRepository {
  @override
  Future<Profile> createProfileIfMissing({
    required String userId,
    required String email,
    required String displayName,
  }) {
    // Simulates the real SupabaseProfileRepository throwing (e.g. RLS
    // rejection, constraint violation, network) when the profile row can't be
    // created/looked-up after a successful Google sign-in.
    throw Exception('profiles insert unavailable');
  }
}

final class _DeferredCountingProfileRepository
    extends _CountingProfileRepository {
  final Completer<void> _createStarted = Completer<void>();
  final Completer<void> _releaseCreate = Completer<void>();

  Future<void> get createStarted => _createStarted.future;

  void releaseCreate() {
    if (!_releaseCreate.isCompleted) _releaseCreate.complete();
  }

  @override
  Future<Profile> createProfileIfMissing({
    required String userId,
    required String email,
    required String displayName,
  }) async {
    createCallCount++;
    if (!_createStarted.isCompleted) _createStarted.complete();
    await _releaseCreate.future;
    return createWithoutCounting(
      userId: userId,
      email: email,
      displayName: displayName,
    );
  }
}

final class _DeferredReactivationLifecycleRepository
    extends MockAccountLifecycleRepository {
  _DeferredReactivationLifecycleRepository({
    required super.profileRepository,
    required super.verificationCodeRepository,
  });

  final Completer<void> _reactivationStarted = Completer<void>();
  final Completer<void> _releaseReactivation = Completer<void>();

  Future<void> get reactivationStarted => _reactivationStarted.future;

  void releaseReactivation() => _releaseReactivation.complete();

  @override
  Future<void> requestReactivation() async {
    if (!_reactivationStarted.isCompleted) _reactivationStarted.complete();
    await _releaseReactivation.future;
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
  _QueuedSignedInAuthRepository({this.signOutError});

  final Object? signOutError;
  final StreamController<AppSession> _events =
      StreamController<AppSession>.broadcast(sync: true);
  AppSession? _current;
  AppSession? _queuedSignedIn;

  void queueSignedInSession({String? userId, String? email}) {
    final session = AppSession.signedIn(
      userId: userId ?? mockUserId,
      email: email ?? mockEmail,
    );
    _current = session;
    _queuedSignedIn = session;
  }

  void releaseSignedInEvent() {
    final session = _queuedSignedIn;
    if (session == null) return;
    _queuedSignedIn = null;
    _events.add(session);
  }

  void emitSignedInSessionNow({String? userId, String? email}) {
    final session = AppSession.signedIn(
      userId: userId ?? mockUserId,
      email: email ?? mockEmail,
    );
    _current = session;
    _events.add(session);
  }

  @override
  void emitSignedInSession({String? userId, String? email}) {
    queueSignedInSession(userId: userId, email: email);
  }

  @override
  void emitSignedOutSession() {
    _current = null;
    _events.add(const AppSession.signedOut());
  }

  @override
  Future<AppSession> signInWithGoogle() async {
    queueSignedInSession();
    return _current!;
  }

  @override
  Stream<AppSession> authStateChanges() => _events.stream;

  @override
  Future<void> signOut() async {
    final error = signOutError;
    if (error != null) throw error;
    emitSignedOutSession();
  }

  @override
  String? currentUserId() => _current?.userId;

  @override
  Future<void> dispose() async {
    await _events.close();
    await super.dispose();
  }
}
