import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/auth/auth_gate.dart';
import 'package:tripjournal/features/auth/screens/admin_account_screen.dart';
import 'package:tripjournal/features/auth/screens/login_screen.dart';
import 'package:tripjournal/features/home/home_screen.dart';
import 'package:tripjournal/models/profile.dart';

import 'support/auth_test_harness.dart';

/// Regression coverage for the identity-model gap fixed 2026-08-26 (see
/// `AuthController.status`'s doc comment): a `role == admin` profile used to
/// fall straight through to `AuthStatus.authenticated`, silently handing an
/// admin account the traveler `HomeScreen` — even though
/// `docs/admin/PROGRESS.md`'s confirmed decision says admin accounts are
/// dedicated and should never resolve on the traveler side at all.
void main() {
  late AuthTestHarness harness;

  setUp(() async {
    harness = AuthTestHarness();
    await harness.signOut();
  });

  tearDown(() => harness.dispose());

  Widget wrapped() => harness.wrap(const AuthGate());

  group('AuthGate routes an admin-role profile to AdminAccountScreen', () {
    testWidgets('signing in as an admin-role profile shows '
        'AdminAccountScreen, not HomeScreen', (tester) async {
      final existing = (await harness.profileRepository.getProfile(
        'user-001',
      ))!;
      await harness.profileRepository.updateProfile(
        existing.copyWith(role: UserRole.admin),
      );

      await tester.pumpWidget(wrapped());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sign-in-with-google')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminAccountScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(
        find.text('This Is an Administrator Account'),
        findsOneWidget,
      );
    });

    testWidgets('tapping "Sign out" on AdminAccountScreen returns to '
        'LoginScreen', (tester) async {
      final existing = (await harness.profileRepository.getProfile(
        'user-001',
      ))!;
      await harness.profileRepository.updateProfile(
        existing.copyWith(role: UserRole.admin),
      );

      await tester.pumpWidget(wrapped());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sign-in-with-google')));
      await tester.pumpAndSettle();
      expect(find.byType(AdminAccountScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin-account-sign-out')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AdminAccountScreen), findsNothing);
    });
  });
}
