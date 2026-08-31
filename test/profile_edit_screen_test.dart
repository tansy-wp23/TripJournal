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

/// The edit screen's `ListView` is sliver-backed and lazily builds only
/// what's near the viewport — fields further down (travel interests,
/// country) aren't mounted until scrolled into range. Mirrors
/// `place_picker_screen_test.dart`'s `scrollUntilVisible` use.
Future<Finder> _scrollToKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key), skipOffstage: false).first;
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  return find.byKey(Key(key));
}

void main() {
  testWidgets('presents identity and travel details as clear sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profileRepository = MockProfileRepository(
      state: MockProfileState.active,
    );
    final authController = AuthController(
      MockAuthRepository(),
      profileRepository,
      MockAccountLifecycleRepository(
        profileRepository: profileRepository,
        verificationCodeRepository: MockVerificationCodeRepository(),
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

    expect(find.text('Profile photo'), findsOneWidget);
    expect(find.text('Identity'), findsOneWidget);
    expect(find.text('Travel preferences'), findsOneWidget);
  });

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

  testWidgets(
    'editing travel interests and country saves through updateTravelDetails '
    '(Profile Onboarding feature — same widgets as onboarding)',
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

      final interestChip = await _scrollToKey(
        tester,
        'travel-interest-chip-History',
      );
      await tester.tap(interestChip);
      await tester.pumpAndSettle();

      final countrySelector = await _scrollToKey(
        tester,
        'country-selector-field',
      );
      await tester.tap(countrySelector);
      await tester.pumpAndSettle();

      // Filter first — the sheet's list is lazily built, and 'Japan'
      // (unfiltered, alphabetically) sits far enough down that it may not be
      // mounted without scrolling. Narrowing to one match sidesteps that.
      await tester.enterText(
        find.byKey(const Key('country-search-field')),
        'Japan',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('country-option-Japan')));
      await tester.pumpAndSettle();

      final saveButton = find.byKey(const Key('profile-save-button'));
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(controller.profile!.travelInterests, ['History']);
      expect(controller.profile!.country, 'Japan');
      // Editing an already-active profile must never flip this back to
      // needing onboarding.
      expect(controller.profile!.profileCompleted, isTrue);
    },
  );
}
