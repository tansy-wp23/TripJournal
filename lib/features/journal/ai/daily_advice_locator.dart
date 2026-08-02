import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'daily_advice_service.dart';
import 'gemini_daily_advice_service.dart';

/// The one place the app resolves its [DailyAdviceService] from — mirrors
/// `food_detection_locator.dart`.
///
/// Reads the Gemini API key from `.env` (`GEMINI_API_KEY`, loaded via
/// `dotenv.load()` in `main()`). No key set, or `.env` not loaded yet (e.g.
/// in tests)? Falls back to [MockDailyAdviceService] so the app keeps
/// working out of the box, offline, for anyone without one set up.
final DailyAdviceService dailyAdviceService = _resolveDailyAdviceService();

DailyAdviceService _resolveDailyAdviceService() {
  final apiKey = dotenv.isInitialized ? dotenv.env['GEMINI_API_KEY'] : null;
  if (apiKey == null || apiKey.isEmpty) return MockDailyAdviceService();
  return GeminiDailyAdviceService(apiKey: apiKey);
}
