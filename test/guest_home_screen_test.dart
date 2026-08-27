import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/auth/controller/auth_controller.dart';
import 'package:tripjournal/features/auth/screens/login_screen.dart';
import 'package:tripjournal/features/community/community_screen.dart';
import 'package:tripjournal/features/guest/guest_home_screen.dart';

import 'support/auth_test_harness.dart';

void main() {
  late AuthTestHarness harness;

  setUp(() async {
    harness = AuthTestHarness();
    await harness.signOut();
  });

  tearDown(() => harness.dispose());

  testWidgets('embeds the real CommunityScreen, not a forked copy', (
    tester,
  ) async {
    await tester.pumpWidget(harness.wrap(const GuestHomeScreen()));
    await tester.pump();

    expect(find.byType(CommunityScreen), findsOneWidget);
    expect(find.byKey(const Key('guest-home-screen')), findsOneWidget);
    // The features built for the signed-in Community screen still work for
    // a guest — GuestHomeScreen must not have forked/regressed them.
    expect(
      find.byKey(const Key('community-destination-search-toggle')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('community-search-by-id')), findsOneWidget);
  });

  testWidgets(
    'tapping the profile/"Sign in" affordance pushes LoginScreen as a '
    'prompt, without changing any auth state',
    (tester) async {
      await tester.pumpWidget(harness.wrap(const GuestHomeScreen()));
      await tester.pump();

      await tester.tap(find.byKey(const Key('guest-sign-in-button')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      // Merely opening the prompt doesn't sign anything in.
      expect(harness.controller.status, AuthStatus.guest);
    },
  );
}
