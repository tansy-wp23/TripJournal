import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'food_detection_service.dart';
import 'gemini_model.dart';

/// Real vision-model implementation (IMPLEMENTATION_PLAN_UX_POLISH.md §2 —
/// the deferred real-AI phase). Sends the photo inline to Gemini and asks
/// for a food name + calorie estimate as JSON. Accuracy is explicitly not a
/// goal — [FoodDetectionService.detectFromImage] always returns an editable
/// pre-fill, never a final value, and this returns null on any failure so
/// the caller falls back to manual entry rather than blocking the user.
class GeminiFoodDetectionService implements FoodDetectionService {
  GeminiFoodDetectionService({required this.apiKey, http.Client? client}) : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const _endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent';

  static const _prompt =
      'Identify the single main food item in this photo and estimate its '
      'calories for the portion shown. Respond with ONLY compact JSON in '
      'the form {"name": "...", "estimatedCalories": <integer>} — no '
      'markdown, no code fences, no explanation.';

  @override
  Future<DetectedFood?> detectFromImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final response = await _client.post(
        Uri.parse('$_endpoint?key=$apiKey'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': _prompt},
                {
                  'inline_data': {'mime_type': _mimeTypeFor(imagePath), 'data': base64Encode(bytes)},
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode != 200) return null;
      return _parseResponse(response.body);
    } catch (_) {
      return null;
    }
  }

  DetectedFood? _parseResponse(String responseBody) {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    final firstCandidate = candidates?.isNotEmpty == true ? candidates!.first as Map<String, dynamic> : null;
    final parts = (firstCandidate?['content'] as Map<String, dynamic>?)?['parts'] as List<dynamic>?;
    final text = parts?.isNotEmpty == true ? parts!.first as Map<String, dynamic> : null;
    final rawText = text?['text'] as String?;
    if (rawText == null) return null;

    // Models sometimes wrap JSON in ```json fences despite being told not to.
    final cleaned = rawText.trim().replaceAll(RegExp(r'^```(json)?|```$'), '').trim();

    final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
    final name = parsed['name'] as String?;
    final calories = parsed['estimatedCalories'] as num?;
    if (name == null || name.trim().isEmpty || calories == null) return null;

    return DetectedFood(name: name.trim(), estimatedCalories: calories.round());
  }

  String _mimeTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
