import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/admin_repository_locator.dart';
import 'package:tripjournal/features/admin/controller/admin_auth_controller.dart';
import 'package:tripjournal/features/admin/screens/admin_user_detail_screen.dart';
import 'package:tripjournal/models/admin_access_attempt_log.dart';
import 'package:tripjournal/models/admin_audit_log.dart';

void main() {
  // A tall virtual screen so the status-history/access-attempt sections
  // (below the profile header) are actually built — the content is a
  // ListView and won't build off-screen children at the default test
  // viewport size (see docs/admin/PROGRESS.md's note on the same issue in
  // admin_dashboard_screen_test.dart).
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // Suspend/Reactivate need ref.read(adminAuthControllerProvider) to know
  // which admin is acting, so these tests sign in against a real
  // ProviderContainer first (the mock always resolves to admin-001, per
  // admin_repository_locator.dart) and pump the widget tree against that
  // same container via UncontrolledProviderScope.
  Future<void> pumpSignedInDetailScreen(WidgetTester tester, String userId) async {
    useTallViewport(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(adminAuthControllerProvider.notifier).signInWithGoogle();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: AdminUserDetailScreen(userId: userId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AdminUserDetailScreen', () {
    testWidgets('shows the profile fields for a known user', (tester) async {
      useTallViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(home: AdminUserDetailScreen(userId: 'user-101')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Tan'), findsOneWidget);
      expect(find.text('alice.tan@example.com'), findsOneWidget);
      expect(find.text('Traveler'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('shows the administrator role for an admin profile',
        (tester) async {
      useTallViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(home: AdminUserDetailScreen(userId: 'admin-001')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Administrator'), findsOneWidget);
    });

    testWidgets('shows empty states when there is no history', (tester) async {
      useTallViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(home: AdminUserDetailScreen(userId: 'user-105')),
      );
      await tester.pumpAndSettle();

      expect(find.text('No status changes recorded.'), findsOneWidget);
      expect(find.text('No attempts recorded.'), findsOneWidget);
    });

    testWidgets('shows a recorded audit history entry', (tester) async {
      useTallViewport(tester);
      await adminAuditLogRepository.recordAction(
        AdminAuditLog(
          logId: 'test-audit-1',
          adminUserId: 'admin-001',
          targetType: AdminAuditTargetType.user,
          targetId: 'user-102',
          action: AdminAction.suspend,
          reason: 'Reported for spam',
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(home: AdminUserDetailScreen(userId: 'user-102')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suspended'), findsOneWidget);
      expect(find.textContaining('Reported for spam'), findsOneWidget);
    });

    testWidgets('shows a recorded access-attempt entry', (tester) async {
      useTallViewport(tester);
      await adminAccessAttemptLogRepository.recordAttempt(
        AdminAccessAttemptLog(
          logId: 'test-attempt-detail-1',
          attemptedUserId: 'user-103',
          attemptedEmail: 'mei.ling@example.com',
          reason: AdminAccessAttemptReason.notAnAdmin,
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(home: AdminUserDetailScreen(userId: 'user-103')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Not an administrator'), findsOneWidget);
    });

    testWidgets('an unknown user id shows an error with a retry button',
        (tester) async {
      useTallViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(home: AdminUserDetailScreen(userId: 'nonexistent-999')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-user-detail-retry')), findsOneWidget);
      expect(find.byKey(const Key('admin-user-detail-content')), findsNothing);
    });

    testWidgets('an administrator profile shows no Suspend/Reactivate '
        'button', (tester) async {
      await pumpSignedInDetailScreen(tester, 'admin-001');

      expect(find.byKey(const Key('admin-suspend-button')), findsNothing);
      expect(find.byKey(const Key('admin-reactivate-button')), findsNothing);
      expect(
        find.text("Administrator accounts can't be suspended from here."),
        findsOneWidget,
      );
    });

    testWidgets('a self-deactivated profile shows no Suspend/Reactivate '
        'button', (tester) async {
      await pumpSignedInDetailScreen(tester, 'user-104'); // David Wong, deactivated

      expect(find.byKey(const Key('admin-suspend-button')), findsNothing);
      expect(find.byKey(const Key('admin-reactivate-button')), findsNothing);
      expect(find.textContaining('deactivated by the user'), findsOneWidget);
    });

    testWidgets('cancelling the suspend dialog leaves the account active',
        (tester) async {
      await pumpSignedInDetailScreen(tester, 'user-102'); // Brandon Lee, active

      await tester.tap(find.byKey(const Key('admin-suspend-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-suspend-button')), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('suspending with a reason updates status, records an audit '
        'entry, and shows a confirmation', (tester) async {
      await pumpSignedInDetailScreen(tester, 'user-101'); // Alice Tan, active

      await tester.tap(find.byKey(const Key('admin-suspend-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('suspend-reason-field')),
        'Reported for harassment',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('suspend-confirm-button')));
      await tester.pumpAndSettle();

      // "Suspended" appears twice once this succeeds (the status chip and
      // the new audit-history entry's action label) — assert on the more
      // specific signals instead of the ambiguous text.
      expect(find.byKey(const Key('admin-reactivate-button')), findsOneWidget);
      expect(find.byKey(const Key('admin-suspend-button')), findsNothing);
      expect(find.textContaining('Reported for harassment'), findsOneWidget);
      expect(find.text('Alice Tan has been suspended.'), findsOneWidget);
    });

    testWidgets('reactivating a suspended account updates status and '
        'records an audit entry', (tester) async {
      await pumpSignedInDetailScreen(tester, 'user-103'); // Chong Mei Ling, suspended

      await tester.tap(find.byKey(const Key('admin-reactivate-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reactivate-confirm-button')));
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsOneWidget);
      expect(find.byKey(const Key('admin-suspend-button')), findsOneWidget);
      expect(find.text('Chong Mei Ling has been reactivated.'), findsOneWidget);
    });
  });
}
