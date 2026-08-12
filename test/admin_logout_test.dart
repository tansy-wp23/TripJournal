import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/admin_gate.dart';
import 'package:tripjournal/features/admin/controller/admin_auth_controller.dart';
import 'package:tripjournal/features/admin/screens/admin_dashboard_screen.dart';
import 'package:tripjournal/features/admin/screens/admin_login_screen.dart';

/// PB-10: Logout Administrator (Phase 6). The behavior itself has existed
/// since Phase 2 (a side effect of `AdminDashboardScreen`'s logout button)
/// and was already exercised incidentally by `admin_dashboard_screen_test.dart`'s
/// "full flow" test — this file gives it the explicit, named coverage the
/// plan's own Phase 6 Definition of Done calls for, driven through
/// `AdminGate` end-to-end rather than pumping `AdminDashboardScreen` in
/// isolation.
void main() {
  group('PB-10: Logout Administrator', () {
    testWidgets(
        'logout returns to AdminLoginScreen, driven by AdminGate state '
        'rather than a manual redirect', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AdminGate()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminLoginScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin-sign-in-with-google')));
      await tester.pumpAndSettle();
      expect(find.byType(AdminDashboardScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin-logout')));
      await tester.pumpAndSettle();

      // AdminGate swapped the screen on its own by reacting to
      // AdminAuthController.status — the logout button's handler itself
      // only calls signOut(), no Navigator call.
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.byType(AdminDashboardScreen), findsNothing);
    });

    testWidgets('logout clears profile and session — no stale admin state',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AdminGate()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin-sign-in-with-google')));
      await tester.pumpAndSettle();

      final signedIn = container.read(adminAuthControllerProvider);
      expect(signedIn.profile, isNotNull);
      expect(signedIn.session, isNotNull);
      expect(signedIn.status, AdminAuthStatus.authenticated);

      await tester.tap(find.byKey(const Key('admin-logout')));
      await tester.pumpAndSettle();

      final afterLogout = container.read(adminAuthControllerProvider);
      expect(afterLogout.profile, isNull);
      expect(afterLogout.session, isNull);
      expect(afterLogout.error, isNull);
      expect(afterLogout.status, AdminAuthStatus.signedOut);
    });

    testWidgets(
        'signing back in after logout reaches the dashboard again (no '
        'stale signedOut state blocking a fresh sign-in)', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AdminGate()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin-sign-in-with-google')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin-logout')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin-sign-in-with-google')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(container.read(adminAuthControllerProvider).status, AdminAuthStatus.authenticated);
    });
  });
}
