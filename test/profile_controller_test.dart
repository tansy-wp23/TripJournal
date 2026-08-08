import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_auth_repository.dart';
import 'package:tripjournal/data/mock_profile_repository.dart';
import 'package:tripjournal/features/auth/controller/auth_controller.dart';
import 'package:tripjournal/features/profile/controller/profile_controller.dart';
import 'package:tripjournal/validation/profile_validation.dart';

void main() {
  late MockAuthRepository authRepository;
  late MockProfileRepository profileRepository;
  late AuthController authController;
  late ProfileController controller;

  setUp(() {
    authRepository = MockAuthRepository();
    profileRepository = MockProfileRepository(state: MockProfileState.active);
    authController = AuthController(authRepository, profileRepository);
    controller = ProfileController(profileRepository, authController);
  });

  tearDown(() {
    controller.dispose();
    authController.dispose();
  });

  group('ProfileController', () {
    test('loadProfile loads the profile for the signed-in user', () async {
      await authController.signInWithGoogle();
      await controller.loadProfile();

      expect(controller.profile, isNotNull);
      expect(controller.profile!.userID, 'user-001');
      expect(controller.profile!.displayName, 'Sang You');
      expect(controller.error, isNull);
    });

    test('loadProfile sets error when not signed in', () async {
      await controller.loadProfile();

      expect(controller.profile, isNull);
      expect(controller.error, 'Not signed in.');
    });

    test('updateDisplayName updates the profile display name', () async {
      await authController.signInWithGoogle();
      await controller.loadProfile();

      final error = await controller.updateDisplayName('New Name');

      expect(error, isNull);
      expect(controller.profile!.displayName, 'New Name');
    });

    test('updateDisplayName trims whitespace', () async {
      await authController.signInWithGoogle();
      await controller.loadProfile();

      final error = await controller.updateDisplayName('  New Name  ');

      expect(error, isNull);
      expect(controller.profile!.displayName, 'New Name');
    });

    test('updateDisplayName rejects empty display name', () async {
      await authController.signInWithGoogle();
      await controller.loadProfile();

      final error = await controller.updateDisplayName('');

      expect(error, isNotNull);
      expect(controller.profile!.displayName, 'Sang You');
    });

    test('updateDisplayName rejects display name over max length', () async {
      await authController.signInWithGoogle();
      await controller.loadProfile();

      final error = await controller.updateDisplayName(
        'A' * (kProfileDisplayNameMaxLength + 1),
      );

      expect(error, isNotNull);
      expect(controller.profile!.displayName, 'Sang You');
    });
  });
}