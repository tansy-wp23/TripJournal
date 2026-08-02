import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'food_detection_service.dart';
import 'gemini_food_detection_service.dart';

/// The one place the app resolves its [FoodDetectionService] from — mirrors
/// `daily_advice_locator.dart`.
///
/// Reads the Gemini API key from `.env` (`GEMINI_API_KEY`, loaded via
/// `dotenv.load()` in `main()`) — never hardcode a real key in source or
/// commit it. No key set, or `.env` not loaded yet (e.g. in tests)? Falls
/// back to [MockFoodDetectionService] so the app keeps working out of the
/// box for anyone without one set up.
final FoodDetectionService foodDetectionService =
    _resolveFoodDetectionService();

FoodDetectionService _resolveFoodDetectionService() {
  final apiKey = dotenv.isInitialized ? dotenv.env['GEMINI_API_KEY'] : null;
  if (apiKey == null || apiKey.isEmpty) return MockFoodDetectionService();
  return GeminiFoodDetectionService(apiKey: apiKey);
}
