import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripjournal/data/mock_profile_avatar_storage.dart';
import 'package:tripjournal/features/auth/auth_gate.dart';
import 'package:tripjournal/features/guest/guest_home_screen.dart';
import 'package:tripjournal/features/navigation/authenticated_app_shell.dart';
import 'package:tripjournal/features/profile/controller/profile_controller.dart';

import 'support/auth_test_harness.dart';

Widget _wrapApp(AuthTestHarness harness, ProfileController profileController) {
  return harness.wrap(
    ProviderScope(
      overrides: [
        profileControllerProvider.overrideWith(
          (ref) => profileController,
          disposeNotifier: false,
        ),
      ],
      child: const AuthGate(),
    ),
  );
}

void main() {
  testWidgets('the Account safety card signs out to guest browsing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = AuthTestHarness();
    addTearDown(harness.dispose);
    await harness.signIn();
    final profileController = ProfileController(
      harness.profileRepository,
      harness.controller,
      MockProfileAvatarStorage(),
    );

    // Pump the real AuthGate so the post-logout swap is exercised end to end.
    await tester.pumpWidget(_wrapApp(harness, profileController));
    await tester.pumpAndSettle();
    expect(find.byType(AuthenticatedAppShell), findsOneWidget);

    // Real user path: bottom-nav Profile tab, then Log out.
    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-logout-button')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('profile-logout-button')),
    );
    await tester.tap(find.byKey(const Key('profile-logout-button')));
    await tester.pumpAndSettle();

    // AuthGate swaps itself to guest browsing — no explicit navigation.
    expect(find.byType(GuestHomeScreen), findsOneWidget);
    expect(find.byType(AuthenticatedAppShell), findsNothing);
  });
}
