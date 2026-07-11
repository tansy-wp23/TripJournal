import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/health/health_data_source.dart';
import 'package:tripjournal/features/journal/widgets/health_log_form.dart';

/// Full control over permission/data outcomes — unlike `MockHealthDataSource`
/// (always granted, always returns fixed values), this lets these tests
/// exercise the denied/no-data paths required by IMPLEMENTATION_PLAN_
/// HEALTH.md §7 ("UI: null steps/calories -> field stays empty...").
class _FakeHealthDataSource implements HealthDataSource {
  _FakeHealthDataSource({
    this.hasPermissionsResult = false,
    this.requestPermissionsResult = false,
    this.steps,
    this.caloriesBurned,
  });

  bool hasPermissionsResult;
  bool requestPermissionsResult;
  int? steps;
  int? caloriesBurned;

  int hasPermissionsCalls = 0;
  int requestPermissionsCalls = 0;

  @override
  Future<bool> hasPermissions() async {
    hasPermissionsCalls++;
    return hasPermissionsResult;
  }

  @override
  Future<bool> requestPermissions() async {
    requestPermissionsCalls++;
    return requestPermissionsResult;
  }

  @override
  Future<int?> getStepsForDate(DateTime date) async => steps;

  @override
  Future<int?> getCaloriesBurnedForDate(DateTime date) async => caloriesBurned;
}

void main() {
  Future<void> pumpForm(
    WidgetTester tester,
    HealthDataSource healthDataSource, {
    bool initialShowConnectHealthNote = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HealthLogForm(
            entryDate: DateTime(2026, 4, 10),
            initialShowConnectHealthNote: initialShowConnectHealthNote,
            healthDataSource: healthDataSource,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Sync from health app (IMPLEMENTATION_PLAN_HEALTH.md §5, §7)', () {
    testWidgets('already granted: tapping Sync pulls values, fills fields, and shows the synced hint', (
      tester,
    ) async {
      final fake = _FakeHealthDataSource(hasPermissionsResult: true, steps: 8342, caloriesBurned: 2100);
      await pumpForm(tester, fake);

      await tester.tap(find.byKey(const Key('sync-health-button')));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, '8342'), findsOneWidget);
      expect(find.widgetWithText(TextField, '2100'), findsOneWidget);
      expect(find.byKey(const Key('steps-from-health-hint')), findsOneWidget);
      expect(find.byKey(const Key('calories-from-health-hint')), findsOneWidget);
      expect(fake.requestPermissionsCalls, 0); // already granted — never asked again
    });

    testWidgets('editing a synced field by hand clears just that field\'s hint', (tester) async {
      final fake = _FakeHealthDataSource(hasPermissionsResult: true, steps: 8342, caloriesBurned: 2100);
      await pumpForm(tester, fake);

      await tester.tap(find.byKey(const Key('sync-health-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('health-log-steps-field')), '9000');
      await tester.pump();

      expect(find.byKey(const Key('steps-from-health-hint')), findsNothing);
      expect(find.byKey(const Key('calories-from-health-hint')), findsOneWidget); // untouched, still synced
    });

    testWidgets('not yet granted: tapping Sync explains why before requesting permission', (tester) async {
      final fake = _FakeHealthDataSource(hasPermissionsResult: false, requestPermissionsResult: true, steps: 500);
      await pumpForm(tester, fake);

      await tester.tap(find.byKey(const Key('sync-health-button')));
      await tester.pumpAndSettle();

      expect(find.text('Connect a health app?'), findsOneWidget);
      expect(fake.requestPermissionsCalls, 0); // not yet — waiting on the user's Continue tap

      await tester.tap(find.byKey(const Key('health-permission-continue')));
      await tester.pumpAndSettle();

      expect(fake.requestPermissionsCalls, 1);
      expect(find.widgetWithText(TextField, '500'), findsOneWidget);
    });

    testWidgets('"Not now" on the explanation dialog leaves the form untouched, no permission requested', (
      tester,
    ) async {
      final fake = _FakeHealthDataSource(hasPermissionsResult: false);
      await pumpForm(tester, fake);

      await tester.tap(find.byKey(const Key('sync-health-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('health-permission-cancel')));
      await tester.pumpAndSettle();

      expect(fake.requestPermissionsCalls, 0);
      expect(find.byKey(const Key('steps-from-health-hint')), findsNothing);
    });

    testWidgets('permission denied after asking shows the connect note and a snackbar, never blocks entry', (
      tester,
    ) async {
      final fake = _FakeHealthDataSource(hasPermissionsResult: false, requestPermissionsResult: false);
      await pumpForm(tester, fake);

      await tester.tap(find.byKey(const Key('sync-health-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('health-permission-continue')));
      await tester.pumpAndSettle();

      expect(find.text('Connect a health app to auto-fill steps and calories.'), findsOneWidget);
      expect(find.text('Permission denied — you can still enter steps and calories manually.'), findsOneWidget);

      // Manual entry still fully works.
      await tester.enterText(find.byKey(const Key('health-log-steps-field')), '4000');
      await tester.pump();
      expect(find.widgetWithText(TextField, '4000'), findsOneWidget);
    });

    testWidgets('granted but no data for the day: fields stay empty/untouched, not overwritten with 0', (
      tester,
    ) async {
      final fake = _FakeHealthDataSource(hasPermissionsResult: true, steps: null, caloriesBurned: null);
      await pumpForm(tester, fake);

      await tester.tap(find.byKey(const Key('sync-health-button')));
      await tester.pumpAndSettle();

      expect(find.text('No health data found for this day.'), findsOneWidget);
      expect(find.widgetWithText(TextField, '0'), findsOneWidget); // steps field untouched at its default
      expect(find.byKey(const Key('steps-from-health-hint')), findsNothing);
      expect(find.byKey(const Key('calories-from-health-hint')), findsNothing);
    });

    testWidgets('the connect-health note can be dismissed independently of syncing', (tester) async {
      await pumpForm(tester, _FakeHealthDataSource(), initialShowConnectHealthNote: true);

      expect(find.text('Connect a health app to auto-fill steps and calories.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('dismiss-connect-health-note')));
      await tester.pumpAndSettle();

      expect(find.text('Connect a health app to auto-fill steps and calories.'), findsNothing);
    });
  });
}
