/// A food photo's detected contents — always an editable pre-fill, never a
/// final value. Accuracy is explicitly not a goal (see
/// IMPLEMENTATION_PLAN_UX_POLISH.md §2): the user reviews and can change
/// either field before saving the meal.
class DetectedFood {
  const DetectedFood({required this.name, required this.estimatedCalories});

  final String name;
  final int estimatedCalories;
}

/// Detects a meal's name and calorie estimate from a food photo. Optional
/// convenience only — manual meal entry must always work without it.
abstract class FoodDetectionService {
  /// Returns null if detection fails; callers must fall back to manual entry
  /// rather than blocking the user.
  Future<DetectedFood?> detectFromImage(String imagePath);
}

/// Rule-free stand-in used for build/emulator (no API key, no network) —
/// returns the same plausible result regardless of the image. The real
/// vision-model implementation (GPT-4o-class / Gemini) is deferred; it must
/// accept images, not just text.
class MockFoodDetectionService implements FoodDetectionService {
  @override
  Future<DetectedFood?> detectFromImage(String imagePath) async {
    return const DetectedFood(name: 'Nasi lemak', estimatedCalories: 600);
  }
}
