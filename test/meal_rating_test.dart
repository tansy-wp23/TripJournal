import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/widgets/health_log_form.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';

void main() {
  Future<HealthLogFormData?> pumpForm(
    WidgetTester tester, {
    List<Meal> initialMeals = const [],
  }) async {
    HealthLogFormData? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HealthLogForm(
            tripId: 'trip-001',
            entryDate: DateTime(2026, 1, 1),
            initialMeals: initialMeals,
            onChanged: (data) => latest = data,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return latest;
  }

  testWidgets('a new meal has no rating until a star is tapped', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.tap(find.byKey(const Key('add-meal-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('meal-name-field')), 'Ramen');
    await tester.tap(find.byKey(const Key('confirm-meal-button')));
    await tester.pumpAndSettle();

    // No rating row shown for an unrated meal.
    expect(find.byKey(const Key('meal-row-rating-0')), findsNothing);
  });

  testWidgets('tapping the 4th star rates the meal 4/5', (tester) async {
    HealthLogFormData? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HealthLogForm(
            tripId: 'trip-001',
            entryDate: DateTime(2026, 1, 1),
            onChanged: (data) => latest = data,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-meal-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('meal-name-field')), 'Ramen');
    await tester.ensureVisible(find.byKey(const Key('meal-rating-star-4')));
    await tester.tap(find.byKey(const Key('meal-rating-star-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-meal-button')));
    await tester.pumpAndSettle();

    expect(latest!.meals.single.rating, 4);
  });

  testWidgets('tapping the currently-selected star clears the rating', (
    tester,
  ) async {
    HealthLogFormData? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HealthLogForm(
            tripId: 'trip-001',
            entryDate: DateTime(2026, 1, 1),
            onChanged: (data) => latest = data,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-meal-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('meal-name-field')), 'Ramen');
    await tester.ensureVisible(find.byKey(const Key('meal-rating-star-3')));
    await tester.tap(find.byKey(const Key('meal-rating-star-3')));
    await tester.pumpAndSettle();
    // Tap the same star again — a mis-tap should be fixable.
    await tester.tap(find.byKey(const Key('meal-rating-star-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-meal-button')));
    await tester.pumpAndSettle();

    expect(latest!.meals.single.rating, isNull);
  });

  testWidgets(
    'editing a rated meal without touching the stars keeps the rating, '
    'and the row shows it',
    (tester) async {
      const rated = Meal(
        id: 'meal-rated',
        name: 'Char Kway Teow',
        calories: 500,
        mealType: MealType.dinner,
        rating: 5,
      );
      HealthLogFormData? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HealthLogForm(
              tripId: 'trip-001',
              entryDate: DateTime(2026, 1, 1),
              initialMeals: const [rated],
              onChanged: (data) => latest = data,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Read-only stars visible on the meal row for a rated meal.
      expect(find.byKey(const Key('meal-row-rating-0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('edit-meal-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-meal-button')));
      await tester.pumpAndSettle();

      // Confirming without tapping a star must preserve the pre-filled
      // rating, not reset it — proves the dialog actually read
      // initialMeal.rating rather than defaulting to null.
      expect(latest!.meals.single.rating, 5);
    },
  );
}
