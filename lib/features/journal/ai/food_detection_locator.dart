import '../../../data/ai_request_logging.dart';
import '../../../data/backend_mode.dart';
import '../../../models/ai_request_log.dart';
import 'food_detection_service.dart';
import 'gemini_food_detection_service.dart';
import 'gemini_function_invoker.dart';

/// The one place the app resolves its [FoodDetectionService] from — mirrors
/// `daily_advice_locator.dart`.
///
/// Real detection runs through the `gemini-proxy` Edge Function, which holds
/// `GEMINI_API_KEY` as a Supabase secret. The function reads the photo from
/// Supabase Storage by URL, so this pairing is not incidental: only
/// `BackendMode.supabase` both authenticates the call and stores photos
/// somewhere the function can fetch them. Mock mode keeps
/// [MockFoodDetectionService], whose local file paths the proxy would
/// (correctly) refuse.
///
/// Kept as the raw, unwrapped resolution — `food_detection_locator_test.dart`
/// asserts `foodDetectionService is MockFoodDetectionService` in the mock
/// case, so this symbol can't become a decorator that hides the underlying
/// type. Production call sites use [loggedFoodDetectionService] instead
/// (see its doc comment).
final FoodDetectionService foodDetectionService =
    _resolveFoodDetectionService();

/// [foodDetectionService], wrapped for Sprint 3's AI request monitoring
/// (Phase 18, `docs/admin/PROGRESS.md`, Architecture Decision 9) — records
/// type, status, and execution time to `aiRequestLogRepository` around
/// every call. `HealthLogForm` uses this, not the raw
/// [foodDetectionService], so a real detection request actually shows up in
/// `AiRequestMonitoringScreen`.
final FoodDetectionService loggedFoodDetectionService =
    _LoggingFoodDetectionService(foodDetectionService);

FoodDetectionService _resolveFoodDetectionService() {
  if (backendMode != BackendMode.supabase) return MockFoodDetectionService();
  return GeminiFoodDetectionService(invoke: geminiFunctionInvoker);
}

class _LoggingFoodDetectionService implements FoodDetectionService {
  _LoggingFoodDetectionService(this._inner);

  final FoodDetectionService _inner;

  @override
  Future<DetectedFood?> detectFromImage(String imagePath) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await _inner.detectFromImage(imagePath);
      recordAiRequest(
        requestType: AiRequestType.foodDetection,
        // A null result (detection genuinely couldn't identify the food) is
        // still a completed request, not a failed one — `errorMessage`
        // stays empty since nothing actually threw.
        status: AiRequestStatus.succeeded,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
      return result;
    } catch (e) {
      recordAiRequest(
        requestType: AiRequestType.foodDetection,
        status: AiRequestStatus.failed,
        executionTimeMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }
}
