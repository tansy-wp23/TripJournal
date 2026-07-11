import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/ai/daily_advice_service.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';
import 'package:tripjournal/models/mood.dart';

void main() {
  final service = MockDailyAdviceService();

  int totalCalories(List<Meal> meals) => meals.fold<int>(0, (sum, m) => sum + m.calories);

  group('food', () {
    test('no meals logged returns the "no meals" message', () async {
      final advice = await service.adviceFor(meals: const [], steps: 6000, mood: Mood.neutral);
      expect(advice, contains('No meals logged yet'));
    });

    test('low calorie total flags intake as low', () async {
      const meals = [Meal(id: 'm1', name: 'Toast', calories: 300, mealType: MealType.breakfast)];
      final advice = await service.adviceFor(
        meals: meals,
        steps: 6000,
        mood: Mood.neutral,
        caloriesEaten: totalCalories(meals),
      );
      expect(advice, contains('quite low for the day'));
    });

    test('high calorie total is reported neutrally, without any restrictive framing', () async {
      const meals = [
        Meal(id: 'm1', name: 'Big breakfast', calories: 900, mealType: MealType.breakfast),
        Meal(id: 'm2', name: 'Big lunch', calories: 900, mealType: MealType.lunch),
        Meal(id: 'm3', name: 'Big dinner', calories: 900, mealType: MealType.dinner),
      ];
      final advice = await service.adviceFor(
        meals: meals,
        steps: 6000,
        mood: Mood.neutral,
        caloriesEaten: totalCalories(meals),
      );
      expect(advice, contains('higher side'));
    });

    test('missing breakfast is flagged when calories are otherwise mid-range', () async {
      const meals = [
        Meal(id: 'm1', name: 'Lunch', calories: 700, mealType: MealType.lunch),
        Meal(id: 'm2', name: 'Dinner', calories: 700, mealType: MealType.dinner),
      ];
      final advice = await service.adviceFor(
        meals: meals,
        steps: 6000,
        mood: Mood.neutral,
        caloriesEaten: totalCalories(meals),
      );
      expect(advice, contains("breakfast wasn't logged"));
    });

    test('three or more snacks are flagged when breakfast is present', () async {
      // Kept within the 1200-2500 calorie band so the calorie-threshold
      // branches don't take priority over the snack-count check.
      const meals = [
        Meal(id: 'm1', name: 'Breakfast', calories: 400, mealType: MealType.breakfast),
        Meal(id: 'm2', name: 'Chips', calories: 300, mealType: MealType.snack),
        Meal(id: 'm3', name: 'Cookie', calories: 300, mealType: MealType.snack),
        Meal(id: 'm4', name: 'Soda', calories: 300, mealType: MealType.snack),
      ];
      final advice = await service.adviceFor(
        meals: meals,
        steps: 6000,
        mood: Mood.neutral,
        caloriesEaten: totalCalories(meals),
      );
      expect(advice, contains('snacks logged today'));
    });

    test('balanced day with breakfast and few snacks returns the default message', () async {
      const meals = [
        Meal(id: 'm1', name: 'Breakfast', calories: 400, mealType: MealType.breakfast),
        Meal(id: 'm2', name: 'Lunch', calories: 600, mealType: MealType.lunch),
        Meal(id: 'm3', name: 'Dinner', calories: 600, mealType: MealType.dinner),
      ];
      final advice = await service.adviceFor(
        meals: meals,
        steps: 6000,
        mood: Mood.neutral,
        caloriesEaten: totalCalories(meals),
      );
      expect(advice, contains('well-balanced'));
    });
  });

  group('steps', () {
    const balancedMeals = [
      Meal(id: 'm1', name: 'Breakfast', calories: 400, mealType: MealType.breakfast),
      Meal(id: 'm2', name: 'Lunch', calories: 600, mealType: MealType.lunch),
      Meal(id: 'm3', name: 'Dinner', calories: 600, mealType: MealType.dinner),
    ];

    test('low steps encourage light movement', () async {
      final advice = await service.adviceFor(
        meals: balancedMeals,
        steps: 1500,
        mood: Mood.neutral,
        caloriesEaten: totalCalories(balancedMeals),
      );
      expect(advice, contains('short walk'));
    });

    test('very high steps acknowledge activity and suggest rest/hydration', () async {
      final advice = await service.adviceFor(
        meals: balancedMeals,
        steps: 18000,
        mood: Mood.neutral,
        caloriesEaten: totalCalories(balancedMeals),
      );
      expect(advice, contains('rest up'));
      expect(advice, contains('hydrated'));
    });

    test('a normal step count triggers no steps-related sentence', () async {
      final advice = await service.adviceFor(
        meals: balancedMeals,
        steps: 6000,
        mood: Mood.neutral,
        caloriesEaten: totalCalories(balancedMeals),
      );
      expect(advice, isNot(contains('walk')));
      expect(advice, isNot(contains('hydrated')));
    });
  });

  group('mood', () {
    const balancedMeals = [
      Meal(id: 'm1', name: 'Breakfast', calories: 400, mealType: MealType.breakfast),
      Meal(id: 'm2', name: 'Lunch', calories: 600, mealType: MealType.lunch),
      Meal(id: 'm3', name: 'Dinner', calories: 600, mealType: MealType.dinner),
    ];

    test('a stressed mood suggests something restorative, gently', () async {
      final advice = await service.adviceFor(
        meals: balancedMeals,
        steps: 6000,
        mood: Mood.stressed,
        caloriesEaten: totalCalories(balancedMeals),
      );
      expect(advice, contains('might help'));
      expect(advice, isNot(contains('you should')));
      expect(advice, isNot(contains('diagnos')));
    });

    test('a tired mood suggests winding down / resting early', () async {
      final advice = await service.adviceFor(
        meals: balancedMeals,
        steps: 6000,
        mood: Mood.tired,
        caloriesEaten: totalCalories(balancedMeals),
      );
      expect(advice, contains('rest'));
    });

    test('mood takes priority over steps when both are notable', () async {
      // Very low steps AND stressed mood — the mood sentence should win the
      // "primary" slot, not the steps one.
      final advice = await service.adviceFor(
        meals: balancedMeals,
        steps: 500,
        mood: Mood.stressed,
        caloriesEaten: totalCalories(balancedMeals),
      );
      expect(advice, contains('stressed'));
    });

    test('a neutral/happy/excited mood adds no mood-specific sentence', () async {
      for (final mood in [Mood.neutral, Mood.happy, Mood.excited]) {
        final advice = await service.adviceFor(
          meals: balancedMeals,
          steps: 6000,
          mood: mood,
          caloriesEaten: totalCalories(balancedMeals),
        );
        expect(advice, contains('well-balanced')); // falls through to food only
      }
    });
  });

  group('holistic combination', () {
    test('combines a wellbeing sentence and a food sentence into one short paragraph', () async {
      const meals = [
        Meal(id: 'm1', name: 'Lunch', calories: 700, mealType: MealType.lunch),
        Meal(id: 'm2', name: 'Dinner', calories: 700, mealType: MealType.dinner),
      ];
      final advice = await service.adviceFor(
        meals: meals,
        steps: 6000,
        mood: Mood.tired,
        caloriesEaten: totalCalories(meals),
      );
      // Both the mood signal and the missing-breakfast food signal appear.
      expect(advice, contains('rest'));
      expect(advice, contains("breakfast wasn't logged"));
      // It's a paragraph (sentences joined by a space), not a bulleted list.
      expect(advice, isNot(contains('\n')));
      expect(advice, isNot(contains('•')));
    });
  });

  group('tone and safety constraints (must never appear anywhere)', () {
    const cases = <Map<String, Object?>>[
      {'meals': <Meal>[], 'steps': 500, 'mood': Mood.stressed},
      {
        'meals': [Meal(id: 'm1', name: 'Feast', calories: 3000, mealType: MealType.dinner)],
        'steps': 18000,
        'mood': Mood.tired,
      },
    ];

    test('never uses restrictive-eating or clinical/diagnostic language', () async {
      for (final c in cases) {
        final meals = c['meals'] as List<Meal>;
        final advice = await service.adviceFor(
          meals: meals,
          steps: c['steps'] as int,
          mood: c['mood'] as Mood,
          caloriesEaten: totalCalories(meals),
        );
        final lower = advice.toLowerCase();
        for (final forbidden in ['restrict', 'skip a meal', 'skip meals', 'make up for', 'diagnos', 'you must']) {
          expect(lower, isNot(contains(forbidden)), reason: 'advice: "$advice"');
        }
      }
    });
  });
}
