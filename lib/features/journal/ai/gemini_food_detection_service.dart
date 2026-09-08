import 'package:flutter/foundation.dart';

import 'food_detection_service.dart';
import 'gemini_function_invoker.dart';

/// Real implementation, backed by the `gemini-proxy` Edge Function.
///
/// Sends the photo's **Supabase Storage URL**, not its bytes. The function
/// fetches the object itself, which keeps the API key server-side and avoids
/// pushing a base64-inflated image through an Edge Function request body. It
/// also means detection only works for photos already uploaded to Storage —
/// true in `BACKEND_MODE=supabase`, which is the only mode this class runs in
/// (see `food_detection_locator.dart`; mock mode uses the mock service, whose
/// local file paths this proxy would rightly refuse).
///
/// Accuracy is explicitly not a goal — the result is always an editable
/// pre-fill, and every failure returns null so the caller falls back to manual
/// entry rather than blocking the user.
class GeminiFoodDetectionService implements FoodDetectionService {
  const GeminiFoodDetectionService({required GeminiFunctionInvoker invoke})
    : this._(invoke);

  const GeminiFoodDetectionService._(this._invoke);

  final GeminiFunctionInvoker _invoke;

  /// Debug-build-only breadcrumb. Every failure returns null so the user is
  /// never blocked, which also means a refused URL, an exhausted quota and an
  /// unreadable answer all look identical from the UI. Logging the reason in
  /// debug turns a guessing game into one glance at the console. Never logs
  /// credentials — there are none on this side any more.
  static void _debugFailure(String reason) {
    if (kDebugMode) debugPrint('[GeminiFoodDetection] failed: $reason');
  }

  @override
  Future<DetectedFood?> detectFromImage(String imagePath) async {
    if (!imagePath.startsWith('http://') && !imagePath.startsWith('https://')) {
      // A local file path: mock-mode storage, which the proxy cannot read.
      _debugFailure('not a Storage URL: $imagePath');
      return null;
    }

    try {
      final payload = await _invoke('food_detection', {'imageUrl': imagePath});
      final food = payload['food'];
      if (food == null) {
        _debugFailure('no food recognised in the photo');
        return null;
      }
      if (food is! Map) {
        _debugFailure('unexpected food payload: $food');
        return null;
      }

      final name = food['name'];
      final calories = food['estimatedCalories'];
      if (name is! String || name.trim().isEmpty || calories is! num) {
        _debugFailure('incomplete food payload: $food');
        return null;
      }
      return DetectedFood(
        name: name.trim(),
        estimatedCalories: calories.round(),
      );
    } catch (error) {
      _debugFailure('$error');
      return null;
    }
  }
}
