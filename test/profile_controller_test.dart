import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_account_lifecycle_repository.dart';
import 'package:tripjournal/data/mock_auth_repository.dart';
import 'package:tripjournal/data/mock_profile_avatar_storage.dart';
import 'package:tripjournal/data/mock_profile_repository.dart';
import 'package:tripjournal/data/mock_verification_code_repository.dart';
import 'package:tripjournal/features/auth/controller/auth_controller.dart';
import 'package:tripjournal/features/profile/controller/profile_controller.dart';
import 'package:tripjournal/validation/photo_validation.dart';
import 'package:tripjournal/validation/profile_validation.dart';

void main() {
  late MockAuthRepository authRepository;
  late MockProfileRepository profileRepository;
  late MockProfileAvatarStorage avatarStorage;
  late MockVerificationCodeRepository verificationCodeRepository;
  late MockAccountLifecycleRepository lifecycleRepository;
  late AuthController authController;
  late ProfileController controller;

  setUp(() {
    authRepository = MockAuthRepository();
    profileRepository = MockProfileRepository(state: MockProfileState.active);
    avatarStorage = MockProfileAvatarStorage();
    verificationCodeRepository = MockVerificationCodeRepository();
    lifecycleRepository = MockAccountLifecycleRepository(
      profileRepository: profileRepository,
      verificationCodeRepository: verificationCodeRepository,
    );
    authController = AuthController(authRepository, profileRepository, lifecycleRepository);
    controller = ProfileController(profileRepository, authController, avatarStorage);
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

    test('updateAvatar uploads the photo and sets avatarUrl', () async {
      await authController.signInWithGoogle();
      await controller.loadProfile();
      final photo = XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'avatar.jpg',
        mimeType: 'image/jpeg',
      );

      final error = await controller.updateAvatar(photo);

      expect(error, isNull);
      expect(controller.profile!.avatarUrl, isNotNull);
    });

    test('updateAvatar rejects a photo over the max size', () async {
      await authController.signInWithGoogle();
      await controller.loadProfile();
      final photo = XFile.fromData(
        Uint8List(kMaxPhotoSizeBytes + 1),
        name: 'avatar.jpg',
        mimeType: 'image/jpeg',
      );

      final error = await controller.updateAvatar(photo);

      expect(error, isNotNull);
      expect(controller.profile!.avatarUrl, isNull);
    });

    test('removeAvatar clears a previously set avatarUrl', () async {
      await authController.signInWithGoogle();
      await controller.loadProfile();
      final photo = XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'avatar.jpg',
        mimeType: 'image/jpeg',
      );
      await controller.updateAvatar(photo);
      expect(controller.profile!.avatarUrl, isNotNull);

      final error = await controller.removeAvatar();

      expect(error, isNull);
      expect(controller.profile!.avatarUrl, isNull);
    });

    test('removeAvatar is a no-op when there is no avatar', () async {
      await authController.signInWithGoogle();
      await controller.loadProfile();

      final error = await controller.removeAvatar();

      expect(error, isNull);
      expect(controller.profile!.avatarUrl, isNull);
    });

    group('completeOnboarding', () {
      test('saves all fields and marks the profile completed', () async {
        profileRepository = MockProfileRepository(
          state: MockProfileState.firstTime,
        );
        lifecycleRepository = MockAccountLifecycleRepository(
          profileRepository: profileRepository,
          verificationCodeRepository: verificationCodeRepository,
        );
        authController = AuthController(
          authRepository,
          profileRepository,
          lifecycleRepository,
        );
        controller = ProfileController(
          profileRepository,
          authController,
          avatarStorage,
        );
        await authController.signInWithGoogle();
        expect(authController.status, AuthStatus.needsOnboarding);
        await controller.loadProfile();

        final error = await controller.completeOnboarding(
          displayName: 'Sang You',
          dateOfBirth: DateTime(2000, 5, 7),
          country: 'Malaysia',
          travelInterests: {'Scenery', 'Food'},
        );

        expect(error, isNull);
        expect(controller.profile!.profileCompleted, isTrue);
        expect(controller.profile!.dateOfBirth, DateTime(2000, 5, 7));
        expect(controller.profile!.country, 'Malaysia');
        expect(controller.profile!.travelInterests, ['Scenery', 'Food']);
        // The whole point: AuthController's own cached profile is refreshed
        // too, so AuthGate stops showing the onboarding screen.
        expect(authController.status, AuthStatus.authenticated);
      });

      test('rejects an empty display name without saving', () async {
        await authController.signInWithGoogle();
        await controller.loadProfile();

        final error = await controller.completeOnboarding(
          displayName: '',
          travelInterests: {},
        );

        expect(error, isNotNull);
        expect(controller.profile!.displayName, 'Sang You');
      });

      test('rejects a future date of birth without saving', () async {
        await authController.signInWithGoogle();
        await controller.loadProfile();

        final error = await controller.completeOnboarding(
          displayName: 'Sang You',
          dateOfBirth: DateTime.now().add(const Duration(days: 1)),
          travelInterests: {},
        );

        expect(error, isNotNull);
        expect(controller.profile!.dateOfBirth, isNull);
      });
    });

    group('skipOnboarding', () {
      test('marks completed without touching other fields', () async {
        profileRepository = MockProfileRepository(
          state: MockProfileState.firstTime,
        );
        lifecycleRepository = MockAccountLifecycleRepository(
          profileRepository: profileRepository,
          verificationCodeRepository: verificationCodeRepository,
        );
        authController = AuthController(
          authRepository,
          profileRepository,
          lifecycleRepository,
        );
        controller = ProfileController(
          profileRepository,
          authController,
          avatarStorage,
        );
        await authController.signInWithGoogle();
        await controller.loadProfile();
        final nameBefore = controller.profile!.displayName;

        final error = await controller.skipOnboarding();

        expect(error, isNull);
        expect(controller.profile!.profileCompleted, isTrue);
        expect(controller.profile!.displayName, nameBefore);
        expect(authController.status, AuthStatus.authenticated);
      });
    });

    group('updateTravelDetails', () {
      test('saves date of birth, country and interests', () async {
        await authController.signInWithGoogle();
        await controller.loadProfile();

        final error = await controller.updateTravelDetails(
          dateOfBirth: DateTime(1995, 1, 1),
          country: 'Japan',
          travelInterests: {'History', 'Culture'},
        );

        expect(error, isNull);
        expect(controller.profile!.dateOfBirth, DateTime(1995, 1, 1));
        expect(controller.profile!.country, 'Japan');
        expect(controller.profile!.travelInterests, ['History', 'Culture']);
        // Editing an already-onboarded profile must not disturb the flag.
        expect(controller.profile!.profileCompleted, isTrue);
      });

      test('rejects a future date of birth', () async {
        await authController.signInWithGoogle();
        await controller.loadProfile();

        final error = await controller.updateTravelDetails(
          dateOfBirth: DateTime.now().add(const Duration(days: 1)),
          travelInterests: {},
        );

        expect(error, isNotNull);
      });
    });
  });
}