import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/auth/auth_gate.dart';
import 'package:tripjournal/features/auth/screens/login_screen.dart';
import 'package:tripjournal/features/auth/screens/suspended_screen.dart';
import 'package:tripjournal/models/profile.dart';

import 'support/auth_test_harness.dart';

void main() {
  late AuthTestHarness harness;

  setUp(() async {
    harness = AuthTestHarness();
    await harness.signOut();
  });

  tearDown(() => harness.dispose());

  Widget wrapped() => harness.wrap(const AuthGate());

  group('AuthGate routes a suspended profile to SuspendedScreen', () {
    testWidgets('signing in as an already-suspended profile shows '
        'SuspendedScreen, not HomeScreen', (tester) async {
      final existing = (await harness.profileRepository.getProfile(
        'user-001',
      ))!;
      await harness.profileRepository.updateProfile(
        existing.copyWith(status: AccountStatus.suspended),
      );

      await tester.pumpWidget(wrapped());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sign-in-with-google')));
      await tester.pumpAndSettle();

      expect(find.byType(SuspendedScreen), findsOneWidget);
      expect(find.text('Account Suspended'), findsOneWidget);
    });

    testWidgets('tapping "Sign out" on SuspendedScreen returns to '
        'LoginScreen', (tester) async {
      final existing = (await harness.profileRepository.getProfile(
        'user-001',
      ))!;
      await harness.profileRepository.updateProfile(
        existing.copyWith(status: AccountStatus.suspended),
      );

      await tester.pumpWidget(wrapped());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sign-in-with-google')));
      await tester.pumpAndSettle();
      expect(find.byType(SuspendedScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('suspended-sign-out')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SuspendedScreen), findsNothing);
    });
  });
}
