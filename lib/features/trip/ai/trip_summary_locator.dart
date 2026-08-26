import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../data/ai_request_logging.dart';
import '../../../models/ai_request_log.dart';
import '../../../models/journal_entry.dart';
import '../../../models/trip.dart';
import 'gemini_trip_summary_service.dart';
import 'trip_summary_service.dart';

/// The one place the app resolves its [TripSummaryService]. A configured
/// Gemini key enables generated AI recaps; the offline service keeps the
/// feature available for local development and tests.
///
/// Kept as the raw, unwrapped resolution so nothing else about this
/// symbol's behavior changes for existing callers/tests. Production call
/// sites use [loggedTripSummaryService] instead (see its doc comment).
final TripSummaryService tripSummaryService = _resolveTripSummaryService();

/// [tripSummaryService], wrapped for Sprint 3's AI request monitoring
/// (Phase 18, `docs/admin/PROGRESS.md`, Architecture Decision 9) — records
/// type, status, and execution time to `aiRequestLogRepository` around
/// every call. `TripViewScreen` uses this, not the raw [tripSummaryService],
/// so a real summary request actually shows up in
/// `AiRequestMonitoringScreen`.
final TripSummaryService loggedTripSummaryService =
    _LoggingTripSummaryService(tripSummaryService);

TripSummaryService _resolveTripSummaryService() {
  final apiKey = dotenv.isInitialized ? dotenv.env['GEMINI_API_KEY'] : null;
  if (apiKey == null || apiKey.isEmpty) return MockTripSummaryService();
  return GeminiTripSummaryService(apiKey: apiKey);
}

class _LoggingTripSummaryService implements TripSummaryService {
  _LoggingTripSummaryService(this._inner);

  final TripSummaryService _inner;

  @override
  Future<String> summaryFor({
    required Trip trip,
    required List<JournalEntry> entries,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await _inner.summaryFor(trip: trip, entries: entries);
      recordAiRequest(
        requestType: AiRequestType.tripSummary,
        status: AiRequestStatus.succeeded,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
      return result;
    } catch (e) {
      recordAiRequest(
        requestType: AiRequestType.tripSummary,
        status: AiRequestStatus.failed,
        executionTimeMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }
}
