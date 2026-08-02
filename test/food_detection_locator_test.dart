import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/ai/food_detection_locator.dart';
import 'package:tripjournal/features/journal/ai/food_detection_service.dart';

void main() {
  test(
    'falls back to MockFoodDetectionService when GEMINI_API_KEY is not available',
    () {
      // Tests never call dotenv.load(), so the locator must not require it
      // (or a key) to keep working out of the box.
      expect(foodDetectionService, isA<MockFoodDetectionService>());
    },
  );
}
