import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripjournal/data/mock_profile_avatar_storage.dart';
import 'package:tripjournal/features/profile/controller/profile_controller.dart';
import 'package:tripjournal/features/profile/screens/profile_view_screen.dart';

import 'support/auth_test_harness.dart';

void main() {
  testWidgets('groups travel, app preferences, and account safety clearly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
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
    addTearDown(profileController.dispose);

    await tester.pumpWidget(
      harness.wrap(
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => profileController,
              disposeNotifier: false,
            ),
          ],
          child: const ProfileViewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<AppBar>(find.byType(AppBar)).actions ?? const <Widget>[],
      isEmpty,
    );
    expect(find.byKey(const Key('profile-edit-button')), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Travel preferences'), findsOneWidget);
    expect(find.text('App preferences'), findsOneWidget);
    expect(find.text('Account safety'), findsOneWidget);
    expect(find.byKey(const Key('profile-settings-button')), findsOneWidget);
    expect(
      find.byKey(const Key('profile-recently-deleted-button')),
      findsOneWidget,
    );
  });
}
