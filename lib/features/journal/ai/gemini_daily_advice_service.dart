import '../../../models/meal.dart';
import '../../../models/mood.dart';
import 'daily_advice_service.dart';
import 'gemini_function_invoker.dart';

/// Real implementation, backed by the `gemini-proxy` Edge Function.
///
/// The prompt and the tone/safety system instruction documented on
/// [DailyAdviceService] both live in the function now, not here — the API key
/// is server-side, and a client-supplied instruction could simply be edited
/// out. This class's job is to hand over the day's facts and read one string
/// back.
///
/// Throws on any failure rather than returning a fallback string:
/// `JournalController.generateAndAttachAdvice` already catches it and surfaces
/// the existing retry affordance, and the entry was saved before this runs, so
/// nothing is lost.
class GeminiDailyAdviceService implements DailyAdviceService {
  const GeminiDailyAdviceService({required GeminiFunctionInvoker invoke})
    : this._(invoke);

  const GeminiDailyAdviceService._(this._invoke);

  final GeminiFunctionInvoker _invoke;

  @override
  Future<String> adviceFor({
    required List<Meal> meals,
    required int? steps,
    required Mood mood,
    int? caloriesEaten,
    int? caloriesBurned,
  }) async {
    final payload = await _invoke('daily_advice', {
      'mood': mood.name,
      'steps': steps,
      'caloriesEaten': caloriesEaten,
      'caloriesBurned': caloriesBurned,
      'meals': [
        for (final meal in meals)
          {
            'name': meal.name,
            'mealType': meal.mealType.name,
            'calories': meal.calories,
            'foodReview': meal.foodReview,
          },
      ],
    });

    final advice = payload['advice'];
    if (advice is! String || advice.trim().isEmpty) {
      throw const GeminiProxyException(
        'The AI service returned an empty response.',
        code: 'invalid_response',
      );
    }
    return advice.trim();
  }
}
