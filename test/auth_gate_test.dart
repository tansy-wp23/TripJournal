import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/auth/auth_gate.dart';
import 'package:tripjournal/features/auth/screens/login_screen.dart';
import 'package:tripjournal/features/guest/guest_home_screen.dart';

import 'support/auth_test_harness.dart';

/// Focused on the Guest Mode routing behavior (2026-08-27 redesign): a
/// first-time launch or a just-logged-out user lands on [GuestHomeScreen]
/// directly, and [LoginScreen] is reached only as an explicit, pushed
/// prompt — never as a status [AuthGate] routes to on its own. Every other
/// [AuthGate] case (authenticated, needsOnboarding, deactivated, suspended,
/// adminAccount) predates this file and isn't re-covered here.
void main() {
  late AuthTestHarness harness;

  setUp(() async {
    harness = AuthTestHarness();
    await harness.signOut();
  });

  tearDown(() => harness.dispose());

  testWidgets(
    'a first-time launch (no session, no explicit action) lands on '
    'GuestHomeScreen directly, not a login wall',
    (tester) async {
      await tester.pumpWidget(harness.wrap(const AuthGate()));
      await tester.pump();

      expect(find.byType(GuestHomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    },
  );

  testWidgets(
    'tapping the guest profile affordance pushes LoginScreen as a prompt, '
    'on top of GuestHomeScreen',
    (tester) async {
      await tester.pumpWidget(harness.wrap(const AuthGate()));
      await tester.pump();
      expect(find.byType(GuestHomeScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('guest-sign-in-button')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );

  testWidgets(
    'backing out of the pushed LoginScreen returns to GuestHomeScreen — '
    'a guest who was just peeking is never stuck',
    (tester) async {
      await tester.pumpWidget(harness.wrap(const AuthGate()));
      await tester.pump();
      await tester.tap(find.byKey(const Key('guest-sign-in-button')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(GuestHomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    },
  );

  testWidgets('signing out returns AuthGate to GuestHomeScreen, not LoginScreen', (
    tester,
  ) async {
    await harness.signIn();
    await tester.pumpWidget(harness.wrap(const AuthGate()));
    await tester.pump();

    await harness.signOut();
    await tester.pump();

    expect(find.byType(GuestHomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}
