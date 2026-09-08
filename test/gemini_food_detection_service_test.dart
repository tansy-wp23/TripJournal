import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/ai/gemini_food_detection_service.dart';
import 'package:tripjournal/features/journal/ai/gemini_function_invoker.dart';

// The model call, ```json fence stripping and the storage-URL guard all live
// in the gemini-proxy Edge Function now (covered by its Deno tests). What
// matters here is the contract this service has always had with its caller:
// **never throw, never block manual entry** — every failure is a null.

const _imageUrl =
    'https://project.supabase.co/storage/v1/object/public/journal-photos/'
    'user-1/trip-1/entry-1.jpg';

void main() {
  test('returns the detected food from the proxy', () async {
    String? seenAction;
    Map<String, dynamic>? seenBody;
    final service = GeminiFoodDetectionService(
      invoke: (action, body) async {
        seenAction = action;
        seenBody = body;
        return {
          'food': {'name': 'Ramen', 'estimatedCalories': 620},
        };
      },
    );

    final detected = await service.detectFromImage(_imageUrl);

    expect(detected!.name, 'Ramen');
    expect(detected.estimatedCalories, 620);
    expect(seenAction, 'food_detection');
    expect(seenBody, {'imageUrl': _imageUrl});
  });

  test('rounds a fractional calorie estimate', () async {
    final service = GeminiFoodDetectionService(
      invoke: (_, _) async => {
        'food': {'name': 'Toast', 'estimatedCalories': 149.6},
      },
    );

    expect((await service.detectFromImage(_imageUrl))!.estimatedCalories, 150);
  });

  test('returns null when the proxy recognised nothing', () async {
    final service = GeminiFoodDetectionService(
      invoke: (_, _) async => {'food': null},
    );

    expect(await service.detectFromImage(_imageUrl), isNull);
  });

  test('returns null on an incomplete or malformed food payload', () async {
    for (final food in [
      {'name': '', 'estimatedCalories': 100},
      {'name': 'Ramen'},
      {'estimatedCalories': 100},
      'not a map',
    ]) {
      final service = GeminiFoodDetectionService(
        invoke: (_, _) async => {'food': food},
      );
      expect(
        await service.detectFromImage(_imageUrl),
        isNull,
        reason: 'food: $food',
      );
    }
  });

  test('returns null rather than throwing when the proxy fails', () async {
    final service = GeminiFoodDetectionService(
      invoke: (_, _) async =>
          throw const GeminiProxyException('down', code: 'provider_error'),
    );

    expect(await service.detectFromImage(_imageUrl), isNull);
  });

  test(
    'never calls the proxy for a local file path — those are mock-mode photos '
    'the function cannot read, and sending one would just waste a round trip',
    () async {
      var called = false;
      final service = GeminiFoodDetectionService(
        invoke: (_, _) async {
          called = true;
          return {'food': null};
        },
      );

      expect(await service.detectFromImage('/data/user/0/cache/photo.jpg'), isNull);
      expect(called, isFalse);
    },
  );
}
