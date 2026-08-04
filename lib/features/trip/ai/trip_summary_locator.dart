import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'gemini_trip_summary_service.dart';
import 'trip_summary_service.dart';

/// The one place the app resolves its [TripSummaryService]. A configured
/// Gemini key enables generated AI recaps; the offline service keeps the
/// feature available for local development and tests.
final TripSummaryService tripSummaryService = _resolveTripSummaryService();

TripSummaryService _resolveTripSummaryService() {
  final apiKey = dotenv.isInitialized ? dotenv.env['GEMINI_API_KEY'] : null;
  if (apiKey == null || apiKey.isEmpty) return MockTripSummaryService();
  return GeminiTripSummaryService(apiKey: apiKey);
}
