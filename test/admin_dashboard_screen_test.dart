import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/admin_gate.dart';
import 'package:tripjournal/features/admin/screens/admin_dashboard_screen.dart';
import 'package:tripjournal/features/admin/screens/admin_issue_report_list_screen.dart';
import 'package:tripjournal/features/admin/screens/admin_login_screen.dart';
import 'package:tripjournal/features/admin/screens/admin_user_detail_screen.dart';
import 'package:tripjournal/features/admin/screens/admin_user_list_screen.dart';
import 'package:tripjournal/features/admin/screens/audit_log_screen.dart';
import 'package:tripjournal/models/admin_access_attempt_log.dart';

import 'support/admin_test_harness.dart';

void main() {
  group('AdminDashboardScreen', () {
    testWidgets('renders the stat grid with the default seed counts',
        (tester) async {
      final harness = AdminTestHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.wrap(const AdminDashboardScreen()));
      await tester.pump(); // triggers the post-frame loadStats callback
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-dashboard-stats-grid')), findsOneWidget);
      expect(find.textContaining('Total users'), findsOneWidget);
      expect(find.textContaining('Admins'), findsOneWidget);
    });

    testWidgets(
        'full flow: sign in on AdminLoginScreen reaches the dashboard grid',
        (tester) async {
      final harness = AdminTestHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.wrap(const AdminGate()));
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
      final harness = AdminTestHarness();
      addTearDown(harness.dispose);

      // Tall virtual screen so the attempts section (below the stat grid)
      // is actually built — ListView is lazy and won't build off-screen
      // children at the default test viewport size.
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Recorded directly against the harness's mock (rather than driven
      // through a full rejected sign-in) to test the screen's rendering in
      // isolation from the auth flow, which `admin_auth_controller_test.dart`
      // already covers. An existence check, not an exact count, so this
      // doesn't depend on whether other tests in this file ran first.
      await harness.accessAttemptLogRepository.recordAttempt(
        AdminAccessAttemptLog(
          logId: 'test-attempt-1',
          attemptedUserId: 'user-101',
          attemptedEmail: 'alice.tan@example.com',
          reason: AdminAccessAttemptReason.notAnAdmin,
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(harness.wrap(const AdminDashboardScreen()));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('alice.tan@example.com'), findsOneWidget);
      expect(find.textContaining('Not an administrator'), findsOneWidget);
    });

    testWidgets('tapping the Suspended card opens the user list filtered '
        'to suspended users only', (tester) async {
      final harness = AdminTestHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.wrap(const AdminDashboardScreen()));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin-stat-suspended')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminUserListScreen), findsOneWidget);
      expect(find.text('Suspended Users'), findsWidgets); // AppBar + chip
      expect(find.text('Chong Mei Ling'), findsOneWidget);
      expect(find.text('Alice Tan'), findsNothing);
    });

    testWidgets('tapping the Admins card opens the user list filtered to '
        'administrators only', (tester) async {
      final harness = AdminTestHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.wrap(const AdminDashboardScreen()));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin-stat-admins')));
      await tester.pumpAndSettle();

      expect(find.text('Admin Account'), findsOneWidget);
      expect(find.text('Alice Tan'), findsNothing);
    });

    testWidgets('tapping the New this week card opens the user list '
        'filtered to recently created profiles', (tester) async {
      final harness = AdminTestHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.wrap(const AdminDashboardScreen()));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin-stat-new-this-week')));
      await tester.pumpAndSettle();

      expect(find.text('Alice Tan'), findsOneWidget);
      expect(find.text('Farah Aziz'), findsOneWidget);
      expect(find.text('Chong Mei Ling'), findsNothing);
    });

    testWidgets('tapping the Total users card opens the user list '
        'unfiltered', (tester) async {
      final harness = AdminTestHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.wrap(const AdminDashboardScreen()));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin-stat-total-users')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-user-filter-chip')), findsNothing);
      expect(find.text('Alice Tan'), findsOneWidget);
      expect(find.text('Chong Mei Ling'), findsOneWidget);
    });

    testWidgets('tapping the Issue reports action opens the issue report '
        'list', (tester) async {
      final harness = AdminTestHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.wrap(const AdminDashboardScreen()));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin-issue-reports')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminIssueReportListScreen), findsOneWidget);
    });

    testWidgets('tapping the Audit log action opens the audit log screen',
        (tester) async {
      final harness = AdminTestHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.wrap(const AdminDashboardScreen()));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin-audit-log')));
      await tester.pumpAndSettle();

      expect(find.byType(AuditLogScreen), findsOneWidget);
    });

    testWidgets('tapping an access attempt with a matching profile opens '
        'that user\'s detail screen', (tester) async {
      final harness = AdminTestHarness();
      addTearDown(harness.dispose);

      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await harness.accessAttemptLogRepository.recordAttempt(AdminAccessAttemptLog(
        logId: 'access-attempt-test-reviewable',
        attemptedUserId: 'user-101', // seeded as Alice Tan
        attemptedEmail: 'alice.tan@example.com',
        reason: AdminAccessAttemptReason.notAnAdmin,
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(
        harness.wrap(
          AdminDashboardScreen(
            userDetailScreenBuilder: (userId) => AdminUserDetailScreen(
              userId: userId,
              controller: harness.userDetailController(),
              accountActionsRepository: harness.accountActionsRepository,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin-access-attempt-access-attempt-test-reviewable')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminUserDetailScreen), findsOneWidget);
      expect(find.text('Alice Tan'), findsOneWidget);
    });

    testWidgets('an access attempt with no matching profile is not '
        'tappable', (tester) async {
      final harness = AdminTestHarness();
      addTearDown(harness.dispose);

      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await harness.accessAttemptLogRepository.recordAttempt(AdminAccessAttemptLog(
        logId: 'access-attempt-test-unreviewable',
        attemptedUserId: 'no-such-user-id',
        attemptedEmail: 'ghost@example.com',
        reason: AdminAccessAttemptReason.noProfileFound,
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(harness.wrap(const AdminDashboardScreen()));
      await tester.pump();
      await tester.pumpAndSettle();

      final tile = tester.widget<ListTile>(
        find.byKey(const Key('admin-access-attempt-access-attempt-test-unreviewable')),
      );
      expect(tile.onTap, isNull);
      expect(tile.trailing, isNull);
    });
  });
}
