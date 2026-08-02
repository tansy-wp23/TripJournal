import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_auth_repository.dart';
import 'package:tripjournal/data/mock_profile_repository.dart';
import 'package:tripjournal/features/auth/controller/auth_controller.dart';

void main() {
  late MockAuthRepository authRepository;
  late MockProfileRepository profileRepository;
  late AuthController controller;

  setUp(() {
    authRepository = MockAuthRepository();
    profileRepository = MockProfileRepository(state: MockProfileState.active);
    controller = AuthController(authRepository, profileRepository);
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
      controller = AuthController(authRepository, profileRepository);

      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.authenticated);
      expect(controller.profile, isNotNull);
      expect(controller.profile!.userID, 'user-001');
    });

    test('deactivated user sets status to deactivated', () async {
      profileRepository = MockProfileRepository(state: MockProfileState.deactivated);
      controller = AuthController(authRepository, profileRepository);

      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.deactivated);
      expect(controller.profile!.isDeactivated, isTrue);
    });

    test('failed sign-in sets error and stays signedOut', () async {
      authRepository = MockAuthRepository(result: MockAuthResult.failure);
      controller = AuthController(authRepository, profileRepository);

      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.signedOut);
      expect(controller.error, isNotNull);
      expect(controller.error!.contains('failed'), isTrue);
    });

    test('cancelled sign-in sets a cancelled error and stays signedOut', () async {
      authRepository = MockAuthRepository(result: MockAuthResult.cancelled);
      controller = AuthController(authRepository, profileRepository);

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
  });
}