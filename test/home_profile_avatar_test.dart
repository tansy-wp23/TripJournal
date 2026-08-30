import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/home/home_screen.dart';
import 'package:tripjournal/features/profile/widgets/profile_avatar.dart';

import 'support/auth_test_harness.dart';

/// The home app bar's profile button shows the signed-in user's actual
/// profile picture (falling back to their initial) instead of a generic
/// person icon, once AuthController has a cached profile.
void main() {
  testWidgets('shows the person icon while no profile is cached', (tester) async {
    // No sign-in: AuthController has no session/profile yet, so the app bar
    // falls back to the generic icon (mirrors a not-yet-loaded state).
    final harness = AuthTestHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byType(ProfileAvatar), findsNothing);
  });

  testWidgets("shows the user's initial once the profile is cached", (
    tester,
  ) async {
    final harness = AuthTestHarness();
    addTearDown(harness.dispose);
    // Interactive mock sign-in populates AuthController's cached profile
    // (createProfileIfMissing) — the same state Home sees in production.
    await harness.signIn();

    await tester.pumpWidget(harness.wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person), findsNothing);
    expect(find.byType(ProfileAvatar), findsOneWidget);

    // No avatar URL in the mock seed, so the initial is shown — derived
    // from the profile's display name, same as ProfileViewScreen's hero.
    final profile = await harness.profileRepository.getProfile(
      harness.authRepository.mockUserId,
    );
    final expectedInitial = profile!.displayName[0].toUpperCase();
    expect(find.text(expectedInitial), findsOneWidget);
  });
}
