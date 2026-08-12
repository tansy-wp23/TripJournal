import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/admin_repository_locator.dart';
import 'package:tripjournal/features/admin/controller/admin_auth_controller.dart';
import 'package:tripjournal/features/admin/screens/issue_report_detail_screen.dart';
import 'package:tripjournal/features/journal/widgets/photo_thumbnail.dart';
import 'package:tripjournal/models/issue_report.dart';

void main() {
  // A tall virtual screen so the status-control/status-history sections
  // (below the description) are actually built — the content is a
  // ListView and won't build off-screen children at the default test
  // viewport size (same issue noted in admin_user_detail_screen_test.dart).
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // The status buttons need ref.read(adminAuthControllerProvider) to know
  // which admin is acting, so these tests sign in against a real
  // ProviderContainer first (mirrors pumpSignedInDetailScreen in
  // admin_user_detail_screen_test.dart).
  Future<void> pumpSignedInDetailScreen(WidgetTester tester, String reportId) async {
    useTallViewport(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(adminAuthControllerProvider.notifier).signInWithGoogle();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: IssueReportDetailScreen(reportId: reportId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<String> submitThrowawayReport(String description, {String? screenshotUrl}) async {
    await issueReportRepository.submitReport(
      userId: 'user-101',
      page: 'HomeScreen',
      description: description,
      screenshotUrl: screenshotUrl,
    );
    final all = await issueReportRepository.getAllReports();
    return all.firstWhere((r) => r.description == description).reportId;
  }

  group('IssueReportDetailScreen', () {
    testWidgets('shows the report fields for a known report', (tester) async {
      useTallViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(home: IssueReportDetailScreen(reportId: 'issue-001')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Cover photo fails to upload when offline.'),
        findsOneWidget,
      );
      expect(find.text('TripViewScreen'), findsOneWidget);
      // "Open" appears in both the status chip and the (disabled)
      // current-status button.
      expect(find.text('Open'), findsWidgets);
      expect(
        find.text('Submitted by Alice Tan (alice.tan@example.com)'),
        findsOneWidget,
      );
    });

    testWidgets('a submitter with no matching profile shows an unknown-user '
        'message, not a crash', (tester) async {
      useTallViewport(tester);
      await issueReportRepository.submitReport(
        userId: 'deleted-user-999',
        page: 'HomeScreen',
        description: 'Filed by a since-deleted account.',
      );
      final reportId = (await issueReportRepository.getAllReports())
          .firstWhere((r) => r.submittedByUserId == 'deleted-user-999')
          .reportId;

      await tester.pumpWidget(
        MaterialApp(home: IssueReportDetailScreen(reportId: reportId)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('unknown user'), findsOneWidget);
    });

    testWidgets('shows a photo thumbnail when the report has an attachment',
        (tester) async {
      useTallViewport(tester);
      final reportId = await submitThrowawayReport(
        'Broken layout with a photo attached.',
        screenshotUrl: 'C:/fake/does-not-exist.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(home: IssueReportDetailScreen(reportId: reportId)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PhotoThumbnail), findsOneWidget);
    });

    testWidgets('no photo attachment shows no thumbnail', (tester) async {
      useTallViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(home: IssueReportDetailScreen(reportId: 'issue-001')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PhotoThumbnail), findsNothing);
    });

    testWidgets('shows an empty status history state when nothing has been '
        'recorded yet', (tester) async {
      final reportId = await submitThrowawayReport('Fresh report, never touched.');

      useTallViewport(tester);
      await tester.pumpWidget(
        MaterialApp(home: IssueReportDetailScreen(reportId: reportId)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No status changes recorded.'), findsOneWidget);
    });

    testWidgets('shows a recorded status-history entry', (tester) async {
      final reportId = await submitThrowawayReport('Needs a status change recorded.');
      await issueReportRepository.updateStatus(
        adminUserId: 'admin-001',
        reportId: reportId,
        status: IssueReportStatus.inProgress,
        remarks: 'Investigating now.',
      );

      useTallViewport(tester);
      await tester.pumpWidget(
        MaterialApp(home: IssueReportDetailScreen(reportId: reportId)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Marked In Progress'), findsOneWidget);
      // The remarks field also carries the same text forward after the
      // reload, so this matches both the audit tile and the text field.
      expect(find.textContaining('Investigating now.'), findsWidgets);
    });

    testWidgets('an unknown report id shows an error with a retry button',
        (tester) async {
      useTallViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(home: IssueReportDetailScreen(reportId: 'nonexistent-999')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-issue-detail-retry')), findsOneWidget);
      expect(find.byKey(const Key('admin-issue-detail-content')), findsNothing);
    });

    testWidgets('the button matching the current status is disabled',
        (tester) async {
      final reportId = await submitThrowawayReport('Disabled-current-status check.');

      await pumpSignedInDetailScreen(tester, reportId);

      // Exactly one FilledButton on this screen in this state — the
      // current-status control (disabled); everything else is an
      // OutlinedButton (the other two status options).
      final filledButtons = tester.widgetList<FilledButton>(find.byType(FilledButton));
      expect(filledButtons, hasLength(1));
      expect(filledButtons.single.onPressed, isNull);
      expect(find.byKey(const Key('admin-issue-set-status-inProgress')), findsOneWidget);
      expect(find.byKey(const Key('admin-issue-set-status-resolved')), findsOneWidget);
    });

    testWidgets('selecting a new status updates it, records an audit entry, '
        'and shows a confirmation', (tester) async {
      final reportId = await submitThrowawayReport('Should move to In Progress.');

      await pumpSignedInDetailScreen(tester, reportId);

      await tester.enterText(
        find.byKey(const Key('admin-issue-remarks-field')),
        'Taking a look.',
      );
      await tester.tap(find.byKey(const Key('admin-issue-set-status-inProgress')));
      await tester.pumpAndSettle();

      expect(find.text('Marked as In Progress.'), findsOneWidget);
      expect(find.text('Marked In Progress'), findsOneWidget); // history entry
      expect(find.textContaining('Taking a look.'), findsWidgets);
      expect(find.byKey(const Key('admin-issue-set-status-open')), findsOneWidget);
      expect(find.byKey(const Key('admin-issue-set-status-resolved')), findsOneWidget);
    });

    testWidgets('reopening a resolved report requires a remark, then records '
        'issueReopen', (tester) async {
      final reportId = await submitThrowawayReport('Resolved then reopened.');
      await issueReportRepository.updateStatus(
        adminUserId: 'admin-001',
        reportId: reportId,
        status: IssueReportStatus.resolved,
      );

      await pumpSignedInDetailScreen(tester, reportId);

      await tester.tap(find.byKey(const Key('admin-issue-set-status-open')));
      await tester.pumpAndSettle();

      // The status hasn't changed yet — the dialog is blocking, and its
      // confirm button is disabled until a remark is entered.
      expect(find.text('Marked as Open.'), findsNothing);
      final confirmButton = tester.widget<FilledButton>(
        find.byKey(const Key('leaving-resolved-remark-confirm-button')),
      );
      expect(confirmButton.onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('leaving-resolved-remark-field')),
        'Recurred after being closed.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('leaving-resolved-remark-confirm-button')));
      await tester.pumpAndSettle();

      expect(find.text('Marked as Open.'), findsOneWidget);
      expect(find.text('Reopened'), findsOneWidget);
      expect(find.textContaining('Recurred after being closed.'), findsWidgets);
    });

    testWidgets('cancelling the leaving-resolved dialog leaves the report '
        'status unchanged', (tester) async {
      final reportId = await submitThrowawayReport('Resolved then cancel-reopened.');
      await issueReportRepository.updateStatus(
        adminUserId: 'admin-001',
        reportId: reportId,
        status: IssueReportStatus.resolved,
      );

      await pumpSignedInDetailScreen(tester, reportId);

      await tester.tap(find.byKey(const Key('admin-issue-set-status-inProgress')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Marked as In Progress.'), findsNothing);
      // Still on "Resolved" — that button is the disabled (current-status)
      // one, so the other two remain tappable outline buttons.
      expect(find.byKey(const Key('admin-issue-set-status-open')), findsOneWidget);
      expect(find.byKey(const Key('admin-issue-set-status-inProgress')), findsOneWidget);

      final report = await issueReportRepository.getReportById(reportId);
      expect(report!.status, IssueReportStatus.resolved);
    });

    testWidgets('moving Resolved down to In Progress also requires a remark',
        (tester) async {
      final reportId = await submitThrowawayReport('Resolved then downgraded.');
      await issueReportRepository.updateStatus(
        adminUserId: 'admin-001',
        reportId: reportId,
        status: IssueReportStatus.resolved,
      );

      await pumpSignedInDetailScreen(tester, reportId);

      await tester.tap(find.byKey(const Key('admin-issue-set-status-inProgress')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('leaving-resolved-remark-field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('leaving-resolved-remark-field')),
        'Still needs more work.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('leaving-resolved-remark-confirm-button')));
      await tester.pumpAndSettle();

      expect(find.text('Marked as In Progress.'), findsOneWidget);
    });

    testWidgets('the leaving-resolved dialog is pre-filled from the '
        'persistent remarks field and not shown for forward transitions',
        (tester) async {
      final reportId = await submitThrowawayReport('Pre-filled remark check.');

      await pumpSignedInDetailScreen(tester, reportId);

      // Open -> In Progress is a forward transition — no dialog, remarks
      // field stays optional as before.
      await tester.tap(find.byKey(const Key('admin-issue-set-status-inProgress')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('leaving-resolved-remark-field')), findsNothing);
      expect(find.text('Marked as In Progress.'), findsOneWidget);

      // In Progress -> Resolved is also forward — still no dialog. (Not
      // asserting a second "Marked as ..." snackbar here — the first one's
      // default-duration timer can still be pending, so a stacked
      // ScaffoldMessenger call queues behind it rather than showing
      // immediately; the repository check below is the reliable signal.)
      await tester.enterText(
        find.byKey(const Key('admin-issue-remarks-field')),
        'Fixed in the latest build.',
      );
      await tester.tap(find.byKey(const Key('admin-issue-set-status-resolved')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('leaving-resolved-remark-field')), findsNothing);
      final resolvedReport = await issueReportRepository.getReportById(reportId);
      expect(resolvedReport!.status, IssueReportStatus.resolved);

      // Now Resolved -> Open should prefill the dialog from that same text.
      // (The persistent remarks field behind the dialog carries the same
      // text too, so scope the check to the dialog's own field by key.)
      await tester.tap(find.byKey(const Key('admin-issue-set-status-open')));
      await tester.pumpAndSettle();
      final dialogField = tester.widget<TextField>(
        find.byKey(const Key('leaving-resolved-remark-field')),
      );
      expect(dialogField.controller!.text, 'Fixed in the latest build.');
    });
  });
}
