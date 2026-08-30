import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripjournal/data/mock_profile_avatar_storage.dart';
import 'package:tripjournal/features/community/community_screen.dart';
import 'package:tripjournal/features/home/home_screen.dart';
import 'package:tripjournal/features/navigation/authenticated_app_shell.dart';
import 'package:tripjournal/features/profile/controller/profile_controller.dart';
import 'package:tripjournal/features/profile/screens/profile_view_screen.dart';

import 'support/auth_test_harness.dart';

Widget _wrapShell(
  AuthTestHarness harness,
  ProfileController profileController,
) {
  return harness.wrap(
    ProviderScope(
      overrides: [
        profileControllerProvider.overrideWith(
          (ref) => profileController,
          disposeNotifier: false,
        ),
      ],
      child: const AuthenticatedAppShell(),
    ),
  );
}

ProfileController _profileControllerFor(AuthTestHarness harness) {
  return ProfileController(
    harness.profileRepository,
    harness.controller,
    MockProfileAvatarStorage(),
  );
}

void main() {
  testWidgets(
    'authenticated users receive three persistent root destinations',
    (tester) async {
      final harness = AuthTestHarness();
      addTearDown(harness.dispose);
      await harness.signIn();
      final profileController = _profileControllerFor(harness);
      addTearDown(profileController.dispose);

      await tester.pumpWidget(_wrapShell(harness, profileController));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.byType(HomeScreen).hitTestable(), findsOneWidget);
      expect(find.text('My journeys'), findsOneWidget);
      expect(find.byKey(const Key('community-button')), findsNothing);
      expect(find.byType(ProfileViewScreen, skipOffstage: false), findsNothing);
    },
  );

  testWidgets('root navigation switches the visible destination', (
    tester,
  ) async {
    final harness = AuthTestHarness();
    addTearDown(harness.dispose);
    await harness.signIn();
    final profileController = _profileControllerFor(harness);
    addTearDown(profileController.dispose);

    await tester.pumpWidget(_wrapShell(harness, profileController));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-community')));
    await tester.pump();
    expect(find.byType(CommunityScreen).hitTestable(), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileViewScreen).hitTestable(), findsOneWidget);
  });

  testWidgets('switching root destinations preserves Home search state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = AuthTestHarness();
    addTearDown(harness.dispose);
    await harness.signIn();
    final profileController = _profileControllerFor(harness);
    addTearDown(profileController.dispose);

    await tester.pumpWidget(_wrapShell(harness, profileController));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trip-search-toggle')));
    await tester.pump();
    expect(find.byKey(const Key('trip-search-field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-community')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('nav-trips')));
    await tester.pump();

    expect(find.byKey(const Key('trip-search-field')), findsOneWidget);
  });
}
