import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/health/health_data_source.dart';
import 'package:tripjournal/features/journal/screens/create_edit_entry_screen.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

class _FakeHealthDataSource implements HealthDataSource {
  _FakeHealthDataSource({this.hasPermissionsResult = false, this.steps, this.caloriesBurned});

  bool hasPermissionsResult;
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
    return true;
  }

  @override
  Future<int?> getStepsForDate(DateTime date) async => steps;

  @override
  Future<int?> getCaloriesBurnedForDate(DateTime date) async => caloriesBurned;
}

JournalEntry _existingEntry() => JournalEntry(
  id: 'entry-prefill-test',
  tripId: 'trip-001',
  title: 'Already saved',
  body: 'Body',
  mood: Mood.neutral,
  photoPaths: const [],
  createdAt: DateTime(2026, 4, 10),
  updatedAt: DateTime(2026, 4, 10),
);

void main() {
  group('Automatic health prefill on a new entry (IMPLEMENTATION_PLAN_HEALTH.md §5, §7)', () {
    testWidgets('already granted: silently fills steps/calories, no permission request', (tester) async {
      final fake = _FakeHealthDataSource(hasPermissionsResult: true, steps: 6000, caloriesBurned: 1900);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: CreateEditEntryScreen(initialDate: DateTime(2026, 4, 10), healthDataSource: fake),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, '6000'), findsOneWidget);
      expect(find.widgetWithText(TextField, '1900'), findsOneWidget);
      expect(find.byKey(const Key('steps-from-health-hint')), findsOneWidget);
      expect(fake.requestPermissionsCalls, 0); // never auto-requested — check only
    });

    testWidgets('not granted: never auto-requests permission, and shows the connect note', (tester) async {
      final fake = _FakeHealthDataSource(hasPermissionsResult: false);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: CreateEditEntryScreen(initialDate: DateTime(2026, 4, 10), healthDataSource: fake),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fake.hasPermissionsCalls, 1);
      expect(fake.requestPermissionsCalls, 0); // no cold-open OS prompt
      expect(find.text('Connect a health app to auto-fill steps and calories.'), findsOneWidget);
      expect(find.widgetWithText(TextField, '0'), findsOneWidget); // steps stays at manual-entry default
    });

    testWidgets('granted but no data for the day: fields stay at manual defaults, not overwritten with 0', (
      tester,
    ) async {
      final fake = _FakeHealthDataSource(hasPermissionsResult: true, steps: null, caloriesBurned: null);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: CreateEditEntryScreen(initialDate: DateTime(2026, 4, 10), healthDataSource: fake),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, '0'), findsOneWidget);
      expect(find.byKey(const Key('steps-from-health-hint')), findsNothing);
      expect(find.byKey(const Key('calories-from-health-hint')), findsNothing);
    });
  });

  testWidgets('editing an existing entry never runs the auto-prefill — no permission check at all', (
    tester,
  ) async {
    final fake = _FakeHealthDataSource(hasPermissionsResult: true, steps: 9999, caloriesBurned: 3000);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CreateEditEntryScreen(existingEntry: _existingEntry(), healthDataSource: fake),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(fake.hasPermissionsCalls, 0);
    expect(find.widgetWithText(TextField, '9999'), findsNothing);
    expect(find.byKey(const Key('steps-from-health-hint')), findsNothing);
  });
}
