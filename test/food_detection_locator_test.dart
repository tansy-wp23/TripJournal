import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/ai/food_detection_locator.dart';
import 'package:tripjournal/features/journal/ai/food_detection_service.dart';

void main() {
  test('falls back to MockFoodDetectionService when no GEMINI_API_KEY is supplied', () {
    // Tests never pass --dart-define=GEMINI_API_KEY, so the locator must not
    // require one to keep working out of the box.
    expect(foodDetectionService, isA<MockFoodDetectionService>());
  });
}
