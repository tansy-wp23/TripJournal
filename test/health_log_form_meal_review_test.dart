import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/widgets/health_log_form.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';
import 'package:tripjournal/validation/meal_validation.dart';

void main() {
  Future<HealthLogFormData?> pumpForm(WidgetTester tester) async {
    HealthLogFormData? latest;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HealthLogForm(
          tripId: 'trip-001',
          entryDate: DateTime(2026, 1, 1),
          onChanged: (data) => latest = data,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return latest;
  }

  testWidgets(
    'leaving restaurant and review blank saves the meal with both null, not empty strings',
    (tester) async {
      HealthLogFormData? latest;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HealthLogForm(
            tripId: 'trip-001',
            entryDate: DateTime(2026, 1, 1),
            onChanged: (data) => latest = data,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-meal-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('meal-name-field')), 'Ramen');
      await tester.tap(find.byKey(const Key('confirm-meal-button')));
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      final meal = latest!.meals.single;
      expect(meal.restaurantName, isNull);
      expect(meal.foodReview, isNull);
    },
  );

  testWidgets(
    'typing beyond the review cap is refused by maxLength',
    (tester) async {
      await pumpForm(tester);

      await tester.tap(find.byKey(const Key('add-meal-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('meal-review-field')),
        'a' * (kMealReviewMaxLength + 50),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('meal-review-field')),
      );
      expect(field.controller!.text.length, kMealReviewMaxLength);
    },
  );

  testWidgets(
    'the meal row shows the restaurant name after the dialog closes',
    (tester) async {
      HealthLogFormData? latest;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HealthLogForm(
            tripId: 'trip-001',
            entryDate: DateTime(2026, 1, 1),
            onChanged: (data) => latest = data,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-meal-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('meal-name-field')), 'Ramen');
      await tester.enterText(
        find.byKey(const Key('meal-restaurant-field')),
        'Ichiran Gion',
      );
      await tester.enterText(
        find.byKey(const Key('meal-review-field')),
        'Rich broth.',
      );
      await tester.tap(find.byKey(const Key('confirm-meal-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('meal-row-restaurant-0')), findsOneWidget);
      expect(find.text('Ichiran Gion'), findsOneWidget);
      expect(find.byKey(const Key('meal-row-review-0')), findsOneWidget);
      expect(find.text('Rich broth.'), findsOneWidget);

      expect(latest!.meals.single.restaurantName, 'Ichiran Gion');
      expect(latest!.meals.single.foodReview, 'Rich broth.');
    },
  );

  testWidgets(
    'editing a meal pre-fills its restaurant and review',
    (tester) async {
      const seedMeal = Meal(
        id: 'meal-seed',
        name: 'Ramen',
        calories: 650,
        mealType: MealType.lunch,
        restaurantName: 'Ichiran Gion',
        foodReview: 'Rich broth.',
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HealthLogForm(
            tripId: 'trip-001',
            entryDate: DateTime(2026, 1, 1),
            initialMeals: const [seedMeal],
            onChanged: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit-meal-0')));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Ichiran Gion'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Rich broth.'), findsOneWidget);
    },
  );
}
