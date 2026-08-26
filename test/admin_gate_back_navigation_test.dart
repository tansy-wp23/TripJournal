import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_admin_access_attempt_log_repository.dart';
import 'package:tripjournal/data/mock_admin_user_directory_repository.dart';
import 'package:tripjournal/data/mock_admin_user_store.dart';
import 'package:tripjournal/data/mock_auth_repository.dart';
import 'package:tripjournal/features/admin/admin_gate.dart';
import 'package:tripjournal/features/admin/controller/admin_auth_controller.dart';
import 'package:tripjournal/features/admin/screens/admin_dashboard_screen.dart';
import 'package:tripjournal/features/admin/screens/admin_login_screen.dart';

import 'support/admin_test_harness.dart';

/// Regression coverage for `AdminGate`'s back-navigation guard.
///
/// `AdminGate` is reached via `Navigator.push` from the traveler
/// `LoginScreen` (its hidden logo-tap entry), whose route stays alive
/// underneath it. Because admin sign-in shares the same Supabase session as
/// the traveler side (`adminAuthRepository` is an alias for
/// `authRepository`), popping back out after a sign-in *succeeds* would
/// surface whatever the traveler `AuthGate` now resolves to underneath —
/// not the login screen it was when the admin portal was opened. So back is
/// blocked only for `AdminAuthStatus.authenticated`, which is also the only
/// status with a real "Log out" button to point the "Log out to leave the
/// admin portal" message at (`AdminDashboardScreen`'s).
///
/// Found and fixed 2026-08-26: this guard originally also blocked
/// `unauthorized` (a real, non-admin account correctly rejected by the role
/// check) — but `AdminLoginScreen` (what `unauthorized` renders) has no
/// sign-out affordance of its own, only "Sign in with Google", so that
/// version trapped the user with an instruction ("Log out") they had no way
/// to follow. See the third test below.
void main() {
  group('AdminGate back-navigation guard', () {
    /// Mirrors the real entry point: `AdminGate` pushed on top of a route
    /// that's left alive underneath it, rather than being the app's `home`.
    Widget wrapPushed(AdminTestHarness harness) {
      return ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('push-admin-gate'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminGate()),
                  ),
                  child: const Text('open admin'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'back is blocked once a sign-in attempt has been made — stays on '
      'AdminDashboardScreen rather than leaking the route underneath',
      (tester) async {
        final harness = AdminTestHarness();
        addTearDown(harness.dispose);

        await tester.pumpWidget(wrapPushed(harness));
        await tester.tap(find.byKey(const Key('push-admin-gate')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('admin-sign-in-with-google')));
        await tester.pumpAndSettle();
        expect(find.byType(AdminDashboardScreen), findsOneWidget);

        final popped = await Navigator.of(
          tester.element(find.byType(AdminDashboardScreen)),
        ).maybePop();
        await tester.pumpAndSettle();

        // `maybePop()` returns whether the pop request was *handled*, not
        // whether the route actually popped — `RoutePopDisposition.doNotPop`
        // still counts as handled (it invokes `onPopInvokedWithResult(false,
        // ...)` and returns `true`); only `bubble` returns `false`. So the
        // real proof the block worked is the screen/snackbar assertions
        // below, not this return value.
        expect(popped, isTrue);
        expect(find.byType(AdminDashboardScreen), findsOneWidget);
        expect(find.text('open admin'), findsNothing);
        // The blocked attempt surfaces a hint rather than silently doing
        // nothing.
        expect(
          find.text('Log out to leave the admin portal.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('back is allowed again after logging out', (tester) async {
      final harness = AdminTestHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(wrapPushed(harness));
      await tester.tap(find.byKey(const Key('push-admin-gate')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin-sign-in-with-google')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin-logout')));
      await tester.pumpAndSettle();
      expect(find.byType(AdminLoginScreen), findsOneWidget);

      final popped = await Navigator.of(
        tester.element(find.byType(AdminLoginScreen)),
      ).maybePop();
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(find.text('open admin'), findsOneWidget);
    });

    testWidgets(
      'back is allowed before any sign-in attempt — nothing sensitive to '
      'leak yet',
      (tester) async {
        final harness = AdminTestHarness();
        addTearDown(harness.dispose);

        await tester.pumpWidget(wrapPushed(harness));
        await tester.tap(find.byKey(const Key('push-admin-gate')));
        await tester.pumpAndSettle();
        expect(find.byType(AdminLoginScreen), findsOneWidget);

        final popped = await Navigator.of(
          tester.element(find.byType(AdminLoginScreen)),
        ).maybePop();
        await tester.pumpAndSettle();

        expect(popped, isTrue);
        expect(find.text('open admin'), findsOneWidget);
      },
    );

    testWidgets(
      'a rejected (non-admin) sign-in attempt auto-pops back to the '
      'traveler side and relays the rejection as a SnackBar there',
      (tester) async {
        // AdminGate only ever reads adminAuthControllerProvider — no need
        // for AdminTestHarness's other eight controllers here. Uses the
        // seeded non-admin 'user-101' / alice.tan@example.com row from
        // MockAdminUserStore.defaultSeed() (mirrors
        // admin_auth_controller_test.dart's equivalent case).
        final authRepository = MockAuthRepository(
          mockUserId: 'user-101',
          mockEmail: 'alice.tan@example.com',
        );
        final authController = AdminAuthController(
          authRepository,
          MockAdminUserDirectoryRepository(MockAdminUserStore()),
          MockAdminAccessAttemptLogRepository(),
        );
        addTearDown(authController.dispose);
        addTearDown(authRepository.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              adminAuthControllerProvider.overrideWith(
                (ref) => authController,
                disposeNotifier: false,
              ),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('push-admin-gate'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AdminGate()),
                      ),
                      child: const Text('open admin'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('push-admin-gate')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('admin-sign-in-with-google')));
        await tester.pumpAndSettle();

        // AdminGate has already popped itself (found and fixed 2026-08-26,
        // AdminAuthController._rejectAndSignOut) — no manual back-press
        // needed, and no AdminLoginScreen left showing the error, since
        // that screen has no way to satisfy "Log out" anyway.
        expect(find.byType(AdminLoginScreen), findsNothing);
        expect(find.text('open admin'), findsOneWidget);
        // The rejection message is relayed as a SnackBar on the screen
        // underneath instead.
        expect(
          find.text('This Google account is not registered as an administrator.'),
          findsOneWidget,
        );
        expect(
          find.text('Log out to leave the admin portal.'),
          findsNothing,
        );

        // And the rejected account is fully signed out — session and Google's
        // own cached account selection both cleared — so a follow-up
        // attempt starts clean rather than silently reusing the same
        // wrong account.
        expect(authController.session, isNull);
        expect(authController.hasPendingRejection, isFalse);
      },
    );
  });
}
