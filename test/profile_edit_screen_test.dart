import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_account_lifecycle_repository.dart';
import 'package:tripjournal/data/mock_auth_repository.dart';
import 'package:tripjournal/data/mock_profile_avatar_storage.dart';
import 'package:tripjournal/data/mock_profile_repository.dart';
import 'package:tripjournal/data/mock_verification_code_repository.dart';
import 'package:tripjournal/features/auth/controller/auth_controller.dart';
import 'package:tripjournal/features/profile/controller/profile_controller.dart';
import 'package:tripjournal/features/profile/screens/profile_edit_screen.dart';

void main() {
  testWidgets(
    'avatar picker offers camera and gallery, matching the trip cover photo flow',
    (tester) async {
      final profileRepository = MockProfileRepository(
        state: MockProfileState.active,
      );
      final verificationCodeRepository = MockVerificationCodeRepository();
      final authController = AuthController(
        MockAuthRepository(),
        profileRepository,
        MockAccountLifecycleRepository(
          profileRepository: profileRepository,
          verificationCodeRepository: verificationCodeRepository,
        ),
      );
      await authController.signInWithGoogle();
      final controller = ProfileController(
        profileRepository,
        authController,
        MockProfileAvatarStorage(),
      );
      await controller.loadProfile();
      addTearDown(authController.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: ProfileEditScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('profile-remove-avatar-button')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('profile-avatar-picker-button')));
      await tester.pumpAndSettle();

      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);

      // Under `flutter test` there's no interactive file dialog to complete,
      // so the real picker resolves with nothing picked — same behaviour as
      // a user backing out on a real device. Must not crash or get stuck.
      await tester.tap(find.byKey(const Key('pick-avatar-photo-gallery')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('profile-remove-avatar-button')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
