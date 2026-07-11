import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/ai/food_detection_service.dart';

void main() {
  group('MockFoodDetectionService', () {
    final service = MockFoodDetectionService();

    test('returns a fixed plausible result regardless of the image path', () async {
      final detected = await service.detectFromImage('/some/path/photo.jpg');
      expect(detected, isNotNull);
      expect(detected!.name, isNotEmpty);
      expect(detected.estimatedCalories, greaterThan(0));
    });

    test('the same result is returned for any input, by design (no real vision model yet)', () async {
      final first = await service.detectFromImage('/a.jpg');
      final second = await service.detectFromImage('/completely/different.png');
      expect(first!.name, second!.name);
      expect(first.estimatedCalories, second.estimatedCalories);
    });
  });
}
