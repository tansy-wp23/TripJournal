import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/widgets/health_log_form.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';

void main() {
  const seedMeal = Meal(id: 'meal-seed', name: 'Ramen', calories: 650, mealType: MealType.lunch);

  Future<HealthLogFormData?> pumpForm(WidgetTester tester) async {
    HealthLogFormData? latest;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HealthLogForm(
          entryDate: DateTime(2026, 1, 1),
          initialMeals: const [seedMeal],
          onChanged: (data) => latest = data,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return latest;
  }

  testWidgets('tapping edit on a meal row pre-fills the dialog with its current values', (tester) async {
    await pumpForm(tester);

    await tester.tap(find.byKey(const Key('edit-meal-0')));
    await tester.pumpAndSettle();

    expect(find.text('Edit meal'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Ramen'), findsOneWidget);
    expect(find.widgetWithText(TextField, '650'), findsOneWidget);
  });

  testWidgets('editing a meal updates it in place, preserving id, without adding a new row', (tester) async {
    HealthLogFormData? latest;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HealthLogForm(
          entryDate: DateTime(2026, 1, 1),
          initialMeals: const [seedMeal],
          onChanged: (data) => latest = data,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-meal-0')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('meal-calories-field')), '900');
    await tester.tap(find.byKey(const Key('confirm-meal-button')));
    await tester.pumpAndSettle();

    // Still exactly one meal row — edited in place, not appended.
    expect(find.byKey(const Key('meal-row-0')), findsOneWidget);
    expect(find.byKey(const Key('meal-row-1')), findsNothing);
    expect(find.text('Total calories eaten: ~900 kcal'), findsOneWidget);

    expect(latest, isNotNull);
    expect(latest!.meals.single.id, 'meal-seed'); // id preserved across the edit
    expect(latest!.meals.single.calories, 900);
    expect(latest!.meals.single.name, 'Ramen');
  });

  testWidgets('tapping a meal row (not just the edit icon) also opens the edit dialog', (tester) async {
    await pumpForm(tester);

    await tester.tap(find.byKey(const Key('meal-row-0')));
    await tester.pumpAndSettle();

    expect(find.text('Edit meal'), findsOneWidget);
  });
}
