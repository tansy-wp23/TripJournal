import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/admin_repository_locator.dart';
import 'package:tripjournal/data/current_user_id_provider.dart';
import 'package:tripjournal/features/admin/widgets/report_issue_button.dart';

void main() {
  group('ReportIssueButton', () {
    Widget wrap({CurrentUserIdProvider? userIdProvider}) => MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                ReportIssueButton(page: 'TestScreen', userIdProvider: userIdProvider),
              ],
            ),
          ),
        );

    testWidgets('tapping the button opens the report form', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.byKey(const Key('report-issue-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('report-issue-description-field')), findsOneWidget);
      expect(find.text('Reporting from: TestScreen'), findsOneWidget);
    });

    testWidgets('submitting with an empty description shows an error and '
        "doesn't submit", (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.byKey(const Key('report-issue-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('report-issue-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text('Please describe what went wrong.'), findsOneWidget);
      // The sheet stays open — no submission happened.
      expect(find.byKey(const Key('report-issue-description-field')), findsOneWidget);
    });

    testWidgets('cancel on a pristine, untouched form closes immediately, '
        'no discard prompt', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.byKey(const Key('report-issue-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Discard this report?'), findsNothing);
      expect(find.byKey(const Key('report-issue-description-field')), findsNothing);
    });

    testWidgets('cancel with a typed description prompts "Discard this '
        'report?" instead of closing immediately', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.byKey(const Key('report-issue-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('report-issue-description-field')),
        'This report should never be submitted.',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Discard this report?'), findsOneWidget);
      // Still open, blocked on the prompt — nothing submitted yet.
      expect(find.byKey(const Key('report-issue-description-field')), findsOneWidget);
    });

    testWidgets('"Keep editing" dismisses the prompt and leaves the typed '
        'description intact', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.byKey(const Key('report-issue-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('report-issue-description-field')),
        'Keep me around.',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-issue-keep-editing')));
      await tester.pumpAndSettle();

      expect(find.text('Discard this report?'), findsNothing);
      expect(find.widgetWithText(TextField, 'Keep me around.'), findsOneWidget);
    });

    testWidgets('"Discard" closes the form without submitting a report',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.byKey(const Key('report-issue-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('report-issue-description-field')),
        'This report should never be submitted.',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-issue-discard-confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('report-issue-description-field')), findsNothing);
      final reports = await issueReportRepository.getAllReports();
      expect(
        reports.any((r) => r.description == 'This report should never be submitted.'),
        isFalse,
      );
    });

    testWidgets('the system back gesture on a dirty form prompts the same '
        'discard confirmation', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.byKey(const Key('report-issue-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('report-issue-description-field')),
        'Back-gesture guard check.',
      );
      await tester.pump();

      // The bottom sheet has no app-bar back button for tester.pageBack()
      // to find, so drive the same path a system back gesture takes —
      // Navigator.maybePop, which is exactly what PopScope intercepts.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      await navigator.maybePop();
      await tester.pumpAndSettle();

      expect(find.text('Discard this report?'), findsOneWidget);
      // Still open — the back attempt was blocked pending the prompt.
      expect(find.byKey(const Key('report-issue-description-field')), findsOneWidget);
    });

    testWidgets('a filled-in description submits and creates a report an '
        'admin can see', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.byKey(const Key('report-issue-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('report-issue-description-field')),
        'The map pin is offset on TestScreen.',
      );
      await tester.tap(find.byKey(const Key('report-issue-submit-button')));
      await tester.pumpAndSettle();

      // Sheet closed, confirmation shown.
      expect(find.byKey(const Key('report-issue-description-field')), findsNothing);
      expect(find.textContaining('Thanks'), findsOneWidget);

      final reports = await issueReportRepository.getAllReports();
      final submitted =
          reports.where((r) => r.description == 'The map pin is offset on TestScreen.');
      expect(submitted, hasLength(1));
      expect(submitted.single.page, 'TestScreen');
    });

    testWidgets('an unauthenticated userIdProvider blocks submission with a '
        'visible error', (tester) async {
      await tester.pumpWidget(wrap(userIdProvider: _AlwaysUnauthenticated()));
      await tester.tap(find.byKey(const Key('report-issue-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('report-issue-description-field')),
        'This should not go through.',
      );
      await tester.tap(find.byKey(const Key('report-issue-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text(const UnauthenticatedTripUserException().toString()), findsOneWidget);
      final reports = await issueReportRepository.getAllReports();
      expect(
        reports.any((r) => r.description == 'This should not go through.'),
        isFalse,
      );
    });
  });
}

class _AlwaysUnauthenticated implements CurrentUserIdProvider {
  @override
  String requireUserId() => throw const UnauthenticatedTripUserException();
}
