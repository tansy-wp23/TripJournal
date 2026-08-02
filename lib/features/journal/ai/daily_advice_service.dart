import '../../../models/meal.dart';
import '../../../models/meal_type.dart';
import '../../../models/mood.dart';

/// Generates a holistic daily wellbeing suggestion from the day's meals,
/// steps, and mood together — broadened from the original food-only advice
/// (see IMPLEMENTATION_PLAN_UX_AI.md §2). Positioned as a supportive
/// assistant on top of the user's own logging, never a replacement for it.
///
/// CRITICAL tone/safety constraint that any implementation — mock or real —
/// must uphold: advice is supportive and non-prescriptive. It never
/// diagnoses, never issues clinical/medical instructions, never pressures,
/// and never frames food in disordered-eating-adjacent terms (no "restrict",
/// no "skip a meal", no "make up for it with exercise"). Mood is sensitive
/// (PDPA + wellbeing) — mood suggestions stay gentle and optional-sounding
/// ("a short walk or talking to someone close might help"), never anything
/// that could read as a mental-health diagnosis or directive.
abstract class DailyAdviceService {
  Future<String> adviceFor({
    required List<Meal> meals,
    required int? steps,
    required Mood mood,
    int? caloriesEaten,
    int? caloriesBurned,
  });
}

/// Canned, rule-based advice covering the food/steps/mood cases below — no
/// network call. See the tone/safety constraint on [DailyAdviceService];
/// every branch here was written to uphold it.
///
/// The real implementation is [GeminiDailyAdviceService]
/// (`gemini_daily_advice_service.dart`), selected automatically by
/// `daily_advice_locator.dart` when `GEMINI_API_KEY` is set in `.env`. This
/// mock stays as the default (no key, offline, tests) and is never deleted —
/// same interface, so the swap is a one-line locator change.
class MockDailyAdviceService implements DailyAdviceService {
  @override
  Future<String> adviceFor({
    required List<Meal> meals,
    required int? steps,
    required Mood mood,
    int? caloriesEaten,
    int? caloriesBurned,
  }) async {
    final wellbeingSentence = _wellbeingSentence(mood: mood, steps: steps);
    final foodSentence = _foodSentence(
      meals: meals,
      caloriesEaten: caloriesEaten,
    );

    // One short, friendly paragraph — not a list of separate commands.
    return [?wellbeingSentence, foodSentence].join(' ');
  }

  /// Mood takes priority over steps when both are notable — a low/tired mood
  /// is the more important signal to acknowledge gently. Returns null when
  /// there's nothing worth calling out (normal mood, normal activity).
  String? _wellbeingSentence({required Mood mood, required int? steps}) {
    switch (mood) {
      case Mood.stressed:
        return 'Feeling stressed today? A short walk, a few deep breaths, or '
            'talking to someone close might help you unwind.';
      case Mood.tired:
        return "You mentioned feeling tired — it might be worth winding down "
            'and getting some rest a little earlier tonight.';
      case Mood.happy:
      case Mood.excited:
      case Mood.neutral:
        break;
    }

    if (steps != null) {
      if (steps > 15000) {
        return "That's a big step count today — nice work staying active. "
            'Make sure to rest up and stay hydrated.';
      }
      if (steps < 3000) {
        return 'Your step count was on the lower side today — a short walk '
            'later, even just a few minutes, might feel good.';
      }
    }

    return null;
  }

  String _foodSentence({
    required List<Meal> meals,
    required int? caloriesEaten,
  }) {
    if (meals.isEmpty || caloriesEaten == null || caloriesEaten == 0) {
      return 'No meals logged yet today — add what you ate to get a fuller picture.';
    }

    if (caloriesEaten < 1200) {
      return 'Your estimated intake looks quite low for the day — make sure '
          "you're eating enough to keep your energy up.";
    }

    if (caloriesEaten > 2500) {
      return "Today's estimated intake is on the higher side — that happens "
          'some days, nothing to worry about.';
    }

    final hasBreakfast = meals.any((m) => m.mealType == MealType.breakfast);
    if (!hasBreakfast) {
      return "Looks like breakfast wasn't logged — a balanced morning meal "
          'can help steady your energy through the day.';
    }

    final snackCount = meals.where((m) => m.mealType == MealType.snack).length;
    if (snackCount >= 3) {
      return 'A few snacks logged today — swapping one for some fruit or '
          'water could round things out.';
    }

    return "Your meals look well-balanced today — nice work.";
  }
}
