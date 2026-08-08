import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/account_lifecycle_repository.dart';
import 'package:tripjournal/data/mock_account_lifecycle_repository.dart';
import 'package:tripjournal/data/mock_auth_repository.dart';
import 'package:tripjournal/data/mock_profile_repository.dart';
import 'package:tripjournal/data/mock_verification_code_repository.dart';
import 'package:tripjournal/features/auth/controller/auth_controller.dart';
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
    controller = AuthController(authRepository, profileRepository, lifecycleRepository);
  });

  tearDown(() => controller.dispose());

  group('AuthController', () {
    test('initial status is signedOut', () {
      expect(controller.status, AuthStatus.signedOut);
    });

    test('successful sign-in sets status to authenticated', () async {
      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.authenticated);
      expect(controller.currentUserId, 'user-001');
      expect(controller.profile, isNotNull);
      expect(controller.profile!.isActive, isTrue);
    });

    test('first-time user gets a profile created on sign-in', () async {
      profileRepository = MockProfileRepository(state: MockProfileState.firstTime);
      lifecycleRepository = MockAccountLifecycleRepository(
        profileRepository: profileRepository,
        verificationCodeRepository: verificationCodeRepository,
      );
      controller = AuthController(authRepository, profileRepository, lifecycleRepository);

      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.authenticated);
      expect(controller.profile, isNotNull);
      expect(controller.profile!.userID, 'user-001');
    });

    test('deactivated user sets status to deactivated', () async {
      profileRepository = MockProfileRepository(state: MockProfileState.deactivated);
      lifecycleRepository = MockAccountLifecycleRepository(
        profileRepository: profileRepository,
        verificationCodeRepository: verificationCodeRepository,
      );
      controller = AuthController(authRepository, profileRepository, lifecycleRepository);

      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.deactivated);
      expect(controller.profile!.isDeactivated, isTrue);
    });

    test('failed sign-in sets error and stays signedOut', () async {
      authRepository = MockAuthRepository(result: MockAuthResult.failure);
      controller = AuthController(authRepository, profileRepository, lifecycleRepository);

      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.signedOut);
      expect(controller.error, isNotNull);
      expect(controller.error!.contains('failed'), isTrue);
    });

    test('cancelled sign-in sets a cancelled error and stays signedOut', () async {
      authRepository = MockAuthRepository(result: MockAuthResult.cancelled);
      controller = AuthController(authRepository, profileRepository, lifecycleRepository);

      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.signedOut);
      expect(controller.error, 'Sign-in cancelled.');
    });

    test('signOut clears session and profile', () async {
      await controller.signInWithGoogle();
      expect(controller.status, AuthStatus.authenticated);

      await controller.signOut();

      expect(controller.status, AuthStatus.signedOut);
      expect(controller.session, isNull);
      expect(controller.profile, isNull);
    });

    test('loading is true during sign-in, false after', () async {
      final future = controller.signInWithGoogle();
      expect(controller.loading, isTrue);
      await future;
      expect(controller.loading, isFalse);
    });

    test('deactivated sign-in automatically sends a reactivation code',
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
    });

    test('confirmReactivation with valid code sets status to authenticated',
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
    });

    test('confirmReactivation with wrong code throws and stays deactivated',
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
    });

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

    test('confirmDeactivation with wrong code throws and stays signed in',
        () async {
      await controller.signInWithGoogle();

      await controller.requestDeactivation();

      expect(
        () => controller.confirmDeactivation('000000'),
        throwsA(isA<CodeValidationException>()),
      );
      expect(controller.status, AuthStatus.authenticated);
    });
  });
}
