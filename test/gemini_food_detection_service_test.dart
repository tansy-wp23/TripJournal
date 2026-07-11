import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tripjournal/features/journal/ai/gemini_food_detection_service.dart';

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

void main() {
  late Directory tempDir;
  late String imagePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gemini_food_detection_test');
    final file = File('${tempDir.path}/meal.jpg');
    await file.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));
    imagePath = file.path;
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('parses a well-formed JSON response into a DetectedFood', () async {
    final client = MockClient((request) async {
      return _geminiResponseWithText('{"name": "Chicken rice", "estimatedCalories": 550}');
    });
    final service = GeminiFoodDetectionService(apiKey: 'test-key', client: client);

    final detected = await service.detectFromImage(imagePath);

    expect(detected, isNotNull);
    expect(detected!.name, 'Chicken rice');
    expect(detected.estimatedCalories, 550);
  });

  test('strips ```json code fences the model sometimes adds despite instructions', () async {
    final client = MockClient((request) async {
      return _geminiResponseWithText('```json\n{"name": "Laksa", "estimatedCalories": 480}\n```');
    });
    final service = GeminiFoodDetectionService(apiKey: 'test-key', client: client);

    final detected = await service.detectFromImage(imagePath);

    expect(detected!.name, 'Laksa');
    expect(detected.estimatedCalories, 480);
  });

  test('returns null (falls back to manual entry) on a non-200 response', () async {
    final client = MockClient((request) async => http.Response('Server error', 500));
    final service = GeminiFoodDetectionService(apiKey: 'test-key', client: client);

    final detected = await service.detectFromImage(imagePath);

    expect(detected, isNull);
  });

  test('returns null on malformed/unparseable JSON rather than throwing', () async {
    final client = MockClient((request) async => _geminiResponseWithText('not valid json at all'));
    final service = GeminiFoodDetectionService(apiKey: 'test-key', client: client);

    final detected = await service.detectFromImage(imagePath);

    expect(detected, isNull);
  });

  test('returns null when the network call throws', () async {
    final client = MockClient((request) async => throw const SocketException('no connection'));
    final service = GeminiFoodDetectionService(apiKey: 'test-key', client: client);

    final detected = await service.detectFromImage(imagePath);

    expect(detected, isNull);
  });

  test('returns null for a missing image file', () async {
    final client = MockClient((request) async => _geminiResponseWithText('{"name": "x", "estimatedCalories": 1}'));
    final service = GeminiFoodDetectionService(apiKey: 'test-key', client: client);

    final detected = await service.detectFromImage('${tempDir.path}/does_not_exist.jpg');

    expect(detected, isNull);
  });

  test('sends the image as base64 inline data with the API key in the URL', () async {
    Uri? capturedUri;
    Map<String, dynamic>? capturedBody;
    final client = MockClient((request) async {
      capturedUri = request.url;
      capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _geminiResponseWithText('{"name": "Test", "estimatedCalories": 100}');
    });
    final service = GeminiFoodDetectionService(apiKey: 'my-secret-key', client: client);

    await service.detectFromImage(imagePath);

    expect(capturedUri!.queryParameters['key'], 'my-secret-key');
    final parts = capturedBody!['contents'][0]['parts'] as List<dynamic>;
    final inlineData = parts[1]['inline_data'] as Map<String, dynamic>;
    expect(inlineData['mime_type'], 'image/jpeg');
    expect(base64Decode(inlineData['data'] as String), [1, 2, 3, 4]);
  });
}
