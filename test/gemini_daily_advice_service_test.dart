import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tripjournal/features/journal/ai/gemini_daily_advice_service.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';
import 'package:tripjournal/models/mood.dart';

http.Response _geminiResponseWithText(String modelText) {
  return http.Response(
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': modelText},
            ],
          },
        },
      ],
    }),
    200,
  );
}

const _balancedMeals = [
  Meal(
    id: 'm1',
    name: 'Rice and eggs',
    calories: 500,
    mealType: MealType.breakfast,
  ),
];

void main() {
  test('parses a well-formed text response into the advice string', () async {
    final client = MockClient((request) async {
      return _geminiResponseWithText(
        'You had a balanced day -- nice work staying active.',
      );
    });
    final service = GeminiDailyAdviceService(
      apiKey: 'test-key',
      client: client,
    );

    final advice = await service.adviceFor(
      meals: _balancedMeals,
      steps: 6000,
      mood: Mood.happy,
      caloriesEaten: 500,
    );

    expect(advice, 'You had a balanced day -- nice work staying active.');
  });

  test('trims surrounding whitespace from the model response', () async {
    final client = MockClient(
      (request) async => _geminiResponseWithText('\n  Some advice.  \n'),
    );
    final service = GeminiDailyAdviceService(
      apiKey: 'test-key',
      client: client,
    );

    final advice = await service.adviceFor(
      meals: _balancedMeals,
      steps: 6000,
      mood: Mood.happy,
    );

    expect(advice, 'Some advice.');
  });

  test(
    'throws on a non-200 response so the caller can offer a retry',
    () async {
      final client = MockClient(
        (request) async => http.Response('Server error', 500),
      );
      final service = GeminiDailyAdviceService(
        apiKey: 'test-key',
        client: client,
      );

      expect(
        () => service.adviceFor(
          meals: _balancedMeals,
          steps: 6000,
          mood: Mood.happy,
        ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'throws on malformed/unparseable JSON rather than returning garbage',
    () async {
      final client = MockClient(
        (request) async => http.Response('not json at all', 200),
      );
      final service = GeminiDailyAdviceService(
        apiKey: 'test-key',
        client: client,
      );

      expect(
        () => service.adviceFor(
          meals: _balancedMeals,
          steps: 6000,
          mood: Mood.happy,
        ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('throws when the response has an empty advice string', () async {
    final client = MockClient((request) async => _geminiResponseWithText(''));
    final service = GeminiDailyAdviceService(
      apiKey: 'test-key',
      client: client,
    );

    expect(
      () => service.adviceFor(
        meals: _balancedMeals,
        steps: 6000,
        mood: Mood.happy,
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('throws when the network call itself throws', () async {
    final client = MockClient(
      (request) async => throw const SocketException('no connection'),
    );
    final service = GeminiDailyAdviceService(
      apiKey: 'test-key',
      client: client,
    );

    expect(
      () => service.adviceFor(
        meals: _balancedMeals,
        steps: 6000,
        mood: Mood.happy,
      ),
      throwsA(isA<SocketException>()),
    );
  });

  test(
    'sends the system instruction and the day\'s data, with the API key in the URL',
    () async {
      Uri? capturedUri;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _geminiResponseWithText('ok');
      });
      final service = GeminiDailyAdviceService(
        apiKey: 'my-secret-key',
        client: client,
      );

      await service.adviceFor(
        meals: const [
          Meal(
            id: 'm1',
            name: 'Nasi lemak',
            calories: 600,
            mealType: MealType.lunch,
          ),
        ],
        steps: 4200,
        mood: Mood.stressed,
        caloriesEaten: 600,
        caloriesBurned: 900,
      );

      expect(capturedUri!.queryParameters['key'], 'my-secret-key');

      final systemText =
          (capturedBody!['systemInstruction']['parts']
                  as List<dynamic>)[0]['text']
              as String;
      // The safety/tone constraints must actually be sent to the model, not
      // just documented in a comment.
      for (final mustContain in [
        'Never diagnose',
        'restrict or skip meals',
        'compensation',
        'gentle and optional-sounding',
      ]) {
        expect(systemText, contains(mustContain));
      }

      final promptText =
          (capturedBody!['contents'] as List<dynamic>)[0]['parts'][0]['text']
              as String;
      expect(promptText, contains('stressed'));
      expect(promptText, contains('4200'));
      expect(promptText, contains('Nasi lemak'));
      expect(promptText, contains('600'));
      expect(promptText, contains('900'));
    },
  );

  test('omits optional figures from the prompt when they are null', () async {
    Map<String, dynamic>? capturedBody;
    final client = MockClient((request) async {
      capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _geminiResponseWithText('ok');
    });
    final service = GeminiDailyAdviceService(
      apiKey: 'test-key',
      client: client,
    );

    await service.adviceFor(meals: const [], steps: null, mood: Mood.neutral);

    final promptText =
        (capturedBody!['contents'] as List<dynamic>)[0]['parts'][0]['text']
            as String;
    expect(promptText, contains('none yet today'));
    expect(promptText, isNot(contains('Steps today')));
    expect(promptText, isNot(contains('Calories eaten')));
    expect(promptText, isNot(contains('Calories burned')));
  });

  test('includes a meal\'s food review in the prompt when present', () async {
    Map<String, dynamic>? capturedBody;
    final client = MockClient((request) async {
      capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _geminiResponseWithText('ok');
    });
    final service = GeminiDailyAdviceService(apiKey: 'test-key', client: client);

    await service.adviceFor(
      meals: const [
        Meal(
          id: 'm1',
          name: 'Ramen',
          calories: 650,
          mealType: MealType.lunch,
          restaurantName: 'Ichiran Gion',
          foodReview: 'Rich broth, too salty.',
        ),
      ],
      steps: 6000,
      mood: Mood.happy,
    );

    final promptText =
        (capturedBody!['contents'] as List<dynamic>)[0]['parts'][0]['text']
            as String;
    expect(promptText, contains('Rich broth, too salty.'));
  });

  test('omits the review note from the prompt when a meal has none', () async {
    Map<String, dynamic>? capturedBody;
    final client = MockClient((request) async {
      capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _geminiResponseWithText('ok');
    });
    final service = GeminiDailyAdviceService(apiKey: 'test-key', client: client);

    await service.adviceFor(
      meals: _balancedMeals,
      steps: 6000,
      mood: Mood.happy,
    );

    final promptText =
        (capturedBody!['contents'] as List<dynamic>)[0]['parts'][0]['text']
            as String;
    expect(promptText, isNot(contains("user's note")));
  });
}
