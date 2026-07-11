import 'food_detection_service.dart';
import 'gemini_food_detection_service.dart';

/// The one place the app resolves its [FoodDetectionService] from — mirrors
/// `daily_advice_locator.dart`.
///
/// Reads the Gemini API key from `--dart-define=GEMINI_API_KEY=...` at
/// build/run time — never hardcode a real key in source or commit it. No key
/// supplied? Falls back to [MockFoodDetectionService] so the app keeps
/// working out of the box for anyone without one set up yet.
const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

final FoodDetectionService foodDetectionService = _geminiApiKey.isEmpty
    ? MockFoodDetectionService()
    : GeminiFoodDetectionService(apiKey: _geminiApiKey);
