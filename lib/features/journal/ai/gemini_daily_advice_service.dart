import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../models/meal.dart';
import '../../../models/mood.dart';
import 'daily_advice_service.dart';
import 'gemini_model.dart';
import 'gemini_retry.dart';

/// Real text-model implementation (IMPLEMENTATION_PLAN_REAL_AI.md #2 — the
/// deferred real-AI phase). Sends the day's meals/steps/mood to Gemini under
/// a system instruction that encodes the same tone/safety constraints
/// documented on [DailyAdviceService]. Throws on any failure (network,
/// non-200, empty/unparseable response) rather than returning a fallback
/// string — [JournalController.generateAndAttachAdvice] already catches this
/// and surfaces the existing "tap to retry" affordance, and the entry itself
/// was already saved before this runs, so nothing is lost.
class GeminiDailyAdviceService implements DailyAdviceService {
  GeminiDailyAdviceService({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent';

  /// The tone/safety contract every implementation of [DailyAdviceService]
  /// must uphold — see the constraint documented on the interface itself.
  static const _systemInstruction =
      'You are a supportive, non-clinical daily wellbeing assistant inside a '
      'travel and health journaling app. Given a day\'s logged meals, step '
      'count, and mood, write ONE short, friendly paragraph (2-4 sentences) '
      'of supportive daily wellbeing advice that considers food, activity, '
      'and mood together.\n\n'
      'Rules you MUST follow:\n'
      '- Never diagnose, and never give medical or clinical instructions.\n'
      '- Never set an explicit calorie target, and never tell the user to '
      'restrict or skip meals.\n'
      '- Never frame exercise as compensation for eating (no "burn it off", '
      'no "make up for it").\n'
      '- Mood suggestions must be gentle and optional-sounding (e.g. "a '
      'short walk or reaching out to someone might help"), never clinical '
      'or directive.\n'
      '- Keep it concise, warm, and non-judgemental. Respond with plain '
      'text only — no bullet points, no headings, no markdown.';

  @override
  Future<String> adviceFor({
    required List<Meal> meals,
    required int? steps,
    required Mood mood,
    int? caloriesEaten,
    int? caloriesBurned,
  }) async {
    final response = await postGeminiWithRetry(
      _client,
      Uri.parse('$_endpoint?key=$apiKey'),
      jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': _systemInstruction},
          ],
        },
        'contents': [
          {
            'parts': [
              {
                'text': _buildPrompt(
                  meals: meals,
                  steps: steps,
                  mood: mood,
                  caloriesEaten: caloriesEaten,
                  caloriesBurned: caloriesBurned,
                ),
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini advice request failed with status ${response.statusCode}',
      );
    }

    final advice = _parseResponse(response.body)?.trim();
    if (advice == null || advice.isEmpty) {
      throw Exception('Gemini advice response was empty or unparseable');
    }
    return advice;
  }

  String _buildPrompt({
    required List<Meal> meals,
    required int? steps,
    required Mood mood,
    required int? caloriesEaten,
    required int? caloriesBurned,
  }) {
    final buffer = StringBuffer()..writeln('Mood: ${mood.name}');
    if (steps != null) buffer.writeln('Steps today: $steps');
    if (caloriesEaten != null) buffer.writeln('Calories eaten: $caloriesEaten');
    if (caloriesBurned != null) {
      buffer.writeln('Calories burned: $caloriesBurned');
    }

    if (meals.isEmpty) {
      buffer.writeln('Meals logged: none yet today');
    } else {
      buffer.writeln('Meals logged:');
      for (final meal in meals) {
        buffer.writeln(
          '- ${meal.name} (${meal.mealType.name}, ~${meal.calories} kcal)',
        );
      }
    }

    return buffer.toString();
  }

  String? _parseResponse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;
      final firstCandidate = candidates?.isNotEmpty == true
          ? candidates!.first as Map<String, dynamic>
          : null;
      final parts =
          (firstCandidate?['content'] as Map<String, dynamic>?)?['parts']
              as List<dynamic>?;
      final text = parts?.isNotEmpty == true
          ? parts!.first as Map<String, dynamic>
          : null;
      return text?['text'] as String?;
    } catch (_) {
      return null;
    }
  }
}
