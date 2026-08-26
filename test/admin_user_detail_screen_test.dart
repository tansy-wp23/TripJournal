import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/screens/admin_user_detail_screen.dart';
import 'package:tripjournal/models/admin_access_attempt_log.dart';
import 'package:tripjournal/models/admin_audit_log.dart';

import 'support/admin_test_harness.dart';

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

  // Builds a fresh AdminTestHarness (mocks, isolated per test — see
  // AdminTestHarness's doc comment for why this is needed once
  // admin_repository_locator.dart is wired to the real Supabase backend,
  // Phase 7/14) and pumps AdminUserDetailScreen against it, with its
  // controller and account-actions repository injected directly (the
  // screen constructs its controller locally rather than resolving one
  // from a global provider — see AdminUserDetailScreen's doc comment).
  Future<AdminTestHarness> pumpDetailScreen(
    WidgetTester tester,
    String userId, {
    bool signedIn = false,
  }) async {
    useTallViewport(tester);
    final harness = AdminTestHarness();
    addTearDown(harness.dispose);
    if (signedIn) {
      await harness.signIn();
    }

    await tester.pumpWidget(
      harness.wrap(
        AdminUserDetailScreen(
          userId: userId,
          controller: harness.userDetailController(),
          accountActionsRepository: harness.accountActionsRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return harness;
  }

  // Suspend/Reactivate need ref.read(adminAuthControllerProvider) to know
  // which admin is acting, so these tests additionally sign in first.
  Future<AdminTestHarness> pumpSignedInDetailScreen(
    WidgetTester tester,
    String userId,
  ) => pumpDetailScreen(tester, userId, signedIn: true);

  group('AdminUserDetailScreen', () {
    testWidgets('shows the profile fields for a known user', (tester) async {
      await pumpDetailScreen(tester, 'user-101');

      expect(find.text('Alice Tan'), findsOneWidget);
      expect(find.text('alice.tan@example.com'), findsOneWidget);
      expect(find.text('Traveler'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('shows the administrator role for an admin profile',
        (tester) async {
      await pumpDetailScreen(tester, 'admin-001');

      expect(find.text('Administrator'), findsOneWidget);
    });

    testWidgets('shows empty states when there is no history', (tester) async {
      await pumpDetailScreen(tester, 'user-105');

      expect(find.text('No status changes recorded.'), findsOneWidget);
      expect(find.text('No attempts recorded.'), findsOneWidget);
    });

    testWidgets('shows a recorded audit history entry', (tester) async {
      useTallViewport(tester);
      final harness = AdminTestHarness();
      addTearDown(harness.dispose);
      await harness.auditLogRepository.recordAction(
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
        harness.wrap(
          AdminUserDetailScreen(
            userId: 'user-102',
            controller: harness.userDetailController(),
            accountActionsRepository: harness.accountActionsRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suspended'), findsOneWidget);
      expect(find.textContaining('Reported for spam'), findsOneWidget);
    });

    testWidgets('shows a recorded access-attempt entry', (tester) async {
      useTallViewport(tester);
      final harness = AdminTestHarness();
      addTearDown(harness.dispose);
      await harness.accessAttemptLogRepository.recordAttempt(
        AdminAccessAttemptLog(
          logId: 'test-attempt-detail-1',
          attemptedUserId: 'user-103',
          attemptedEmail: 'mei.ling@example.com',
          reason: AdminAccessAttemptReason.notAnAdmin,
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        harness.wrap(
          AdminUserDetailScreen(
            userId: 'user-103',
            controller: harness.userDetailController(),
            accountActionsRepository: harness.accountActionsRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Not an administrator'), findsOneWidget);
    });

    testWidgets('an unknown user id shows an error with a retry button',
        (tester) async {
      await pumpDetailScreen(tester, 'nonexistent-999');

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
