import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/ai/gemini_daily_advice_service.dart';
import 'package:tripjournal/features/journal/ai/gemini_function_invoker.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';
import 'package:tripjournal/models/mood.dart';

// Prompt wording and the tone/safety system instruction now live in the
// gemini-proxy Edge Function (and are covered by its Deno tests), because the
// API key does. What is left to test here is the client half: what this
// service sends, and how it treats what comes back.

Meal _meal({
  String name = 'Ramen',
  int calories = 600,
  MealType type = MealType.lunch,
  String? review,
}) {
  return Meal(
    id: 'meal-1',
    name: name,
    calories: calories,
    mealType: type,
    foodReview: review,
  );
}

void main() {
  test('sends the day as a daily_advice action and returns the advice', () async {
    String? seenAction;
    Map<String, dynamic>? seenBody;
    final service = GeminiDailyAdviceService(
      invoke: (action, body) async {
        seenAction = action;
        seenBody = body;
        return {'advice': 'A gentle, balanced day.'};
      },
    );

    final advice = await service.adviceFor(
      meals: [_meal(review: 'Rich broth')],
      steps: 8000,
      mood: Mood.happy,
      caloriesEaten: 1800,
      caloriesBurned: 500,
    );

    expect(advice, 'A gentle, balanced day.');
    expect(seenAction, 'daily_advice');
    expect(seenBody!['mood'], 'happy');
    expect(seenBody!['steps'], 8000);
    expect(seenBody!['caloriesEaten'], 1800);
    expect(seenBody!['caloriesBurned'], 500);

    final meals = seenBody!['meals'] as List;
    expect(meals, hasLength(1));
    expect(meals.single, {
      'name': 'Ramen',
      'mealType': 'lunch',
      'calories': 600,
      'foodReview': 'Rich broth',
    });
  });

  test('passes null figures through rather than inventing zeros', () async {
    Map<String, dynamic>? seenBody;
    final service = GeminiDailyAdviceService(
      invoke: (action, body) async {
        seenBody = body;
        return {'advice': 'ok'};
      },
    );

    await service.adviceFor(meals: const [], steps: null, mood: Mood.neutral);

    expect(seenBody!['steps'], isNull);
    expect(seenBody!['caloriesEaten'], isNull);
    expect(seenBody!['caloriesBurned'], isNull);
    expect(seenBody!['meals'], isEmpty);
  });

  test('trims surrounding whitespace from the returned advice', () async {
    final service = GeminiDailyAdviceService(
      invoke: (_, _) async => {'advice': '   Take it easy today.  \n'},
    );

    expect(
      await service.adviceFor(meals: const [], steps: 1, mood: Mood.neutral),
      'Take it easy today.',
    );
  });

  test('throws when the advice is missing or empty', () async {
    for (final payload in [
      <String, dynamic>{},
      <String, dynamic>{'advice': '   '},
      <String, dynamic>{'advice': 42},
    ]) {
      final service = GeminiDailyAdviceService(invoke: (_, _) async => payload);
      expect(
        () => service.adviceFor(meals: const [], steps: 1, mood: Mood.neutral),
        throwsA(isA<GeminiProxyException>()),
        reason: 'payload: $payload',
      );
    }
  });

  test('lets a proxy failure surface so the caller can offer a retry', () async {
    final service = GeminiDailyAdviceService(
      invoke: (_, _) async =>
          throw const GeminiProxyException('down', code: 'provider_error'),
    );

    await expectLater(
      service.adviceFor(meals: const [], steps: 1, mood: Mood.neutral),
      throwsA(isA<GeminiProxyException>()),
    );
  });
}
