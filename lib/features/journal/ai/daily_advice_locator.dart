import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../data/ai_request_logging.dart';
import '../../../models/ai_request_log.dart';
import '../../../models/meal.dart';
import '../../../models/mood.dart';
import 'daily_advice_service.dart';
import 'gemini_daily_advice_service.dart';

/// The one place the app resolves its [DailyAdviceService] from — mirrors
/// `food_detection_locator.dart`.
///
/// Reads the Gemini API key from `.env` (`GEMINI_API_KEY`, loaded via
/// `dotenv.load()` in `main()`). No key set, or `.env` not loaded yet (e.g.
/// in tests)? Falls back to [MockDailyAdviceService] so the app keeps
/// working out of the box, offline, for anyone without one set up.
///
/// Kept as the raw, unwrapped resolution — `daily_advice_locator_test.dart`
/// asserts `dailyAdviceService is MockDailyAdviceService` in the no-key
/// case, so this symbol can't become a decorator that hides the underlying
/// type. Production call sites use [loggedDailyAdviceService] instead (see
/// its doc comment).
final DailyAdviceService dailyAdviceService = _resolveDailyAdviceService();

/// [dailyAdviceService], wrapped for Sprint 3's AI request monitoring
/// (Phase 18, `docs/admin/PROGRESS.md`, Architecture Decision 9) — records
/// type, status, and execution time to `aiRequestLogRepository` around
/// every call. `JournalController`'s provider uses this, not the raw
/// [dailyAdviceService], so a real advice request actually shows up in
/// `AiRequestMonitoringScreen`.
final DailyAdviceService loggedDailyAdviceService =
    _LoggingDailyAdviceService(dailyAdviceService);

DailyAdviceService _resolveDailyAdviceService() {
  final apiKey = dotenv.isInitialized ? dotenv.env['GEMINI_API_KEY'] : null;
  if (apiKey == null || apiKey.isEmpty) return MockDailyAdviceService();
  return GeminiDailyAdviceService(apiKey: apiKey);
}

class _LoggingDailyAdviceService implements DailyAdviceService {
  _LoggingDailyAdviceService(this._inner);

  final DailyAdviceService _inner;

  @override
  Future<String> adviceFor({
    required List<Meal> meals,
    required int? steps,
    required Mood mood,
    int? caloriesEaten,
    int? caloriesBurned,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await _inner.adviceFor(
        meals: meals,
        steps: steps,
        mood: mood,
        caloriesEaten: caloriesEaten,
        caloriesBurned: caloriesBurned,
      );
      recordAiRequest(
        requestType: AiRequestType.dailyAdvice,
        status: AiRequestStatus.succeeded,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
      return result;
    } catch (e) {
      recordAiRequest(
        requestType: AiRequestType.dailyAdvice,
        status: AiRequestStatus.failed,
        executionTimeMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }
}
