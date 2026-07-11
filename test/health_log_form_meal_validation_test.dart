import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/widgets/health_log_form.dart';

Future<void> pumpForm(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: HealthLogForm(entryDate: DateTime(2026, 1, 1), onChanged: (_) {})),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('adding a meal with no name shows an inline error and does not add it', (tester) async {
    await pumpForm(tester);

    await tester.tap(find.byKey(const Key('add-meal-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('meal-calories-field')), '300');
    await tester.tap(find.byKey(const Key('confirm-meal-button')));
    await tester.pump();

    expect(find.text('Please enter a meal name.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget); // dialog stayed open — nothing was added
  });

  testWidgets('adding a meal with negative calories shows an inline error and does not add it', (tester) async {
    await pumpForm(tester);

    await tester.tap(find.byKey(const Key('add-meal-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('meal-name-field')), 'Bad snack');
    await tester.enterText(find.byKey(const Key('meal-calories-field')), '-50');
    await tester.tap(find.byKey(const Key('confirm-meal-button')));
    await tester.pump();

    expect(find.text('Please enter a valid number.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('leaving calories blank defaults to 0 without an error', (tester) async {
    await pumpForm(tester);

    await tester.tap(find.byKey(const Key('add-meal-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('meal-name-field')), 'Water');
    await tester.tap(find.byKey(const Key('confirm-meal-button')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing); // dialog closed — meal was added
    expect(find.text('Total calories eaten: ~0 kcal'), findsOneWidget);
  });

  testWidgets('a valid meal (name + non-negative calories) is added with no error', (tester) async {
    await pumpForm(tester);

    await tester.tap(find.byKey(const Key('add-meal-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('meal-name-field')), 'Ramen');
    await tester.enterText(find.byKey(const Key('meal-calories-field')), '650');
    await tester.tap(find.byKey(const Key('confirm-meal-button')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Total calories eaten: ~650 kcal'), findsOneWidget);
  });

  testWidgets('typing a negative step count shows a live inline warning', (tester) async {
    await pumpForm(tester);

    await tester.enterText(find.byKey(const Key('health-log-steps-field')), '-100');
    await tester.pump();

    expect(find.text('Please enter a valid number.'), findsOneWidget);
  });

  testWidgets('typing more than 100,000 steps shows the soft-cap warning', (tester) async {
    await pumpForm(tester);

    await tester.enterText(find.byKey(const Key('health-log-steps-field')), '100001');
    await tester.pump();

    expect(find.text('That step count seems unusually high — please check.'), findsOneWidget);
  });
}
