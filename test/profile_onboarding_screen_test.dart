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
import 'package:tripjournal/features/profile/screens/profile_onboarding_screen.dart';

/// Builds a signed-in, genuinely-new-user harness (mirrors
/// `profile_edit_screen_test.dart`'s pattern) — `MockProfileState.firstTime`
/// so the created profile starts with `profileCompleted == false`, matching
/// what actually routes a real user to this screen.
({AuthController authController, ProfileController controller}) _harness() {
  final profileRepository = MockProfileRepository(
    state: MockProfileState.firstTime,
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
  final controller = ProfileController(
    profileRepository,
    authController,
    MockProfileAvatarStorage(),
  );
  return (authController: authController, controller: controller);
}

Future<void> _pump(WidgetTester tester, ProfileController controller) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [profileControllerProvider.overrideWith((ref) => controller)],
      child: const MaterialApp(home: ProfileOnboardingScreen()),
    ),
  );
}

/// The onboarding form is long enough that its bottom fields/button aren't
/// mounted (the surrounding `ListView` is sliver-backed and lazily builds
/// only what's near the viewport) until scrolled into range — same pattern
/// as `place_picker_screen_test.dart`'s `scrollUntilVisible` use.
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
  testWidgets(
    'pre-fills the Google-derived display name so Continue works untouched',
    (tester) async {
      final h = _harness();
      await h.authController.signInWithGoogle();
      addTearDown(h.authController.dispose);

      await _pump(tester, h.controller);
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(
        find.byKey(const Key('onboarding-display-name-field')),
      );
      // AuthController._deriveDisplayName splits on '._-' only — the seeded
      // mock email 'sangyou@example.com' has no separator, so it title-cases
      // the whole local part as one word rather than "Sang You".
      expect(field.controller!.text, 'Sangyou');
    },
  );

  testWidgets('Skip for now completes onboarding without validating fields', (
    tester,
  ) async {
    final h = _harness();
    await h.authController.signInWithGoogle();
    addTearDown(h.authController.dispose);
    expect(h.authController.status, AuthStatus.needsOnboarding);

    await _pump(tester, h.controller);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding-skip-button')));
    await tester.pumpAndSettle();

    expect(h.controller.profile!.profileCompleted, isTrue);
    expect(h.authController.status, AuthStatus.authenticated);
  });

  testWidgets('Continue with an empty name shows a validation error', (
    tester,
  ) async {
    final h = _harness();
    await h.authController.signInWithGoogle();
    addTearDown(h.authController.dispose);

    await _pump(tester, h.controller);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('onboarding-display-name-field')),
      '',
    );
    final continueButton = await _scrollToKey(
      tester,
      'onboarding-continue-button',
    );
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Please enter a display name.'), findsOneWidget);
    // Never trapped-but-also-never-silently-completed: a validation failure
    // must not flip profileCompleted.
    expect(h.controller.profile!.profileCompleted, isFalse);
    expect(h.authController.status, AuthStatus.needsOnboarding);
  });

  testWidgets('Continue with a valid name saves interests and completes', (
    tester,
  ) async {
    final h = _harness();
    await h.authController.signInWithGoogle();
    addTearDown(h.authController.dispose);

    await _pump(tester, h.controller);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('travel-interest-chip-Scenery')));
    await tester.tap(find.byKey(const Key('travel-interest-chip-Food')));
    await tester.pumpAndSettle();

    final continueButton = await _scrollToKey(
      tester,
      'onboarding-continue-button',
    );
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(h.controller.profile!.profileCompleted, isTrue);
    expect(h.controller.profile!.travelInterests, ['Scenery', 'Food']);
    expect(h.authController.status, AuthStatus.authenticated);
  });

  testWidgets('country selector opens a searchable list and picks a country', (
    tester,
  ) async {
    final h = _harness();
    await h.authController.signInWithGoogle();
    addTearDown(h.authController.dispose);

    await _pump(tester, h.controller);
    await tester.pumpAndSettle();

    final countrySelector = await _scrollToKey(
      tester,
      'country-selector-field',
    );
    await tester.tap(countrySelector);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('country-search-field')),
      'Malay',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('country-option-Malaysia')), findsOneWidget);
    await tester.tap(find.byKey(const Key('country-option-Malaysia')));
    await tester.pumpAndSettle();

    expect(find.text('Malaysia'), findsOneWidget);

    final continueButton = await _scrollToKey(
      tester,
      'onboarding-continue-button',
    );
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(h.controller.profile!.country, 'Malaysia');
  });
}
