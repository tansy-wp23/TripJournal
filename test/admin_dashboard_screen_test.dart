import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/admin_repository_locator.dart';
import 'package:tripjournal/features/admin/admin_gate.dart';
import 'package:tripjournal/features/admin/screens/admin_dashboard_screen.dart';
import 'package:tripjournal/features/admin/screens/admin_login_screen.dart';
import 'package:tripjournal/models/admin_access_attempt_log.dart';

void main() {
  group('AdminDashboardScreen', () {
    testWidgets('renders the stat grid with the default seed counts',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminDashboardScreen())),
      );
      await tester.pump(); // triggers the post-frame loadStats callback
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-dashboard-stats-grid')), findsOneWidget);
      expect(find.textContaining('Total users'), findsOneWidget);
      expect(find.textContaining('Admins'), findsOneWidget);
    });

    testWidgets(
        'full flow: sign in on AdminLoginScreen reaches the dashboard grid',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminGate())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin-sign-in-with-google')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(find.byKey(const Key('admin-dashboard-stats-grid')), findsOneWidget);

      // Logout returns to AdminLoginScreen.
      await tester.tap(find.byKey(const Key('admin-logout')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsOneWidget);
    });

    testWidgets('shows a recorded unauthorized access attempt',
        (tester) async {
      // Tall virtual screen so the attempts section (below the stat grid)
      // is actually built — ListView is lazy and won't build off-screen
      // children at the default test viewport size.
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Recorded directly against the shared mock (rather than driven
      // through a full rejected sign-in) to test the screen's rendering in
      // isolation from the auth flow, which `admin_auth_controller_test.dart`
      // already covers. An existence check, not an exact count, so this
      // doesn't depend on whether other tests in this file ran first.
      await adminAccessAttemptLogRepository.recordAttempt(
        AdminAccessAttemptLog(
          logId: 'test-attempt-1',
          attemptedUserId: 'user-101',
          attemptedEmail: 'alice.tan@example.com',
          reason: AdminAccessAttemptReason.notAnAdmin,
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminDashboardScreen())),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('alice.tan@example.com'), findsOneWidget);
      expect(find.textContaining('Not an administrator'), findsOneWidget);
    });
  });
}
